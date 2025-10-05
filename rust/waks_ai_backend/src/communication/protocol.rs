use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub enum Request {
    Generate { prompt: String },
    Save { key: String, value: String },
    Fetch { key: String },
}

#[derive(Debug, Serialize, Deserialize)]
pub enum Response {
    Success { data: String },
    Error { message: String },
}
