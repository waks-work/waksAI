use axum::{
    extract::State,
    response::{sse::{Event, Sse}, IntoResponse},
    routing::post,
    Json, Router,
};
use futures::stream::{self, Stream};
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, net::SocketAddr, sync::{Arc, Mutex}, time::Duration};
use tokio::time::sleep;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Message { role: String, content: String }

#[derive(Debug, Deserialize)]
struct GenerateReq {
    session_id: String,
    messages: Vec<Message>,
    #[serde(default)]
    stream: bool,
}

#[derive(Debug, Serialize)]
struct GenerateResp {
    response: String,
}

#[derive(Clone, Default)]
struct AppState {
    sessions: Arc<Mutex<HashMap<String, Vec<Message>>>>,
}

#[tokio::main]
async fn main() {
    let state = AppState::default();
    let app = Router::new()
        .route("/generate", post(generate))
        .route("/stream", post(stream_generate))
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 11434));
    println!("waksAI backend on http://{addr}");
    axum::serve(tokio::net::TcpListener::bind(addr).await.unwrap(), app)
        .await
        .unwrap();
}

async fn generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> impl IntoResponse {
    let mut sessions = state.sessions.lock().unwrap();
    let history = sessions.entry(req.session_id.clone()).or_default();
    *history = req.messages.clone();

    // 👇 Replace this with a real model call (llama.cpp, gpt4all, etc.)
    // For now, concatenate the last user message with a friendly reply.
    let reply = match req.messages.iter().rev().find(|m| m.role == "user") {
        Some(msg) => format!("(assistant) I hear you: {}", msg.content),
        None => "(assistant) Hello! Ask me anything.".to_string(),
    };

    history.push(Message { role: "assistant".into(), content: reply.clone() });
    Json(GenerateResp { response: reply })
}

async fn stream_generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Sse<impl Stream<Item = Result<Event, axum::Error>>> {
    {
        let mut sessions = state.sessions.lock().unwrap();
        let history = sessions.entry(req.session_id.clone()).or_default();
        *history = req.messages.clone();
    }

    // Simulate token streaming
    let text = match req.messages.iter().rev().find(|m| m.role == "user") {
        Some(msg) => format!("Streaming: {}", msg.content),
        None => "Streaming: Hello!".into(),
    };

    let chunks: Vec<String> = text
        .split_whitespace()
        .map(|s| s.to_string())
        .collect();

    let stream = stream::iter(chunks.into_iter()).then(|tok| async move {
        sleep(Duration::from_millis(80)).await;
        Ok(Event::default().data(tok))
    });

    Sse::new(stream)
}


// RUNS ON: http://127.0.0.1:11434/generate


