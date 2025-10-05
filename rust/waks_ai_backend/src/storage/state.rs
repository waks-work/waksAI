use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

use crate::storage::{db, file, git};

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

    pub async fn set(&self, key: String, value: String) {
        {
            let mut lock = self.memory.lock().await;
            lock.insert(key.clone(), value.clone());
        }

        file::save(&key, &value).await.unwrap_or_else(|e| {
            eprintln!("File save error: {}", e);
        });

        db::save(&key, &value).await.unwrap_or_else(|e| {
            eprintln!("DB save error: {}", e);
        });

        git::commit(&key, &value).await.unwrap_or_else(|e| {
            eprintln!("Git commit error: {}", e);
        });
    }

    pub async fn get(&self, key: &str) -> Option<String> {
        let mem = self.memory.lock().await;
        if let Some(value) = mem.get(key) {
            return Some(value.clone());
        }
        drop(mem);

        if let Ok(Some(value)) = file::load(key).await {
            return Some(value);
        }

        if let Ok(Some(value)) = db::load(key).await {
            return Some(value);
        }

        None
    }

    // Remove a key
    pub async fn remove(&self, key: &str) {
        {
            let mut lock = self.memory.lock().await;
            lock.remove(key);
        }

        let _ = file::delete(key).await;
        let _ = db::delete(key).await;
        let _ = git::delete(key).await;
    }
}
