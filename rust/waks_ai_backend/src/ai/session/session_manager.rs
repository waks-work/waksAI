use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

use once_cell::sync::OnceCell;

#[derive(Clone)]
pub struct SessionManager {
    active_sessions: Arc<RwLock<HashMap<String, bool>>>,
}

impl SessionManager {
    pub fn new() -> Self {
        Self {
            active_sessions: Arc::new(RwLock::new(HashMap::new())),
        }
    }
    pub async fn global() -> Self {
        static INSTANCE: OnceCell<SessionManager> = OnceCell::new();
        INSTANCE.get_or_init(|| SessionManager::new()).clone()
    }

    pub async fn register(&self, session_id: &str) {
        let mut sessions = self.active_sessions.write().await;
        sessions.insert(session_id.to_string(), true);
    }

    pub async fn unregister(&self, session_id: &str) {
        let mut sessions = self.active_sessions.write().await;
        sessions.remove(session_id);
    }

    #[allow(dead_code)]
    pub async fn is_active(&self, session_id: &str) -> bool {
        let sessions = self.active_sessions.read().await;
        sessions.contains_key(session_id)
    }

    #[allow(dead_code)]
    pub async fn count(&self) -> usize {
        self.active_sessions.read().await.len()
    }

    #[allow(dead_code)]
    pub async fn list(&self) -> Vec<String> {
        let sessions = self.active_sessions.read().await;
        sessions.keys().cloned().collect()
    }
}
