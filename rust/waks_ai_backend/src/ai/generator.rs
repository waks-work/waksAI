use axum::{
    extract::State,
    http::StatusCode,
    response::{
        sse::{Event, Sse},
        IntoResponse, Json, Response,
    },
};
use futures::{Stream, StreamExt};
use std::{convert::Infallible, path::PathBuf, sync::Arc};
use tracing::info;

use crate::ai::{
    agent::manager::AgentManager,
    provider::{GenerateReq, GenerateResp, Message},
    registry::Provider,
    session::{Prompt, PromptManager, SessionManager},
    state::AppState,
};

/// --- Helper: Register and sync prompt history ---
async fn setup_request_with_sessions(
    sessions: &Arc<tokio::sync::Mutex<std::collections::HashMap<String, Vec<Message>>>>,
    req: &GenerateReq,
    session_manager: &SessionManager,
    prompt_manager: &PromptManager,
) {
    if let Some(session_id) = &req.session_id {
        session_manager.register(session_id).await;

        let mut sessions_lock = sessions.lock().await;
        sessions_lock
            .entry(session_id.clone())
            .or_default()
            .extend(req.messages.clone());

        for msg in &req.messages {
            prompt_manager
                .add_prompt(
                    session_id,
                    Prompt::new(
                        msg.content.clone(),
                        msg.role.clone(),
                        req.provider.clone().to_string(),
                    ),
                )
                .await;
        }

        // Default rules injected as system messages
        let default_rules = vec![
            "Always reason step-by-step",
            "Be concise and clear",
            "Follow safety constraints",
        ];
        for rule in default_rules {
            sessions_lock
                .entry(session_id.clone())
                .or_default()
                .push(Message {
                    role: "system".to_string(),
                    content: rule.to_string(),
                });
        }

        info!(
            "Session {} initialized with {} messages",
            session_id,
            req.messages.len()
        );
    }
}

/// --- Non-Streaming Text Generation ---
pub async fn generate_text(
    state: AppState,
    session_manager: SessionManager,
    prompt_manager: PromptManager,
    prompt: String,
) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    let session_id = "internal".to_string();
    session_manager.register(&session_id).await;

    prompt_manager
        .add_prompt(
            &session_id,
            Prompt::new(prompt.clone(), "user", "generator".to_string()),
        )
        .await;

    let req = GenerateReq {
        provider: Provider::Ollama,
        model: "llama2".to_string(),
        messages: vec![Message {
            role: "user".to_string(),
            content: prompt.clone(),
        }],
        stream: false,
        api_key: None,
        session_id: Some(session_id.clone()),
        agent_mode: Some(true),
    };

    let provider_config = state
        .registry
        .get(&req.provider)
        .ok_or("Unsupported provider")?;
    let (url, headers, body) = (provider_config.build_request)(&req)
        .map_err(|e| format!("Request build error: {:?}", e))?;

    let mut builder = state.client.post(&url);
    for (k, v) in headers {
        builder = builder.header(&k, &v);
    }

    let resp = builder.json(&body).send().await?;
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(format!("Request failed: {}", text).into());
    }

    let text = resp.text().await?;
    let parsed = (provider_config.parser.parse(&text))
        .map_err(|e| format!("Response parse error: {:?}", e))?;

    // Save assistant response
    prompt_manager
        .add_prompt(
            &session_id,
            Prompt::new(parsed.clone(), "assistant", "generator".to_string()),
        )
        .await;

    session_manager.unregister(&session_id).await;
    Ok(parsed)
}

/// --- Non-Streaming Generation Route ---
pub async fn generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Result<Response, (StatusCode, String)> {
    let session_manager = SessionManager::global().await;
    let prompt_manager = PromptManager::global();

    setup_request_with_sessions(&state.sessions, &req, &session_manager, &prompt_manager).await;

    let session_id = req
        .session_id
        .clone()
        .unwrap_or_else(|| "internal".to_string());

    // Start AgentManager if agent_mode is enabled
    if req.agent_mode.unwrap_or(false) {
        let home_dir = std::env::var("HOME").unwrap_or_else(|_| ".".into());
        let rules_file = PathBuf::from(format!("{}/.config/nvim/ai/user_rules.txt", home_dir));
        let agent_manager = AgentManager::new(
            Arc::new(session_manager.clone()),
            Arc::new(prompt_manager.clone()),
            rules_file,
        );
        agent_manager.start_agent(&session_id).await;
    }

    let provider_config = state
        .registry
        .get(&req.provider)
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
    let parsed = (provider_config.parser.parse(&text))?;

    if req.session_id.is_some() {
        prompt_manager
            .update_response(&session_id, &parsed, None)
            .await;
    }

    Ok(Json(GenerateResp { response: parsed }).into_response())
}

/// --- Streaming Generation Route (SSE) ---
pub async fn stream_generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Result<Sse<impl Stream<Item = Result<Event, Infallible>>>, (StatusCode, String)> {
    let session_manager = SessionManager::global().await;
    let prompt_manager = PromptManager::global();

    setup_request_with_sessions(&state.sessions, &req, &session_manager, &prompt_manager).await;

    let provider_config = state
        .registry
        .get(&req.provider)
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

    let session_id = req
        .session_id
        .clone()
        .unwrap_or_else(|| "internal".to_string());

    if req.agent_mode.unwrap_or(false) {
        let home_dir = std::env::var("HOME").unwrap_or_else(|_| ".".into());
        let rules_file = PathBuf::from(format!("{}/.config/nvim/ai/user_rules.txt", home_dir));
        let agent_manager = AgentManager::new(
            Arc::new(session_manager.clone()),
            Arc::new(prompt_manager.clone()),
            rules_file,
        );
        agent_manager.start_agent(&session_id).await;
    }

    let user_prompt = req
        .messages
        .iter()
        .rev()
        .find(|m| m.role == "user")
        .map(|m| m.content.clone())
        .unwrap_or_default();

    let base_stream = (create_stream_fn)(resp, req.provider.clone().to_string(), user_prompt);

    let wrapped_stream = async_stream::stream! {
        let mut stream = Box::pin(base_stream);

        while let Some(event_res) = stream.next().await {
            if let Ok(event) = &event_res {
                let data_str = format!("{:?}", event);
                if !data_str.trim().is_empty() {
                    let pm = prompt_manager.clone();
                    let sid = session_id.clone();

                    tokio::spawn(async move {
                        let _ = pm.update_response(&sid, &data_str, None).await;
                    });
                }
            }
            yield event_res;
        }
    };

    Ok(Sse::new(wrapped_stream))
}
