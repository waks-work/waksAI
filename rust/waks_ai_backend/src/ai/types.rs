use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Message {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct GenerateReq {
    pub provider: String,
    pub model: String,
    pub messages: Vec<Message>,
    pub stream: bool,
    pub api_key: Option<String>,
    pub session_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct GenerateResp {
    pub response: String,
}
