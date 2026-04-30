use crate::ai::{generator, registry, session};
use axum::{routing::post, Router};
use reqwest::Client;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::info;

mod ai;
mod communication;
mod storage;

pub async fn run_server() {
    if let Err(e) = storage::db::init().await {
        eprintln!("DB init failed: {e}");
        return;
    }

    let _session_manager = session::SessionManager::new();
    let _prompt_manager = session::PromptManager::new();

    let strong_handle = storage::state::StrongHandle::new();
    let state = ai::generator::AppState {
        sessions: Arc::new(Mutex::new(HashMap::new())),
        client: Client::new(),
        registry: Arc::new(registry::provider_registry()),
    };

    if let Err(e) = communication::initializer::initialize_communications(
        state.clone().into(),
        strong_handle.clone(),
    )
    .await
    {
        eprintln!("Communication init failed: {e}");
        return;
    }
    let app = Router::new()
        .route("/generate", post(generator::generate))
        .route("/stream", post(generator::stream_generate))
        .route("/activity", post(storage::handler::handle_record_activity))
        .route("/code_change", post(storage::handler::handle_code_change))
        .route(
            "/session_status",
            post(storage::handler::handle_session_status),
        )
        .with_state(state);
    let addr = std::net::SocketAddr::from(([127, 0, 0, 1], 11500));

    info!("waksAI backend running on http://{}", addr);

    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Port already in use, connecting to existing instance: {e}");
            return;
        }
    };
    if let Err(e) = axum::serve(listener, app).await {
        eprintln!("Server error: {e}");
    }
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    run_server().await;
}
