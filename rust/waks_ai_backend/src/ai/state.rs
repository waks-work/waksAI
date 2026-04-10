use crate::ai;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Clone)]
pub struct AppState {
    pub sessions: Arc<Mutex<HashMap<String, Vec<ai::provider::Message>>>>,
    pub client: reqwest::Client,
    pub registry: Arc<HashMap<ai::provider::Provider, ai::registry::ProviderConfig>>,
}

impl AppState {
    pub async fn run(
        &self,
        prompt: String,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let session_manager = ai::session::SessionManager::global().await;
        let prompt_manager = ai::session::PromptManager::global().clone();
        ai::generator::generate_text(self.clone(), session_manager, prompt_manager, prompt).await
    }
}
