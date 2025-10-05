use std::sync::Arc;

use super::protocol::{Request, Response};
use crate::ai::state::AppState;
use crate::storage::state::StrongHandle;

/// Dispatches frontend requests to AI or storage
pub async fn handle_request(
    req: Request,
    ai_state: Arc<AppState>,
    storage: StrongHandle,
) -> Response {
    match req {
        Request::Generate { prompt } => match ai_state.run(prompt).await {
            Ok(output) => Response::Success { data: output },
            Err(e) => Response::Error {
                message: e.to_string(),
            },
        },
        Request::Save { key, value } => {
            storage.set(key.clone(), value.clone()).await; // set returns ()
            Response::Success {
                data: "saved".into(),
            }
        }
        Request::Fetch { key } => {
            let value = storage.get(&key).await.unwrap_or_default();
            Response::Success { data: value }
        }
    }
}
