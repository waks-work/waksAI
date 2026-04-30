use crate::{ai, storage};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

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

pub async fn request_manager(
    req: Request,
    ai_state: Arc<ai::generator::AppState>,
    storage: storage::state::StrongHandle,
) -> Response {
    match req {
        Request::Generate { prompt } => match ai_state.run(prompt).await {
            Ok(output) => Response::Success { data: output },
            Err(e) => Response::Error {
                message: e.to_string(),
            },
        },

        Request::Save { key, value } => {
            storage.set(key.clone(), value.clone()).await;
            Response::Success {
                data: "request has been saved successfully".into(),
            }
        }

        Request::Fetch { key } => {
            let value = storage.get(&key).await.unwrap_or_default();
            Response::Success { data: value }
        }

        Request::RecordSession { session_id, status } => {
            let session = storage::db::AiSessionStatus {
                session_id: session_id.clone(),
                ai_model: "gpt-4o-mini".into(),
                provider: "openai".into(),
                user_prompt: None,
                system_prompt: None,
                metadata: None,
                status: Some(status),
                created_at: Some(Utc::now()),
                updated_at: Some(Utc::now()),
            };

            match storage.record_session(&session).await {
                Ok(_) => Response::Success {
                    data: format!("Session '{}' has been recorded", session_id),
                },
                Err(err) => Response::Error {
                    message: format!("Failed to record session: {}", err),
                },
            }
        }

        Request::RecordResponse {
            session_id,
            prompt: _,
            output,
        } => {
            let response = storage::db::AiResponse {
                id: 0,
                session_id: session_id.clone(),
                ai_response: output,
                tokens_used: Some(0),
                response_time_ms: Some(0),
                created_at: Some(Utc::now()),
            };

            match storage.record_response(&response).await {
                Ok(_) => Response::Success {
                    data: format!("Response for session '{}' has been stored", session_id),
                },
                Err(err) => Response::Error {
                    message: err.to_string(),
                },
            }
        }

        Request::RecordFrontendActivity { session_id, action } => {
            let activity = storage::db::FrontendActivity {
                activity_id: 0,
                session_id: Some(session_id.clone()),
                action,
                payload: None,
                timestamp: Some(Utc::now()),
            };

            match storage.record_frontend_activity(&activity).await {
                Ok(_) => Response::Success {
                    data: format!("🪶 Activity recorded for session '{}'", session_id),
                },
                Err(e) => Response::Error {
                    message: e.to_string(),
                },
            }
        }

        Request::RecordCodeChange {
            session_id,
            file_path,
            diff,
            commit_message,
        } => {
            let change = storage::db::CodeChange {
                code_change_id: 0,
                session_id: session_id.clone(),
                file_name: Some(file_path),
                previous_code: None,
                changed_code: Some(diff),
                description: Some(commit_message),
                backup_path: None,
                created_at: Some(Utc::now()),
            };

            match storage.record_code_change(&change).await {
                Ok(_) => Response::Success {
                    data: format!("Code change saved for '{}'", session_id),
                },
                Err(e) => Response::Error {
                    message: e.to_string(),
                },
            }
        }

        Request::GetCodeChanges { session_id } => match storage.get_code_changes(&session_id).await
        {
            Ok(changes) => {
                let json = serde_json::to_string_pretty(&changes).unwrap_or_default();
                Response::Success { data: json }
            }
            Err(e) => Response::Error {
                message: e.to_string(),
            },
        },
    }
}
