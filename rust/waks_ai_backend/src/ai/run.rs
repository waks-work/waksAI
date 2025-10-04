use axum::{routing::post, Router};
use tracing::info;

#[warn(unused_import)]
use crate::ai::provider::Message;

use crate::ai::{
    generator::{generate, stream_generate},
    registry::provider_registry,
    state::AppState,
};
use reqwest::Client;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

pub async fn run_server() {
    let state = AppState {
        sessions: Arc::new(Mutex::new(HashMap::new())),
        client: Client::new(),
        registry: Arc::new(provider_registry()),
    };

    let app = Router::new()
        .route("/generate", post(generate))
        .route("/stream", post(stream_generate))
        .with_state(state);

    let addr = std::net::SocketAddr::from(([127, 0, 0, 1], 11500));
    info!("waksAI backend running on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
