use super::prompt::Prompt;
use crate::storage::{db, state::StrongHandle};
use chrono::Utc;
use once_cell::sync::OnceCell;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Clone)]
pub struct PromptManager {
    prompts: Arc<Mutex<HashMap<String, Vec<Prompt>>>>,
    responses: Arc<Mutex<HashMap<String, String>>>,
}

impl PromptManager {
    pub fn new() -> Self {
        Self {
            prompts: Arc::new(Mutex::new(HashMap::new())),
            responses: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// --- Singleton Global Instance ---
    pub fn global() -> &'static PromptManager {
        static INSTANCE: OnceCell<PromptManager> = OnceCell::new();
        INSTANCE.get_or_init(|| PromptManager::new())
    }

    /// Add a new prompt to a session
    pub async fn add_prompt(&self, session_id: &str, prompt: Prompt) {
        let mut map = self.prompts.lock().await;
        map.entry(session_id.to_string()).or_default().push(prompt);
    }

    /// Get all prompts for a session
    #[allow(dead_code)]
    pub async fn get_prompts(&self, session_id: &str) -> Option<Vec<Prompt>> {
        let map = self.prompts.lock().await;
        map.get(session_id).cloned()
    }

    /// Clear all prompts for a session
    #[allow(dead_code)]
    pub async fn clear_prompts(&self, session_id: &str) {
        let mut map = self.prompts.lock().await;
        map.remove(session_id);
    }

    /// Count prompts for a session
    #[allow(dead_code)]
    pub async fn prompt_count(&self, session_id: &str) -> usize {
        let map = self.prompts.lock().await;
        map.get(session_id).map(|v| v.len()).unwrap_or(0)
    }

    // ----------------------------------------------------------
    // 🧠 UPDATED SECTION: Streaming + DB persistence
    // ----------------------------------------------------------

    /// Append chunks during streaming and persist if `storage` provided
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

    /// Retrieve last in-memory response
    pub async fn get_response(&self, session_id: &str) -> Option<String> {
        let responses = self.responses.lock().await;
        responses.get(session_id).cloned()
    }

    /// Clear all responses for a session
    #[allow(dead_code)]
    pub async fn clear_response(&self, session_id: &str) {
        let mut responses = self.responses.lock().await;
        responses.remove(session_id);
    }
}
