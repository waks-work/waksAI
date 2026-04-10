use crate::ai::{provider::*, session};
use crate::storage;
use axum::{http::StatusCode, response::sse::Event};
use futures::{Stream, StreamExt};
use serde_json::Value;
use std::{collections::HashMap, convert::Infallible, pin::Pin, sync::Arc};

pub type StreamType = Pin<Box<dyn Stream<Item = Result<Event, Infallible>> + Send>>;

pub struct ProviderConfig {
    pub build_request: Arc<
        dyn Fn(
                &GenerateReq,
            )
                -> Result<(String, Vec<(String, String)>, serde_json::Value), (StatusCode, String)>
            + Send
            + Sync,
    >,
    pub parser: Arc<dyn ResponseParser + Send + Sync>,
    pub create_stream:
        Option<Arc<dyn Fn(reqwest::Response, String, String) -> StreamType + Send + Sync>>,
}

pub struct OpenAiParser;
pub struct AnthropicParser;
pub struct OllamaParser;
pub struct CohereParser;
pub struct HuggingFaceParser;

/// Parsing
pub trait ResponseParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)>;
}

impl ResponseParser for OpenAiParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|err| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {}", err)))?;
        json.get("choices")
            .and_then(|con| con[0]["message"]["content"].as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed response".into()))
    }
}

impl ResponseParser for AnthropicParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|err| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {}", err)))?;
        json.get("content")
            .and_then(|con| con[0]["text"].as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed response".into()))
    }
}

impl ResponseParser for OllamaParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
        json.get("response")
            .and_then(|val| val.as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed Ollama response".into()))
    }
}

impl ResponseParser for CohereParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|err| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {err}")))?;
        json.get("generations")
            .and_then(|con| con[0]["text"].as_str())
            .map(|st| st.to_string())
            .ok_or((StatusCode::BAD_GATEWAY, "Malformed Cohere response".into()))
    }
}

impl ResponseParser for HuggingFaceParser {
    fn parse(&self, body: &str) -> Result<String, (StatusCode, String)> {
        let json: Value = serde_json::from_str(body)
            .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Invalid JSON: {e}")))?;
        if let Some(arr) = json.as_array() {
            arr.get(0)
                .and_then(|obj| obj["generated_text"].as_str())
                .map(|st| st.to_string())
                .ok_or((
                    StatusCode::BAD_GATEWAY,
                    "Malformed HuggingFace response".into(),
                ))
        } else {
            Err((
                StatusCode::BAD_GATEWAY,
                "Unexpected HuggingFace response".into(),
            ))
        }
    }
}

/// Stream logic
trait StreamParser {
    fn parse_line(line: &str) -> Option<String>;
}

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
) -> (
    String,
    session::SessionManager,
    &'static session::PromptManager,
    storage::state::StrongHandle,
) {
    let session_manager = session::SessionManager::global().await;
    let prompt_manager = session::PromptManager::global();
    let storage = storage::state::StrongHandle::new(); // DB handle

    let session_id = format!("{}_{}", provider, uuid::Uuid::new_v4());
    session_manager.register(&session_id).await;

    let prompt = session::Prompt::new(user_prompt.to_string(), "user", provider.to_string());
    prompt_manager.add_prompt(&session_id, prompt).await;

    (session_id, session_manager, prompt_manager, storage)
}

async fn end_session(session_manager: &session::SessionManager, session_id: &str) {
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
            let response_prompt = session::Prompt::new(final_resp, "assistant", provider);
            prompt_manager.add_prompt(&session_id, response_prompt).await;
        }

        end_session(&session_manager, &session_id).await;
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

pub fn provider_registry() -> HashMap<Provider, ProviderConfig> {
    let mut map = HashMap::new();

    // OpenAI-compatible providers
    let openai_like_providers = [
        (
            Provider::OpenAi,
            "https://api.openai.com/v1/chat/completions",
        ),
        (
            Provider::Mistral,
            "https://api.mistral.ai/v1/chat/completions",
        ),
    ];

    for (provider, url) in openai_like_providers {
        let name = format!("{:?}", provider).to_lowercase();
        let url_string = url.to_string();
        map.insert(
            provider,
            ProviderConfig {
                build_request: Arc::new(move |req| build_openai_like(&url_string, &name, req)),
                parser: Arc::new(OpenAiParser),
                create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                    create_openai_stream(resp, provider, user_prompt)
                })),
            },
        );
    }

    // NOTE(waks-work): Add grok support
    map.insert(
        Provider::Ollama,
        ProviderConfig {
            build_request: Arc::new(|req| build_ollama(req)),
            parser: Arc::new(OllamaParser),
            create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                create_ollama_stream(resp, provider, user_prompt)
            })),
        },
    );

    map.insert(
        Provider::OllamaChat,
        ProviderConfig {
            build_request: Arc::new(|req| build_ollama_chat(req)),
            parser: Arc::new(OllamaParser),
            create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                create_openai_stream(resp, provider, user_prompt)
            })),
        },
    );

    map.insert(
        Provider::Anthropic,
        ProviderConfig {
            build_request: Arc::new(|req| build_anthropic(req)),
            parser: Arc::new(AnthropicParser),
            create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                create_anthropic_stream(resp, provider, user_prompt)
            })),
        },
    );

    map.insert(
        Provider::Cohere,
        ProviderConfig {
            build_request: Arc::new(|req| build_cohere(req)),
            parser: Arc::new(CohereParser),
            create_stream: None, // Cohere streaming not implemented yet
        },
    );

    map.insert(
        Provider::HuggingFace,
        ProviderConfig {
            build_request: Arc::new(|req| build_huggingface(req)),
            parser: Arc::new(HuggingFaceParser),
            create_stream: None, // HuggingFace streaming not implemented yet
        },
    );

    map
}
