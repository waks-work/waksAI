use axum::response::sse::Event;
use futures::{Stream, StreamExt};
use std::{convert::Infallible, pin::Pin};

use crate::ai::{
    provider::OllamaStreamResponse,
    session::{Prompt, PromptManager, SessionManager},
};
use crate::storage::state::StrongHandle;

pub type StreamType = Pin<Box<dyn Stream<Item = Result<Event, Infallible>> + Send>>;

trait StreamParser {
    fn parse_line(line: &str) -> Option<String>;
}

struct OpenAiParser;
struct AnthropicParser;
struct OllamaParser;

impl StreamParser for OpenAiParser {
    fn parse_line(line: &str) -> Option<String> {
        if line.starts_with("data: ") {
            let data = &line[6..];
            if data == "[DONE]" {
                return None;
            }
            serde_json::from_str::<serde_json::Value>(data)
                .ok()
                .and_then(|v| {
                    v["choices"][0]["delta"]["content"]
                        .as_str()
                        .map(|res| res.to_string())
                })
        } else {
            None
        }
    }
}

impl StreamParser for AnthropicParser {
    fn parse_line(line: &str) -> Option<String> {
        if line.starts_with("data: ") {
            let data = &line[6..];
            serde_json::from_str::<serde_json::Value>(data)
                .ok()
                .and_then(|v| v["delta"]["text"].as_str().map(|res| res.to_string()))
        } else {
            None
        }
    }
}

impl StreamParser for OllamaParser {
    fn parse_line(line: &str) -> Option<String> {
        if line.starts_with("data: ") {
            let data = &line[6..];
            serde_json::from_str::<OllamaStreamResponse>(data)
                .ok()
                .filter(|res| !res.response.is_empty())
                .map(|res| res.response)
        } else {
            None
        }
    }
}

async fn begin_session(
    provider: &str,
    user_prompt: &str,
) -> (String, SessionManager, &'static PromptManager, StrongHandle) {
    let session_manager = SessionManager::global().await;
    let prompt_manager = PromptManager::global();
    let storage = StrongHandle::new(); // DB handle

    let session_id = format!("{}_{}", provider, uuid::Uuid::new_v4());
    session_manager.register(&session_id).await;

    // record initial user prompt
    let prompt = Prompt::new(user_prompt.to_string(), "user", provider.to_string());
    prompt_manager.add_prompt(&session_id, prompt).await;

    (session_id, session_manager, prompt_manager, storage)
}

async fn end_session(session_manager: &SessionManager, session_id: &str) {
    session_manager.unregister(session_id).await;
}

fn create_stream<P>(
    response: reqwest::Response,
    provider: String,
    user_prompt: String,
) -> StreamType
where
    P: StreamParser + Send + 'static,
{
    Box::pin(async_stream::stream! {
        let (session_id, session_manager, prompt_manager, storage) = begin_session(&provider, &user_prompt).await;
        let mut byte_stream = response.bytes_stream();

        while let Some(item) = byte_stream.next().await {
            match item {
                Ok(chunk) => {
                    let chunk_str = String::from_utf8_lossy(&chunk);
                    for line in chunk_str.lines() {
                        if let Some(content) = P::parse_line(line) {
                            prompt_manager
                                .update_response(&session_id, &content, Some(&storage))
                                .await;

                            let marked = format!("[session:{}]: {}", session_id,content);
                            yield Ok(Event::default().data(marked));
                        }
                    }
                }
                Err(e) => {
                    tracing::error!("Stream error: {}", e);
                    yield Ok(Event::default().data(format!("Error: {}", e)));
                }
            }
        }

        if let Some(final_resp) = prompt_manager.get_response(&session_id).await {
            let response_prompt = Prompt::new(final_resp, "assistant", provider);
            prompt_manager.add_prompt(&session_id, response_prompt).await;
        }

        end_session(&session_manager, &session_id);
    })
}

pub fn create_openai_stream(
    response: reqwest::Response,
    provider: String,
    user_prompt: String,
) -> StreamType {
    create_stream::<OpenAiParser>(response, provider, user_prompt)
}

pub fn create_anthropic_stream(
    response: reqwest::Response,
    provider: String,
    user_prompt: String,
) -> StreamType {
    create_stream::<AnthropicParser>(response, provider, user_prompt)
}

pub fn create_ollama_stream(
    response: reqwest::Response,
    provider: String,
    user_prompt: String,
) -> StreamType {
    create_stream::<OllamaParser>(response, provider, user_prompt)
}
