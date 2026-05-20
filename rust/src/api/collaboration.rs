use std::sync::Arc;
use yrs::{Doc, Text, Transact, TextRef, GetString};
use flutter_rust_bridge::frb;

#[derive(Clone, Debug)]
pub struct RustTextOperation {
    pub offset: u32,
    pub inserted_text: String,
    pub deleted_length: u32,
}

#[frb(opaque)]
pub struct CollaborationEngine {
    doc: Arc<Doc>,
    text: TextRef,
    // Add Iroh endpoint here later.
}

impl CollaborationEngine {
    #[frb(sync)]
    pub fn new() -> Self {
        let doc = Arc::new(Doc::new());
        let text = doc.get_or_insert_text("content");
        
        Self {
            doc,
            text,
        }
    }

    #[frb(sync)]
    pub fn apply_local_edit(&self, op: RustTextOperation) {
        let mut txn = self.doc.transact_mut();
        if op.deleted_length > 0 {
            self.text.remove_range(&mut txn, op.offset, op.deleted_length);
        }
        if !op.inserted_text.is_empty() {
            self.text.insert(&mut txn, op.offset, &op.inserted_text);
        }
        txn.commit();
        // Trigger Iroh sync later
    }

    #[frb(sync)]
    pub fn get_text(&self) -> String {
        let txn = self.doc.transact();
        self.text.get_string(&txn)
    }

    // Example Iroh method
    pub async fn start_session(&self) {
        // Initialize Iroh endpoint
    }
}
