use axum::{
    extract::State,
    response::sse::{Event, Sse},
    routing::post,
    Json, Router,
};
use futures::{Stream, StreamExt};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    net::SocketAddr,
    sync::{Arc, Mutex},
};
use tracing::info;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Message {
    role: String,
    content: String,
}

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

#[derive(Debug, Deserialize)]
struct OllamaGenerateResponse {
    response: String,
}

#[derive(Debug, Deserialize)]
struct OllamaStreamResponse {
    response: String,
    done: bool,
}

#[derive(Clone)]
struct AppState {
    sessions: Arc<Mutex<HashMap<String, Vec<Message>>>>,
    client: Client,
}

#[tokio::main]
async fn main() {
    // Initialize logging
    tracing_subscriber::fmt::init();

    let state = AppState {
        sessions: Arc::new(Mutex::new(HashMap::new())),
        client: Client::new(),
    };

    let app = Router::new()
        .route("/generate", post(generate))
        .route("/stream", post(stream_generate))
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 11500));
    info!("waksAI backend running on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Json<GenerateResp> {
    info!(
        "Processing generate request for session: {}",
        req.session_id
    );

    // Save session messages
    {
        let mut sessions = state.sessions.lock().unwrap();
        sessions
            .entry(req.session_id.clone())
            .or_default()
            .extend(req.messages.clone());
    }

    // Build prompt from all messages (not just user messages)
    let prompt = req
        .messages
        .iter()
        .map(|m| format!("{}: {}", m.role, m.content))
        .collect::<Vec<_>>()
        .join("\n");

    let response = state
        .client
        .post("http://localhost:11434/api/generate")
        .json(&serde_json::json!({
            "model": "deepseek-coder:1.3b",
            "prompt": prompt,
            "stream": false
        }))
        .send()
        .await
        .map_err(|e| {
            tracing::error!("Failed to send request to Ollama: {}", e);
            e
        })
        .unwrap();

    if !response.status().is_success() {
        tracing::error!("Ollama API returned error status: {}", response.status());
        return Json(GenerateResp {
            response: "Error: Failed to get response from AI model".to_string(),
        });
    }

    let ollama_response: OllamaGenerateResponse = response.json().await.unwrap_or_else(|e| {
        tracing::error!("Failed to parse Ollama response: {}", e);
        OllamaGenerateResponse {
            response: "Error: Invalid response from AI model".to_string(),
        }
    });

    Json(GenerateResp {
        response: ollama_response.response,
    })
}

async fn stream_generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Sse<impl Stream<Item = Result<Event, axum::Error>>> {
    info!(
        "Processing stream generate request for session: {}",
        req.session_id
    );

    // Save session messages
    {
        let mut sessions = state.sessions.lock().unwrap();
        sessions
            .entry(req.session_id.clone())
            .or_default()
            .extend(req.messages.clone());
    }

    // Build prompt from all messages
    let prompt = req
        .messages
        .iter()
        .map(|m| format!("{}: {}", m.role, m.content))
        .collect::<Vec<_>>()
        .join("\n");

    let resp = state
        .client
        .post("http://localhost:11434/api/generate")
        .json(&serde_json::json!({
            "model": "deepseek-coder:1.3b",
            "prompt": prompt,
            "stream": true
        }))
        .send()
        .await;

    let stream = async_stream::stream! {
        match resp {
            Ok(response) if response.status().is_success() => {
                let mut byte_stream = response.bytes_stream();
                while let Some(item) = byte_stream.next().await {
                    match item {
                        Ok(chunk) => {
                            let s = String::from_utf8_lossy(&chunk).to_string();
                            for line in s.lines() {
                                if let Ok(stream_response) = serde_json::from_str::<OllamaStreamResponse>(line) {
                                    if !stream_response.response.is_empty() {
                                        yield Ok(Event::default().data(stream_response.response));
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            tracing::error!("Error reading stream chunk: {}", e);
                            yield Ok(Event::default().data(format!("Error: {}", e)));
                        }
                    }
                }
            }
            Ok(response) => {
                tracing::error!("Ollama API returned error status: {}", response.status());
                yield Ok(Event::default().data("Error: Failed to get response from AI model"));
            }
            Err(e) => {
                tracing::error!("Failed to connect to Ollama: {}", e);
                yield Ok(Event::default().data(format!("Error: {}", e)));
            }
        }
    };

    Sse::new(stream)
}
