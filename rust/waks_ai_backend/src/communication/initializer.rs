use crate::communication::manager;
use crate::{ai, storage};
use std::sync::Arc;
use tokio::sync::mpsc;

pub type AppResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

pub type RequestSender = mpsc::Sender<manager::Request>;
pub type RequestReceiver = mpsc::Receiver<manager::Request>;
pub type ResponseSender = mpsc::Sender<manager::Response>;
pub type ResponseReceiver = mpsc::Receiver<manager::Response>;

pub fn make_channels() -> (
    RequestSender,
    RequestReceiver,
    ResponseSender,
    ResponseReceiver,
) {
    let (req_tx, req_rx) = mpsc::channel(100);
    let (res_tx, res_rx) = mpsc::channel(100);
    (req_tx, req_rx, res_tx, res_rx)
}

pub async fn communication_channel(
    ai_state: Arc<ai::generator::AppState>,
    storage: storage::state::StrongHandle,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let (req_tx, mut req_rx, res_tx, mut res_rx) = make_channels();

    let ai_clone = ai_state.clone();
    let storage_clone = storage.clone();
    tokio::spawn(async move {
        while let Some(req) = req_rx.recv().await {
            let response =
                manager::request_manager(req, ai_clone.clone(), storage_clone.clone()).await;
            if let Err(err) = res_tx.send(response).await {
                eprintln!("Failed to send response: {err}");
            }
        }
    });

    req_tx
        .send(manager::Request::Generate {
            prompt: "Hello AI".into(),
        })
        .await
        .map_err(|err| format!("Send error: {err}"))?;

    while let Some(res) = res_rx.recv().await {
        println!("Frontend got response: {:?}", res);
    }

    Ok(())
}

pub async fn initialize_communications(
    ai_state: Arc<ai::generator::AppState>,
    storage: storage::state::StrongHandle,
) -> AppResult<()> {
    tokio::spawn(async move {
        if let Err(e) = communication_channel(ai_state.clone(), storage.clone()).await {
            eprintln!("Frontend bridge error: {e:?}");
        }
    });

    Ok(())
}
