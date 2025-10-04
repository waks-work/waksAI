use axum::http::StatusCode;
use serde_json::Value;

/// Generic helper to extract text from an OpenAI-like response structure
fn extract_openai_like(json: &Value) -> Option<String> {
    json.get("choices")?
        .get(0)?
        .get("message")?
        .get("content")?
        .as_str()
        .map(|s| s.to_string())
}

/// Parser for OpenAI-compatible APIs (OpenAI, Mistral, etc.)
pub fn parse_openai_like(body: &str) -> Result<String, (StatusCode, String)> {
    let json: Value = serde_json::from_str(body)
        .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
    extract_openai_like(&json).ok_or((StatusCode::BAD_GATEWAY, "Malformed response".into()))
}

/// Parser for Ollama responses
pub fn parse_ollama(body: &str) -> Result<String, (StatusCode, String)> {
    let json: Value = serde_json::from_str(body)
        .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
    json.get("response")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .ok_or((StatusCode::BAD_GATEWAY, "Malformed Ollama response".into()))
}

/// Parser for Anthropic (Claude)
pub fn parse_anthropic(body: &str) -> Result<String, (StatusCode, String)> {
    let json: Value = serde_json::from_str(body)
        .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
    json.get("content")
        .and_then(|arr| arr.get(0))
        .and_then(|c| c.get("text"))
        .and_then(|t| t.as_str())
        .map(|s| s.to_string())
        .ok_or((
            StatusCode::BAD_GATEWAY,
            "Malformed Anthropic response".into(),
        ))
}

/// Parser for Cohere
pub fn parse_cohere(body: &str) -> Result<String, (StatusCode, String)> {
    let json: Value = serde_json::from_str(body)
        .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
    json.get("generations")
        .and_then(|arr| arr.get(0))
        .and_then(|c| c.get("text"))
        .and_then(|t| t.as_str())
        .map(|s| s.to_string())
        .ok_or((StatusCode::BAD_GATEWAY, "Malformed Cohere response".into()))
}

/// Parser for Hugging Face Inference API
pub fn parse_huggingface(body: &str) -> Result<String, (StatusCode, String)> {
    let json: Value = serde_json::from_str(body)
        .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
    if let Some(arr) = json.as_array() {
        arr.get(0)
            .and_then(|obj| obj.get("generated_text"))
            .and_then(|t| t.as_str())
            .map(|s| s.to_string())
            .ok_or((
                StatusCode::BAD_GATEWAY,
                "Malformed HuggingFace response".into(),
            ))
    } else {
        Err((
            StatusCode::BAD_GATEWAY,
            "Unexpected HuggingFace response".into(),
        ))
    }
}
