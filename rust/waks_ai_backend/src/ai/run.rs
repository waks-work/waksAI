use axum::{routing::post, Router};
use tracing::info;

use crate::{
    ai::{
        generator::{generate, stream_generate},
        registry::provider_registry,
        state::AppState,
    },
    communication,
    storage::{self, db, state::StrongHandle},
};

use reqwest::Client;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

pub async fn run_server() {
    let strong_handle = StrongHandle::new();
    // if let Err(e) = db::init().await {
    //  eprintln!("Failed to initialize DB: {}", e);
    // return;
    // }
    let state = AppState {
        sessions: Arc::new(Mutex::new(HashMap::new())),
        client: Client::new(),
        registry: Arc::new(provider_registry()),
    };

    communication::init(state.clone().into(), strong_handle.clone())
        .await
        .unwrap();

    let app = Router::new()
        .route("/generate", post(generate))
        .route("/stream", post(stream_generate))
        .with_state(state);

    let addr = std::net::SocketAddr::from(([127, 0, 0, 1], 11500));
    info!("waksAI backend running on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
