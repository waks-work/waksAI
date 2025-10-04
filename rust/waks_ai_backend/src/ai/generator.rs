use axum::{
    extract::State,
    http::StatusCode,
    response::{
        sse::{Event, Sse},
        IntoResponse, Json, Response,
    },
};
use futures::Stream;
use std::convert::Infallible;

use crate::ai::provider::{GenerateReq, GenerateResp, Message};
use crate::ai::state::AppState;
#[warn(unused_import)]
use crate::ai::stream::StreamType;

use tracing::info;

async fn setup_request(
    sessions: &std::sync::Arc<tokio::sync::Mutex<std::collections::HashMap<String, Vec<Message>>>>,
    req: &GenerateReq,
) {
    if let Some(session_id) = &req.session_id {
        info!(
            "Processing session: {}, provider: {}",
            session_id, req.provider
        );
        let mut sessions_lock = sessions.lock().await;
        sessions_lock
            .entry(session_id.clone())
            .or_default()
            .extend(req.messages.clone());
    }
}

pub async fn generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Result<Response, (StatusCode, String)> {
    setup_request(&state.sessions, &req).await;

    let provider_config = state
        .registry
        .get(req.provider.as_str())
        .ok_or((StatusCode::BAD_REQUEST, "Unsupported provider".into()))?;

    let (url, headers, body) = (provider_config.build_request)(&req)?;
    let mut builder = state.client.post(&url);
    for (k, v) in headers {
        builder = builder.header(&k, &v);
    }

    let resp = builder
        .json(&body)
        .send()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if !resp.status().is_success() {
        return Err((resp.status(), resp.text().await.unwrap_or_default()));
    }

    let text = resp
        .text()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    let parsed = (provider_config.parse_response)(&text)?;
    Ok(Json(GenerateResp { response: parsed }).into_response())
}

pub async fn stream_generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Result<Sse<impl Stream<Item = Result<Event, Infallible>>>, (StatusCode, String)> {
    setup_request(&state.sessions, &req).await;

    let provider_config = state
        .registry
        .get(req.provider.as_str())
        .ok_or((StatusCode::BAD_REQUEST, "Unsupported provider".into()))?;

    let create_stream_fn = provider_config
        .create_stream
        .as_ref()
        .ok_or((StatusCode::BAD_REQUEST, "Streaming not supported".into()))?;

    let (url, headers, body) = (provider_config.build_request)(&req)?;
    let mut builder = state.client.post(&url);
    for (k, v) in headers {
        builder = builder.header(&k, &v);
    }

    let resp = builder
        .json(&body)
        .send()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if !resp.status().is_success() {
        return Err((resp.status(), resp.text().await.unwrap_or_default()));
    }

    let stream = (create_stream_fn)(resp, req.provider.clone());
    Ok(Sse::new(stream))
}
