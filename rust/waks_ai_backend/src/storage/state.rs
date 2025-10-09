use crate::storage::{db, file, git};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Central memory + persistence layer
#[derive(Clone)]
pub struct StrongHandle {
    memory: Arc<Mutex<HashMap<String, String>>>,
}

impl StrongHandle {
    pub fn new() -> Self {
        StrongHandle {
            memory: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    // ======================================================
    // 🔹 GENERIC KEY-VALUE API (fallback / legacy)
    // ======================================================

    /// Save a generic key-value pair to memory + file + git
    pub async fn set(&self, key: String, value: String) {
        {
            let mut lock = self.memory.lock().await;
            lock.insert(key.clone(), value.clone());
        }

        // Sync all layers — db not used here since db.rs has no generic kv
        let _ = file::save(&key, &value).await;
        let _ = git::commit(&key, &value).await;
    }

    /// Retrieve a value by key (memory → file)
    pub async fn get(&self, key: &str) -> Option<String> {
        // In-memory check
        if let Some(value) = self.memory.lock().await.get(key).cloned() {
            return Some(value);
        }

        // File fallback
        if let Ok(Some(value)) = file::load(key).await {
            return Some(value);
        }

        None
    }

    /// Remove from memory + file + git
    #[allow(dead_code)]
    pub async fn remove(&self, key: &str) {
        {
            let mut lock = self.memory.lock().await;
            lock.remove(key);
        }

        let _ = file::delete(key).await;
        let _ = git::delete(key).await;
    }

    // ======================================================
    // 🧠 STRUCTURED DATA SYNC HELPERS (DB-INTEGRATED)
    // ======================================================

    /// Record and sync an AI session
    pub async fn record_session(
        &self,
        session: &db::AiSessionStatus,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        db::insert_session(session).await?;
        file::sync_session_to_file(&session.session_id).await?;
        Ok(())
    }

    /// Record an AI model response
    pub async fn record_response(
        &self,
        response: &db::AiResponse,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        db::insert_response(response).await?;
        Ok(())
    }

    /// Record a code change entry
    pub async fn record_code_change(
        &self,
        change: &db::CodeChange,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        db::insert_code_change(change).await?;
        Ok(())
    }

    /// Record frontend activity (UI action, telemetry, etc.)
    pub async fn record_frontend_activity(
        &self,
        activity: &db::FrontendActivity,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        db::insert_frontend_activity(activity).await?;
        Ok(())
    }

    // ======================================================
    // 🔍 FETCH HELPERS
    // ======================================================
    #[allow(dead_code)]
    pub async fn get_session(
        &self,
        session_id: &str,
    ) -> Result<Option<db::AiSessionStatus>, Box<dyn std::error::Error + Send + Sync>> {
        db::get_session(session_id).await
    }

    #[allow(dead_code)]
    pub async fn get_responses(
        &self,
        session_id: &str,
    ) -> Result<Vec<db::AiResponse>, Box<dyn std::error::Error + Send + Sync>> {
        db::get_responses_by_session(session_id).await
    }

    #[allow(dead_code)]
    pub async fn get_code_changes(
        &self,
        session_id: &str,
    ) -> Result<Vec<db::CodeChange>, Box<dyn std::error::Error + Send + Sync>> {
        db::get_code_changes(session_id).await
    }

    #[allow(dead_code)]
    pub async fn get_frontend_activities(
        &self,
        session_id: &str,
    ) -> Result<Vec<db::FrontendActivity>, Box<dyn std::error::Error + Send + Sync>> {
        db::get_frontend_activities(session_id).await
    }
}
