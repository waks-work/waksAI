use axum::http::StatusCode;
use serde_json::Value;

pub trait ResponseParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)>;
}

pub struct OpenAiParser;
pub struct AnthropicParser;
pub struct OllamaParser;
pub struct CohereParser;
pub struct HuggingFaceParser;

impl ResponseParser for OpenAiParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|err| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {}", err)))?;
        json.get("choices")
            .and_then(|con| con[0]["message"]["content"].as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed response".into()))
    }
}

impl ResponseParser for AnthropicParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|err| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {}", err)))?;
        json.get("content")
            .and_then(|con| con[0]["text"].as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed response".into()))
    }
}

impl ResponseParser for OllamaParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
        json.get("response")
            .and_then(|val| val.as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed Ollama response".into()))
    }
}

impl ResponseParser for CohereParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|err| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {err}")))?;
        json.get("generations")
            .and_then(|con| con[0]["text"].as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed Cohere response".into()))
    }
}

impl ResponseParser for HuggingFaceParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
        if let Some(arr) = json.as_array() {
            arr.get(0)
                .and_then(|obj| obj["generated_text"].as_str())
                .map(|st| st.to_string())
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
}
