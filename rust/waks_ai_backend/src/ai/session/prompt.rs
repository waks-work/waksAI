use crate::storage::{db, state::StrongHandle};
use chrono::Utc;
use once_cell::sync::OnceCell;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Prompt {
    pub id: String,
    pub content: String,
    pub marker: String,
    pub source: String,
}

#[derive(Clone)]
pub struct PromptManager {
    prompts: Arc<Mutex<HashMap<String, Vec<Prompt>>>>,
    responses: Arc<Mutex<HashMap<String, String>>>,
}

impl Prompt {
    pub fn new(
        content: impl Into<String>,
        source: impl Into<String>,
        marker: impl Into<String>,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            content: content.into(),
            marker: marker.into(),
            source: source.into(),
        }
    }
}

impl PromptManager {
    pub fn new() -> Self {
        Self {
            prompts: Arc::new(Mutex::new(HashMap::new())),
            responses: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn global() -> &'static PromptManager {
        static INSTANCE: OnceCell<PromptManager> = OnceCell::new();
        INSTANCE.get_or_init(|| PromptManager::new())
    }

    pub async fn add_prompt(&self, session_id: &str, prompt: Prompt) {
        let mut map = self.prompts.lock().await;
        map.entry(session_id.to_string()).or_default().push(prompt);
    }

    #[allow(dead_code)]
    pub async fn get_prompts(&self, session_id: &str) -> Option<Vec<Prompt>> {
        let map = self.prompts.lock().await;
        map.get(session_id).cloned()
    }

    #[allow(dead_code)]
    pub async fn clear_prompts(&self, session_id: &str) {
        let mut map = self.prompts.lock().await;
        map.remove(session_id);
    }

    #[allow(dead_code)]
    pub async fn prompt_count(&self, session_id: &str) -> usize {
        let map = self.prompts.lock().await;
        map.get(session_id).map(|v| v.len()).unwrap_or(0)
    }

    // in stream
    pub async fn update_response(
        &self,
        session_id: &str,
        new_chunk: &str,
        storage: Option<&StrongHandle>,
    ) {
        let mut responses = self.responses.lock().await;
        let entry = responses.entry(session_id.to_string()).or_default();
        entry.push_str(new_chunk);

        // Optional DB sync
        if let Some(store) = storage {
            let response = db::AiResponse {
                id: 0,
                session_id: session_id.to_string(),
                ai_response: entry.clone(),
                tokens_used: Some(0),
                response_time_ms: Some(0),
                created_at: Some(Utc::now()),
            };

            if let Err(e) = store.record_response(&response).await {
                eprintln!("⚠️ Failed to sync streamed response to DB: {e}");
            }
        }
    }

    // last in mem
    pub async fn get_response(&self, session_id: &str) -> Option<String> {
        let responses = self.responses.lock().await;
        responses.get(session_id).cloned()
    }

    #[allow(dead_code)]
    pub async fn clear_response(&self, session_id: &str) {
        let mut responses = self.responses.lock().await;
        responses.remove(session_id);
    }
}
