use reqwest::Client;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

use crate::ai::generator;
use crate::ai::provider::Message;
use crate::ai::registry::ProviderConfig;

use super::registry::Provider;
use super::session::{PromptManager, SessionManager};

#[derive(Clone)]
pub struct AppState {
    pub sessions: Arc<Mutex<HashMap<String, Vec<Message>>>>,
    pub client: Client,
    pub registry: Arc<HashMap<Provider, ProviderConfig>>,
}

impl AppState {
    pub async fn run(
        &self,
        prompt: String,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let session_manager = SessionManager::global().await;
        let prompt_manager = PromptManager::global().clone();
        generator::generate_text(self.clone(), session_manager, prompt_manager, prompt).await
    }
}
