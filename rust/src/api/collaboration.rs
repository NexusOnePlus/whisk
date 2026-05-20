use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use yrs::updates::decoder::Decode;
use yrs::updates::encoder::Encode;
use yrs::{Doc, GetString, ReadTxn, StateVector, Text, TextRef, Transact, Update};

#[derive(Clone, Debug)]
pub struct RustTextOperation {
    pub offset: u32,
    pub inserted_text: String,
    pub deleted_length: u32,
}

#[frb(opaque)]
pub struct CollaborationEngine {
    files: Arc<Mutex<HashMap<String, CollaborationFile>>>,
    // Add Iroh endpoint here later.
}

struct CollaborationFile {
    doc: Doc,
    text: TextRef,
}

impl CollaborationEngine {
    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            files: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    #[frb(sync)]
    pub fn load_file_snapshot(&self, file_path: String, text: String) {
        let mut files = self
            .files
            .lock()
            .expect("collaboration files lock poisoned");
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
        let mut files = self
            .files
            .lock()
            .expect("collaboration files lock poisoned");
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
        let files = self
            .files
            .lock()
            .expect("collaboration files lock poisoned");
        let Some(file) = files.get(&file_path) else {
            return StateVector::default().encode_v1();
        };
        let txn = file.doc.transact();
        txn.state_vector().encode_v1()
    }

    #[frb(sync)]
    pub fn encode_update_since(&self, file_path: String, state_vector: Vec<u8>) -> Vec<u8> {
        let files = self
            .files
            .lock()
            .expect("collaboration files lock poisoned");
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
        let mut files = self
            .files
            .lock()
            .expect("collaboration files lock poisoned");
        let file = files
            .entry(file_path)
            .or_insert_with(CollaborationFile::new);
        let mut txn = file.doc.transact_mut();
        txn.apply_update(update).is_ok()
    }

    #[frb(sync)]
    pub fn get_text(&self, file_path: String) -> String {
        let files = self
            .files
            .lock()
            .expect("collaboration files lock poisoned");
        let Some(file) = files.get(&file_path) else {
            return String::new();
        };
        let txn = file.doc.transact();
        file.text.get_string(&txn)
    }

    // Example Iroh method
    pub async fn start_session(&self) {
        // Initialize Iroh endpoint
    }
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
}
