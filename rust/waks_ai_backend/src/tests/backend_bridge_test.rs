#![allow(unused)]
use std::sync::Arc;

use chrono::Utc;
use tokio;

use crate::{
    ai::state::AppState,
    backend_bridge::handle_request,
    protocol::{Request, Response},
    storage::{db, state::StrongHandle},
};

/// Utility: Initialize test environment (mock db + app state)
async fn setup() -> (Arc<AppState>, StrongHandle) {
    let ai_state = Arc::new(AppState::new());
    let storage = StrongHandle::new();

    // Initialize DB if needed
    let _ = db::init_db().await;

    (ai_state, storage)
}

/// ✅ Test generic save/fetch
#[tokio::test]
async fn test_save_and_fetch() {
    let (ai_state, storage) = setup().await;

    let save_req = Request::Save {
        key: "username".into(),
        value: "waks".into(),
    };

    let resp = handle_request(save_req, ai_state.clone(), storage.clone()).await;
    assert!(matches!(resp, Response::Success { .. }));

    let fetch_req = Request::Fetch {
        key: "username".into(),
    };

    let resp = handle_request(fetch_req, ai_state, storage).await;
    if let Response::Success { data } = resp {
        assert_eq!(data, "waks");
    } else {
        panic!("Fetch failed");
    }
}

/// ✅ Test session recording
#[tokio::test]
async fn test_record_session() {
    let (ai_state, storage) = setup().await;
    let req = Request::RecordSession {
        session_id: "sess_001".into(),
        status: "active".into(),
    };

    let resp = handle_request(req, ai_state, storage).await;
    if let Response::Success { data } = resp {
        assert!(data.contains("recorded"));
    } else {
        panic!("Session record failed");
    }
}

/// ✅ Test AI response recording
#[tokio::test]
async fn test_record_response() {
    let (ai_state, storage) = setup().await;
    let req = Request::RecordResponse {
        session_id: "sess_001".into(),
        prompt: "Hello AI".into(),
        output: "Hi human!".into(),
    };

    let resp = handle_request(req, ai_state, storage).await;
    if let Response::Success { data } = resp {
        assert!(data.contains("stored"));
    } else {
        panic!("Response record failed");
    }
}

/// ✅ Test frontend activity
#[tokio::test]
async fn test_frontend_activity() {
    let (ai_state, storage) = setup().await;
    let req = Request::RecordFrontendActivity {
        session_id: "sess_001".into(),
        action: "Button Click".into(),
    };

    let resp = handle_request(req, ai_state, storage).await;
    if let Response::Success { data } = resp {
        assert!(data.contains("recorded"));
    } else {
        panic!("Activity record failed");
    }
}

/// ✅ Test code change recording and retrieval
#[tokio::test]
async fn test_code_change_flow() {
    let (ai_state, storage) = setup().await;

    let record_req = Request::RecordCodeChange {
        session_id: "sess_code_1".into(),
        file_path: "src/main.rs".into(),
        diff: "fn main() {}".into(),
        commit_message: "Initial commit".into(),
    };

    let resp = handle_request(record_req, ai_state.clone(), storage.clone()).await;
    assert!(matches!(resp, Response::Success { .. }));

    let fetch_req = Request::GetCodeChanges {
        session_id: "sess_code_1".into(),
    };

    let resp = handle_request(fetch_req, ai_state, storage).await;
    if let Response::Success { data } = resp {
        assert!(data.contains("Initial commit"));
    } else {
        panic!("Fetch code change failed");
    }
}
