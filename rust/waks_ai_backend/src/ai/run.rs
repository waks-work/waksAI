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
<<<<<<< HEAD
    if let Err(e) = db::init().await {
        eprintln!("DB init failed: {e}");
        return;
    }

    let strong_handle = StrongHandle::new();
=======
    let strong_handle = StrongHandle::new();
    // if let Err(e) = db::init().await {
    //  eprintln!("Failed to initialize DB: {}", e);
    // return;
    // }
>>>>>>> c7277b6daca621643918d9cab9510edec67d0fce
    let state = AppState {
        sessions: Arc::new(Mutex::new(HashMap::new())),
        client: Client::new(),
        registry: Arc::new(provider_registry()),
    };

<<<<<<< HEAD
    if let Err(e) = communication::init(state.clone().into(), strong_handle.clone()).await {
        eprintln!("Communication init failed: {e}");
        return;
    }
=======
    communication::init(state.clone().into(), strong_handle.clone())
        .await
        .unwrap();
>>>>>>> c7277b6daca621643918d9cab9510edec67d0fce

    let app = Router::new()
        .route("/generate", post(generate))
        .route("/stream", post(stream_generate))
        .with_state(state);

    let addr = std::net::SocketAddr::from(([127, 0, 0, 1], 11500));
    info!("waksAI backend running on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
<<<<<<< HEAD
    if let Err(e) = axum::serve(listener, app).await {
        eprintln!("Server error: {e}");
    }
=======
    axum::serve(listener, app).await.unwrap();
>>>>>>> c7277b6daca621643918d9cab9510edec67d0fce
}
