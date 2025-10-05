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

use tracing::info;

pub async fn generate_text(
    state: AppState,
    prompt: String,
) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    // Create internal GenerateReq
    let req = GenerateReq {
        provider: "default".to_string(),    // pick your default provider
        model: "default-model".to_string(), // default model if needed
        messages: vec![Message {
            role: "user".to_string(),
            content: prompt,
        }],
        stream: false,
        api_key: None,
        session_id: Some("internal".to_string()),
    };

    // Setup session memory
    if let Some(session_id) = &req.session_id {
        let mut sessions_lock = state.sessions.lock().await;
        sessions_lock
            .entry(session_id.clone())
            .or_default()
            .extend(req.messages.clone());
    }

    // Get provider config
    let provider_config = state
        .registry
        .get(req.provider.as_str())
        .ok_or("Unsupported provider")?;

    // Build request
    let (url, headers, _body) = (provider_config.build_request)(&req)
        .map_err(|(status, msg)| format!("Request build error: {} {:?}", status, msg))?;

    // Send request
    let mut builder = state.client.post(&url);
    for (k, v) in headers {
        builder = builder.header(&k, &v);
    }

    let resp = builder.send().await?;
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(format!("Request failed: {}", text).into());
    }

    let text = resp.text().await?;
    let parsed = (provider_config.parse_response)(&text)
        .map_err(|(status, msg)| format!("Parse error: {} {:?}", status, msg))?;
    Ok(parsed)
}

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
