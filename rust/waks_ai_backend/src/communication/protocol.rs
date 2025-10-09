use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub enum Request {
    Generate {
        prompt: String,
    },
    Save {
        key: String,
        value: String,
    },
    Fetch {
        key: String,
    },

    // Structured Data
    RecordSession {
        session_id: String,
        status: String,
    },
    RecordResponse {
        session_id: String,
        prompt: String,
        output: String,
    },
    RecordFrontendActivity {
        session_id: String,
        action: String,
    },
    RecordCodeChange {
        session_id: String,
        file_path: String,
        diff: String,
        commit_message: String,
    },
    GetCodeChanges {
        session_id: String,
    },
}

#[derive(Debug, Serialize, Deserialize)]
pub enum Response {
    Success { data: String },
    Error { message: String },
}
