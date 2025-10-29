use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Prompt {
    pub id: String,
    pub content: String,
    pub marker: String,
    pub source: String,
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
