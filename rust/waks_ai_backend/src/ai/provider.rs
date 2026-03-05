use axum::http::StatusCode;
use serde::{Deserialize, Serialize};
use serde_json::json;

use super::registry::Provider;

//---------------------------------
// Request + Response Types
//---------------------------------
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Message {
    pub role: String,
    pub content: String,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct GenerateReq {
    pub provider: Provider,
    pub model: String,
    pub messages: Vec<Message>,
    pub stream: bool,
    pub api_key: Option<String>,
    pub session_id: Option<String>,
    pub agent_mode: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct GenerateResp {
    pub response: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
pub struct OllamaGenerateResponse {
    pub response: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
pub struct OllamaStreamResponse {
    pub response: String,
    #[serde(default)]
    pub done: bool,
}

/// Accepts the user input and builds the prompt for the llm
pub fn build_legacy_prompt(messages: &[Message]) -> String {
    messages
        .iter()
        .map(|m| format!("{}: {}", m.role, m.content))
        .collect::<Vec<_>>()
        .join("\n")
}

/// Builds all the prompts for all providers with same llm structure as openai.
pub fn build_openai_like(
    url: &str,
    provider: &str,
    req: &GenerateReq,
) -> Result<(String, Vec<(String, String)>, serde_json::Value), (StatusCode, String)> {
    let api_key = req.api_key.clone().ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            format!("API key required for {}", provider),
        )
    })?;

    Ok((
        url.to_string(),
        vec![("Authorization".to_string(), format!("Bearer {}", api_key))],
        json!({
            "model": req.model,
            "messages": req.messages,
            "stream": req.stream
        }),
    ))
}

/// Builds all the prompts for local models.
pub fn build_ollama(
    req: &GenerateReq,
) -> Result<(String, Vec<(String, String)>, serde_json::Value), (StatusCode, String)> {
    Ok((
        "http://localhost:11434/api/generate".to_string(),
        vec![],
        json!({
            "model": req.model,
            "prompt": build_legacy_prompt(&req.messages),
            "stream": req.stream
        }),
    ))
}

pub fn build_ollama_chat(
    req: &GenerateReq,
) -> Result<(String, Vec<(String, String)>, serde_json::Value), (StatusCode, String)> {
    Ok((
        "http://localhost:11434/v1/chat/completions".to_string(),
        vec![(
            "Authorization".to_string(),
            format!("Bearer {}", req.api_key.as_deref().unwrap_or("ollama")),
        )],
        json!({
            "model": req.model,
            "messages": req.messages,
            "stream": req.stream
        }),
    ))
}

pub fn build_anthropic(
    req: &GenerateReq,
) -> Result<(String, Vec<(String, String)>, serde_json::Value), (StatusCode, String)> {
    let api_key = req.api_key.clone().ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            "API key required for Anthropic".into(),
        )
    })?;

    Ok((
        "https://api.anthropic.com/v1/messages".to_string(),
        vec![
            ("x-api-key".to_string(), api_key),
            ("anthropic-version".to_string(), "2023-06-01".to_string()),
            ("content-type".to_string(), "application/json".to_string()),
        ],
        json!({
            "model": req.model,
            "max_tokens": 1024,
            "messages": req.messages
        }),
    ))
}

pub fn build_cohere(
    req: &GenerateReq,
) -> Result<(String, Vec<(String, String)>, serde_json::Value), (StatusCode, String)> {
    let api_key = req.api_key.clone().ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            "API key required for Cohere".into(),
        )
    })?;

    Ok((
        "https://api.cohere.ai/v1/chat".to_string(),
        vec![
            ("Authorization".to_string(), format!("Bearer {}", api_key)),
            ("Content-Type".to_string(), "application/json".to_string()),
        ],
        json!({
            "model": req.model,
            "message": req.messages.last().map(|m| m.content.clone()).unwrap_or_default()
        }),
    ))
}

pub fn build_huggingface(
    req: &GenerateReq,
) -> Result<(String, Vec<(String, String)>, serde_json::Value), (StatusCode, String)> {
    let api_key = req.api_key.clone().ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            "API key required for HuggingFace".into(),
        )
    })?;

    Ok((
        format!("https://api-inference.huggingface.co/models/{}", req.model),
        vec![("Authorization".to_string(), format!("Bearer {}", api_key))],
        json!({
            "inputs": req.messages.last().map(|m| m.content.clone()).unwrap_or_default()
        }),
    ))
}
