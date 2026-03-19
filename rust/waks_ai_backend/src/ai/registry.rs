use std::{collections::HashMap, fmt, sync::Arc};

use axum::http::StatusCode;
use serde::{Deserialize, Serialize};

use crate::ai::parser::OpenAiParser;

use crate::ai::{
    provider::*,
    stream::{create_anthropic_stream, create_ollama_stream, create_openai_stream, StreamType},
};

use super::parser::{
    AnthropicParser, CohereParser, HuggingFaceParser, OllamaParser, ResponseParser,
};

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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub enum Provider {
    OpenAi,
    Mistral,
    Ollama,
    OllamaChat,
    Anthropic,
    Cohere,
    HuggingFace,
}

impl Provider {
    pub fn as_str(&self) -> &'static str {
        match self {
            Provider::OpenAi => "openai",
            Provider::Mistral => "mistral",
            Provider::Ollama => "ollama",
            Provider::OllamaChat => "ollama-chat",
            Provider::Anthropic => "anthropic",
            Provider::Cohere => "cohere",
            Provider::HuggingFace => "huggingface",
        }
    }
}

impl<'de> Deserialize<'de> for Provider {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let deserialized_str = String::deserialize(deserializer)?.to_lowercase();
        match deserialized_str.as_str() {
            "openai" => Ok(Provider::OpenAi),
            "mistral" => Ok(Provider::Mistral),
            "ollama" => Ok(Provider::Ollama),
            "ollama-chat" => Ok(Provider::OllamaChat),
            "anthropic" => Ok(Provider::Anthropic),
            "cohere" => Ok(Provider::Cohere),
            "huggingface" => Ok(Provider::HuggingFace),
            _ => Err(serde::de::Error::custom(format!(
                "unknown provider: {}",
                deserialized_str
            ))),
        }
    }
}

impl fmt::Display for Provider {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Provider::OpenAi => write!(f, "openai"),
            Provider::Mistral => write!(f, "mistral"),
            Provider::Ollama => write!(f, "ollama"),
            Provider::OllamaChat => write!(f, "ollama-chat"),
            Provider::Anthropic => write!(f, "anthropic"),
            Provider::Cohere => write!(f, "cohere"),
            Provider::HuggingFace => write!(f, "huggingface"),
        }
    }
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
