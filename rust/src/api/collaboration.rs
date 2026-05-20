use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use yrs::{Doc, GetString, Text, TextRef, Transact};

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
        // Trigger Iroh sync later
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
