use flutter_rust_bridge::frb;
use iroh::{endpoint::presets, Endpoint, EndpointAddr};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use yrs::updates::decoder::Decode;
use yrs::updates::encoder::Encode;
use yrs::{Doc, GetString, ReadTxn, StateVector, Text, TextRef, Transact, Update};

const WHISK_COLLAB_ALPN: &[u8] = b"whisk/collab/0";
const MAX_MESSAGE_BYTES: usize = 16 * 1024 * 1024;

#[derive(Clone, Debug)]
pub struct RustTextOperation {
    pub offset: u32,
    pub inserted_text: String,
    pub deleted_length: u32,
}

#[frb(opaque)]
pub struct CollaborationEngine {
    files: Arc<Mutex<HashMap<String, CollaborationFile>>>,
    endpoint: Arc<Mutex<Option<Endpoint>>>,
    inbox: Arc<Mutex<Vec<Vec<u8>>>>,
    outgoing: Arc<Mutex<Option<Endpoint>>>,
}

struct CollaborationFile {
    doc: Doc,
    text: TextRef,
}

impl CollaborationEngine {
    fn lock_files(&self) -> std::sync::MutexGuard<'_, HashMap<String, CollaborationFile>> {
        self.files.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn lock_endpoint(&self) -> std::sync::MutexGuard<'_, Option<Endpoint>> {
        self.endpoint.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn lock_inbox(&self) -> std::sync::MutexGuard<'_, Vec<Vec<u8>>> {
        self.inbox.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn lock_outgoing(&self) -> std::sync::MutexGuard<'_, Option<Endpoint>> {
        self.outgoing.lock().unwrap_or_else(|e| e.into_inner())
    }

    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            files: Arc::new(Mutex::new(HashMap::new())),
            endpoint: Arc::new(Mutex::new(None)),
            inbox: Arc::new(Mutex::new(Vec::new())),
            outgoing: Arc::new(Mutex::new(None)),
        }
    }

    #[frb(sync)]
    pub fn load_file_snapshot(&self, file_path: String, text: String) {
        let mut files = self.lock_files();
        let file = files
            .entry(file_path)
            .or_insert_with(CollaborationFile::new);
        let mut txn = file.doc.transact_mut();
        let current_len = file.text.len(&txn);
        if current_len > 0 {
            file.text.remove_range(&mut txn, 0, current_len);
        }
        if !text.is_empty() {
            file.text.insert(&mut txn, 0, &text);
        }
        txn.commit();
    }

    #[frb(sync)]
    pub fn apply_local_edit(&self, file_path: String, op: RustTextOperation) {
        let mut files = self.lock_files();
        let file = files
            .entry(file_path)
            .or_insert_with(CollaborationFile::new);
        let mut txn = file.doc.transact_mut();
        if op.deleted_length > 0 {
            file.text
                .remove_range(&mut txn, op.offset, op.deleted_length);
        }
        if !op.inserted_text.is_empty() {
            file.text.insert(&mut txn, op.offset, &op.inserted_text);
        }
        txn.commit();
    }

    #[frb(sync)]
    pub fn encode_state_vector(&self, file_path: String) -> Vec<u8> {
        let files = self.lock_files();
        let Some(file) = files.get(&file_path) else {
            return StateVector::default().encode_v1();
        };
        let txn = file.doc.transact();
        txn.state_vector().encode_v1()
    }

    #[frb(sync)]
    pub fn encode_update_since(&self, file_path: String, state_vector: Vec<u8>) -> Vec<u8> {
        let files = self.lock_files();
        let Some(file) = files.get(&file_path) else {
            return Vec::new();
        };
        let state_vector = StateVector::decode_v1(state_vector.as_slice())
            .unwrap_or_else(|_| StateVector::default());
        let txn = file.doc.transact();
        txn.encode_state_as_update_v1(&state_vector)
    }

    #[frb(sync)]
    pub fn encode_full_update(&self, file_path: String) -> Vec<u8> {
        self.encode_update_since(file_path, StateVector::default().encode_v1())
    }

    #[frb(sync)]
    pub fn apply_remote_update(&self, file_path: String, update: Vec<u8>) -> bool {
        let Ok(update) = Update::decode_v1(update.as_slice()) else {
            return false;
        };
        let mut files = self.lock_files();
        let file = files
            .entry(file_path)
            .or_insert_with(CollaborationFile::new);
        let mut txn = file.doc.transact_mut();
        txn.apply_update(update).is_ok()
    }

    #[frb(sync)]
    pub fn get_text(&self, file_path: String) -> String {
        let files = self.lock_files();
        let Some(file) = files.get(&file_path) else {
            return String::new();
        };
        let txn = file.doc.transact();
        file.text.get_string(&txn)
    }

    pub async fn start_session(&self) -> String {
        let endpoint = match Endpoint::builder(presets::N0)
            .alpns(vec![WHISK_COLLAB_ALPN.to_vec()])
            .bind()
            .await
        {
            Ok(endpoint) => endpoint,
            Err(_) => return String::new(),
        };
        endpoint.online().await;
        let invite = match serde_json::to_string(&endpoint.addr()) {
            Ok(invite) => invite,
            Err(_) => return String::new(),
        };

        let outgoing = match Endpoint::builder(presets::N0)
            .alpns(vec![WHISK_COLLAB_ALPN.to_vec()])
            .bind()
            .await
        {
            Ok(endpoint) => endpoint,
            Err(_) => return String::new(),
        };

        self.spawn_accept_loop(endpoint.clone());
        {
            let mut current = self.lock_endpoint();
            *current = Some(endpoint);
        }
        {
            let mut out = self.lock_outgoing();
            *out = Some(outgoing);
        }
        invite
    }

    pub async fn close_session(&self) {
        let endpoint = {
            let mut current = self.lock_endpoint();
            current.take()
        };
        if let Some(endpoint) = endpoint {
            endpoint.close().await;
        }
        let outgoing = { self.lock_outgoing().take() };
        if let Some(outgoing) = outgoing {
            outgoing.close().await;
        }
    }

    pub async fn send_bytes_to_invite(&self, invite: String, payload: Vec<u8>) -> bool {
        let Ok(addr) = serde_json::from_str::<EndpointAddr>(&invite) else {
            return false;
        };
        let outgoing = { self.lock_outgoing().clone() };
        let (endpoint, owned) = match outgoing {
            Some(ref ep) => (ep.clone(), false),
            None => match Endpoint::bind(presets::N0).await {
                Ok(ep) => (ep, true),
                Err(_) => return false,
            },
        };
        let result = send_bytes(&endpoint, addr, payload).await;
        if owned {
            endpoint.close().await;
        }
        result
    }

    #[frb(sync)]
    pub fn drain_received_bytes(&self) -> Vec<Vec<u8>> {
        let mut inbox = self.lock_inbox();
        inbox.drain(..).collect()
    }

    fn spawn_accept_loop(&self, endpoint: Endpoint) {
        let inbox = self.inbox.clone();
        tokio::spawn(async move {
            while let Some(incoming) = endpoint.accept().await {
                let inbox = inbox.clone();
                tokio::spawn(async move {
                    let Ok(connection) = incoming.await else {
                        return;
                    };
                    let Ok((mut send, mut recv)) = connection.accept_bi().await else {
                        return;
                    };
                    let Ok(payload) = recv.read_to_end(MAX_MESSAGE_BYTES).await else {
                        return;
                    };
                    {
                        let mut inbox = match inbox.lock() {
                            Ok(guard) => guard,
                            Err(poisoned) => poisoned.into_inner(),
                        };
                        inbox.push(payload);
                    }
                    let _ = send.write_all(b"ok").await;
                    let _ = send.finish();
                    connection.closed().await;
                });
            }
        });
    }
}

async fn send_bytes(endpoint: &Endpoint, addr: EndpointAddr, payload: Vec<u8>) -> bool {
    let Ok(connection) = endpoint.connect(addr, WHISK_COLLAB_ALPN).await else {
        return false;
    };
    let Ok((mut send, mut recv)) = connection.open_bi().await else {
        connection.close(0u32.into(), b"stream failed");
        return false;
    };
    if send.write_all(&payload).await.is_err() {
        connection.close(0u32.into(), b"write failed");
        return false;
    }
    if send.finish().is_err() {
        connection.close(0u32.into(), b"finish failed");
        return false;
    }
    let acknowledged = recv
        .read_to_end(16)
        .await
        .map(|bytes| bytes == b"ok")
        .unwrap_or(false);
    connection.close(0u32.into(), b"done");
    acknowledged
}

impl CollaborationFile {
    fn new() -> Self {
        let doc = Doc::new();
        let text = doc.get_or_insert_text("content");
        Self { doc, text }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn syncs_text_using_binary_updates() {
        let left = CollaborationEngine::new();
        let right = CollaborationEngine::new();
        let file_path = "main.tex".to_string();

        left.load_file_snapshot(file_path.clone(), "abc".to_string());
        let full_update = left.encode_full_update(file_path.clone());
        assert!(right.apply_remote_update(file_path.clone(), full_update));
        assert_eq!(right.get_text(file_path.clone()), "abc");

        right.apply_local_edit(
            file_path.clone(),
            RustTextOperation {
                offset: 1,
                inserted_text: "X".to_string(),
                deleted_length: 0,
            },
        );
        let left_state = left.encode_state_vector(file_path.clone());
        let delta = right.encode_update_since(file_path.clone(), left_state);
        assert!(left.apply_remote_update(file_path.clone(), delta));
        assert_eq!(left.get_text(file_path), "aXbc");
    }

    #[tokio::test]
    async fn sends_binary_payloads_over_iroh_invites() {
        let host = CollaborationEngine::new();
        let guest = CollaborationEngine::new();
        let invite = host.start_session().await;
        assert!(!invite.is_empty());

        assert!(
            guest
                .send_bytes_to_invite(invite, b"crdt-update".to_vec())
                .await
        );

        let received = host.drain_received_bytes();
        assert_eq!(received, vec![b"crdt-update".to_vec()]);
        host.close_session().await;
    }
}
