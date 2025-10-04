use axum::response::sse::Event;
use futures::Stream;
use futures::StreamExt;
use std::{convert::Infallible, pin::Pin};

use crate::ai::provider::OllamaStreamResponse;

pub type StreamType = Pin<Box<dyn Stream<Item = Result<Event, Infallible>> + Send>>;

pub fn create_openai_stream(response: reqwest::Response, _provider: String) -> StreamType {
    Box::pin(async_stream::stream! {
        let mut byte_stream = response.bytes_stream();

        while let Some(item) = byte_stream.next().await {
            match item {
                Ok(chunk) => {
                    let chunk_str = String::from_utf8_lossy(&chunk);
                    for line in chunk_str.lines() {
                        if line.starts_with("data: ") {
                            let data = &line[6..];
                            if data == "[DONE]" {
                                // end the stream
                                return;
                            }
                            if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(data) {
                                if let Some(content) = parsed["choices"][0]["delta"]["content"].as_str() {
                                    if !content.is_empty() {
                                        yield Ok(Event::default().data(content.to_string()));
                                    }
                                }
                            }
                        }
                    }
                }
                Err(e) => {
                    tracing::error!("Error reading stream chunk: {}", e);
                    yield Ok(Event::default().data(format!("Error: {}", e)));
                }
            }
        }
    })
}

pub fn create_ollama_stream(response: reqwest::Response, _provider: String) -> StreamType {
    Box::pin(async_stream::stream! {
        let mut byte_stream = response.bytes_stream();

        while let Some(item) = byte_stream.next().await {
            match item {
                Ok(chunk) => {
                    let chunk_str = String::from_utf8_lossy(&chunk);
                    for line in chunk_str.lines() {
                        if let Ok(stream_response) = serde_json::from_str::<OllamaStreamResponse>(line) {
                            if !stream_response.response.is_empty() {
                                yield Ok(Event::default().data(stream_response.response));
                            }
                        }
                    }
                }
                Err(e) => {
                    tracing::error!("Error reading stream chunk: {}", e);
                    yield Ok(Event::default().data(format!("Error: {}", e)));
                }
            }
        }
    })
}

pub fn create_anthropic_stream(response: reqwest::Response, _provider: String) -> StreamType {
    Box::pin(async_stream::stream! {
        let mut byte_stream = response.bytes_stream();

        while let Some(item) = byte_stream.next().await {
            match item {
                Ok(chunk) => {
                    let chunk_str = String::from_utf8_lossy(&chunk);
                    for line in chunk_str.lines() {
                        if line.starts_with("data: ") {
                            let data = &line[6..];
                            if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(data) {
                                if let Some(content) = parsed["delta"]["text"].as_str() {
                                    yield Ok(Event::default().data(content.to_string()));
                                }
                            }
                        }
                    }
                }
                Err(e) => {
                    tracing::error!("Error reading stream chunk: {}", e);
                    yield Ok(Event::default().data(format!("Error: {}", e)));
                }
            }
        }
    })
}
