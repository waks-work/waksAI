use std::sync::Arc;

use super::backend_bridge::handle_request;
use super::channel::make_channels;
use super::protocol::Request;
use crate::ai::state::AppState;
use crate::storage::state::StrongHandle;

pub async fn start(
    ai_state: Arc<AppState>,
    storage: StrongHandle,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let (req_tx, mut req_rx, res_tx, mut res_rx) = make_channels();

    //  spawn requests
    let ai_clone = ai_state.clone();
    let storage_clone = storage.clone();
    tokio::spawn(async move {
        while let Some(req) = req_rx.recv().await {
            let response = handle_request(req, ai_clone.clone(), storage_clone.clone()).await;
            if let Err(err) = res_tx.send(response).await {
                eprintln!("Failed to send response: {err}");
            }
        }
    });

    req_tx
        .send(Request::Generate {
            prompt: "Hello AI".into(),
        })
        .await
        .map_err(|err| format!("Send error: {err}"))?;

    while let Some(res) = res_rx.recv().await {
        println!("Frontend got response: {:?}", res);
    }

    Ok(())
}
