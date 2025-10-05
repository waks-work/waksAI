// use async_trait::async_trait;
// use std::sync::Arc;

pub type AppResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

// Placeholder AI and Storage handles
// pub type AiHandle = Arc<dyn AiBackend + Send + Sync>;
// pub type StorageHandle = Arc<dyn StorageBackend + Send + Sync>;

// #[async_trait::async_trait]
// pub trait AiBackend {
//     async fn run(&self, prompt: String) -> AppResult<String>;
// }

// #[async_trait::async_trait]
// pub trait StorageBackend {
//    async fn save(&self, key: &str, value: &str) -> AppResult<()>;
//    async fn fetch(&self, key: &str) -> AppResult<String>;
// }
