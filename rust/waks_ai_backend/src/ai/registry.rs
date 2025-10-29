use std::collections::HashMap;
use std::sync::Arc;

use axum::http::StatusCode;

use crate::ai::parser::{
    parse_anthropic, parse_cohere, parse_huggingface, parse_ollama, parse_openai_like,
};
use crate::ai::provider::*;
use crate::ai::stream::{
    create_anthropic_stream, create_ollama_stream, create_openai_stream, StreamType,
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
    pub parse_response: Arc<dyn Fn(&str) -> Result<String, (StatusCode, String)> + Send + Sync>,
    pub create_stream:
        Option<Arc<dyn Fn(reqwest::Response, String, String) -> StreamType + Send + Sync>>,
}

pub fn provider_registry() -> HashMap<&'static str, ProviderConfig> {
    let mut map = HashMap::new();

    // OpenAI-compatible providers
    let openai_like_providers = [
        ("openai", "https://api.openai.com/v1/chat/completions"),
        ("mistral", "https://api.mistral.ai/v1/chat/completions"),
    ];

    for (name, url) in openai_like_providers {
        let name_static: &'static str = Box::leak(name.to_string().into_boxed_str());
        let url_string = url.to_string();
        map.insert(
            name_static,
            ProviderConfig {
                build_request: Arc::new(move |req| build_openai_like(&url_string, name, req)),
                parse_response: Arc::new(parse_openai_like),
                create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                    create_openai_stream(resp, provider, user_prompt)
                })),
            },
        );
    }

    // Ollama variants
    map.insert(
        "ollama",
        ProviderConfig {
            build_request: Arc::new(|req| build_ollama(req)),
            parse_response: Arc::new(parse_ollama),
            create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                create_ollama_stream(resp, provider, user_prompt)
            })),
        },
    );

    map.insert(
        "ollama-chat",
        ProviderConfig {
            build_request: Arc::new(|req| build_ollama_chat(req)),
            parse_response: Arc::new(parse_openai_like),
            create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                create_openai_stream(resp, provider, user_prompt)
            })),
        },
    );

    // Other providers
    map.insert(
        "anthropic",
        ProviderConfig {
            build_request: Arc::new(|req| build_anthropic(req)),
            parse_response: Arc::new(parse_anthropic),
            create_stream: Some(Arc::new(|resp, provider, user_prompt| {
                create_anthropic_stream(resp, provider, user_prompt)
            })),
        },
    );

    map.insert(
        "cohere",
        ProviderConfig {
            build_request: Arc::new(|req| build_cohere(req)),
            parse_response: Arc::new(parse_cohere),
            create_stream: None, // Cohere streaming not implemented yet
        },
    );

    map.insert(
        "huggingface",
        ProviderConfig {
            build_request: Arc::new(|req| build_huggingface(req)),
            parse_response: Arc::new(parse_huggingface),
            create_stream: None, // HuggingFace streaming not implemented yet
        },
    );

    map
}
