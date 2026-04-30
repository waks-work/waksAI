use super::registry::ProviderConfig;
use crate::ai::{
    agent::AgentManager,
    provider::{GenerateReq, GenerateResp, Message, Provider},
    session::{Prompt, PromptManager, SessionManager},
};
use axum::{
    extract::State,
    http::StatusCode,
    response::{
        sse::{Event, Sse},
        IntoResponse, Json, Response,
    },
};
use futures::{Stream, StreamExt};
use std::{collections::HashMap, convert::Infallible, path::PathBuf, sync::Arc};
use tokio::sync::Mutex;
use tracing::info;

#[derive(Clone)]
pub struct AppState {
    pub sessions: Arc<Mutex<HashMap<String, Vec<Message>>>>,
    pub client: reqwest::Client,
    pub registry: Arc<HashMap<Provider, ProviderConfig>>,
}

impl AppState {
    pub async fn run(
        &self,
        prompt: String,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let session_manager = SessionManager::global().await;
        let prompt_manager = PromptManager::global().clone();
        generate_text(self.clone(), session_manager, prompt_manager, prompt).await
    }
}

/// [HTTP Request] → [Session Init] → [Agent Activation] → [Execute] → [Persist] → [Response]
///
/// [Raw Request] → [Station 1] → [Station 2] → [Station 3] → [Final Product]
///
pub trait SessionInitializer {}

#[async_trait::async_trait]
pub trait SessionInitializerAsync: SessionInitializer + Send + Sync {
    async fn initialize(
        &self,
        req: &GenerateReq,
        sessions: &Arc<tokio::sync::Mutex<std::collections::HashMap<String, Vec<Message>>>>,
        session_manager: &SessionManager,
        prompt_manager: &PromptManager,
    );
}

pub struct DefaultSessionInitializer {
    rules: Vec<String>,
}

impl SessionInitializer for DefaultSessionInitializer {}

impl Default for DefaultSessionInitializer {
    fn default() -> Self {
        Self {
            rules: vec![
                "Always reason step-by-step".to_string(),
                "Be concise and clear".to_string(),
                "Follow safety constraints".to_string(),
            ],
        }
    }
}

impl DefaultSessionInitializer {
    pub fn with_rules(rules: Vec<String>) -> Self {
        Self { rules }
    }

    pub fn from_file(path: &PathBuf) -> std::io::Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let rules = content.lines().map(|st| st.to_string()).collect();
        Ok(Self { rules })
    }
}

#[async_trait::async_trait]
impl SessionInitializerAsync for DefaultSessionInitializer {
    async fn initialize(
        &self,
        req: &GenerateReq,
        sessions: &Arc<tokio::sync::Mutex<std::collections::HashMap<String, Vec<Message>>>>,
        session_manager: &SessionManager,
        prompt_manager: &PromptManager,
    ) {
        if let Some(session_id) = &req.session_id {
            session_manager.register(session_id).await;

            let mut sessions_lock = sessions.lock().await;
            sessions_lock
                .entry(session_id.clone())
                .or_default()
                .extend(req.messages.clone());

            for msg in &req.messages {
                prompt_manager
                    .add_prompt(
                        session_id,
                        Prompt::new(
                            msg.content.clone(),
                            msg.role.clone(),
                            req.provider.to_string(),
                        ),
                    )
                    .await;
            }

            for rule in &self.rules {
                sessions_lock
                    .entry(session_id.clone())
                    .or_default()
                    .push(Message {
                        role: "system".to_string(),
                        content: rule.to_string(),
                    });
            }

            info!(
                "Session {} initialized with {} messages and {} rules",
                session_id,
                req.messages.len(),
                self.rules.len()
            );
        }
    }
}

pub struct MinimalSessionInitializer;

impl SessionInitializer for MinimalSessionInitializer {}

#[async_trait::async_trait]
impl SessionInitializerAsync for MinimalSessionInitializer {
    async fn initialize(
        &self,
        req: &GenerateReq,
        sessions: &Arc<tokio::sync::Mutex<std::collections::HashMap<String, Vec<Message>>>>,
        session_manager: &SessionManager,
        prompt_manager: &PromptManager,
    ) {
        if let Some(session_id) = &req.session_id {
            session_manager.register(session_id).await;

            let mut sessions_lock = sessions.lock().await;
            sessions_lock
                .entry(session_id.clone())
                .or_default()
                .extend(req.messages.clone());

            for msg in &req.messages {
                prompt_manager
                    .add_prompt(
                        session_id,
                        Prompt::new(
                            msg.content.clone(),
                            msg.role.clone(),
                            req.provider.to_string(),
                        ),
                    )
                    .await;
            }
        }
    }
}

pub struct AgentActivator {
    rules_file: PathBuf,
}

impl AgentActivator {
    pub fn new(rules_file: PathBuf) -> Self {
        Self { rules_file }
    }

    pub fn from_home_dir() -> Self {
        let home_dir = std::env::var("HOME").unwrap_or_else(|_| ".".into());
        let rules_file = PathBuf::from(format!("{}/.config/nvim/ai/user_rules.txt", home_dir));
        Self { rules_file }
    }

    pub async fn activate_if_enabled(
        &self,
        req: &GenerateReq,
        session_id: &str,
        session_manager: &SessionManager,
        prompt_manager: &PromptManager,
    ) {
        if req.agent_mode.unwrap_or(false) {
            let agent_manager = AgentManager::new(
                Arc::new(session_manager.clone()),
                Arc::new(prompt_manager.clone()),
                self.rules_file.clone(),
            );
            agent_manager.start_agent(session_id).await;
            info!("Agent mode activated for session: {}", session_id);
        }
    }
}

pub struct ResponsePersister;

impl ResponsePersister {
    pub async fn persist(session_id: &str, response: &str, prompt_manager: &PromptManager) {
        prompt_manager
            .update_response(session_id, response, None)
            .await;
    }
}

pub struct RequestExecutor {
    client: reqwest::Client,
    registry: Arc<HashMap<Provider, ProviderConfig>>,
}

impl RequestExecutor {
    pub fn new(client: reqwest::Client, registry: Arc<HashMap<Provider, ProviderConfig>>) -> Self {
        Self { client, registry }
    }

    pub async fn execute(&self, req: &GenerateReq) -> Result<String, (StatusCode, String)> {
        let provider_config = self
            .registry
            .get(&req.provider)
            .ok_or((StatusCode::BAD_REQUEST, "Unsupported provider".into()))?;

        let (url, headers, body) = (provider_config.build_request)(req)?;

        let mut builder = self.client.post(&url);
        for (k, v) in headers {
            builder = builder.header(&k, &v);
        }

        let resp = builder
            .json(&body)
            .send()
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        if !resp.status().is_success() {
            return Err((resp.status(), resp.text().await.unwrap_or_default()));
        }

        let text = resp
            .text()
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        let parsed = (provider_config.parser.parse(&text))?;
        Ok(parsed)
    }

    pub async fn execute_stream(
        &self,
        req: &GenerateReq,
    ) -> Result<reqwest::Response, (StatusCode, String)> {
        let provider_config = self
            .registry
            .get(&req.provider)
            .ok_or((StatusCode::BAD_REQUEST, "Unsupported provider".into()))?;

        provider_config
            .create_stream
            .as_ref()
            .ok_or((StatusCode::BAD_REQUEST, "Streaming not supported".into()))?;

        let (url, headers, body) = (provider_config.build_request)(req)?;

        let mut builder = self.client.post(&url);
        for (k, v) in headers {
            builder = builder.header(&k, &v);
        }

        let resp = builder
            .json(&body)
            .send()
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        if !resp.status().is_success() {
            return Err((resp.status(), resp.text().await.unwrap_or_default()));
        }

        Ok(resp)
    }
}

pub struct GenerationPipeline {
    session_initializer: Box<dyn SessionInitializerAsync + Send + Sync + 'static>,
    agent_activator: AgentActivator,
    executor: RequestExecutor,
}

impl GenerationPipeline {
    pub fn new(state: &AppState) -> Self {
        Self {
            session_initializer: Box::new(DefaultSessionInitializer::default()),
            agent_activator: AgentActivator::from_home_dir(),
            executor: RequestExecutor::new(state.client.clone(), state.registry.clone()),
        }
    }

    pub fn with_session_initializer(
        mut self,
        initializer: Box<dyn SessionInitializerAsync + Send + Sync>,
    ) -> Self {
        self.session_initializer = initializer;
        self
    }

    pub fn with_agent_rules(mut self, rules_file: PathBuf) -> Self {
        self.agent_activator = AgentActivator::new(rules_file);
        self
    }

    pub async fn execute_non_streaming(
        &self,
        req: GenerateReq,
        sessions: Arc<tokio::sync::Mutex<HashMap<String, Vec<Message>>>>,
    ) -> Result<Response, (StatusCode, String)> {
        let session_manager = SessionManager::global().await;
        let prompt_manager = PromptManager::global();

        self.session_initializer
            .initialize(&req, &sessions, &session_manager, &prompt_manager)
            .await;

        let session_id = req
            .session_id
            .clone()
            .unwrap_or_else(|| "internal".to_string());

        self.agent_activator
            .activate_if_enabled(&req, &session_id, &session_manager, &prompt_manager)
            .await;

        let parsed = self.executor.execute(&req).await?;

        if req.session_id.is_some() {
            ResponsePersister::persist(&session_id, &parsed, &prompt_manager).await;
        }

        Ok(Json(GenerateResp { response: parsed }).into_response())
    }

    pub async fn execute_streaming(
        &self,
        req: GenerateReq,
        sessions: Arc<tokio::sync::Mutex<HashMap<String, Vec<Message>>>>,
        state: &AppState,
    ) -> Result<Sse<impl Stream<Item = Result<Event, Infallible>>>, (StatusCode, String)> {
        let session_manager = SessionManager::global().await;
        let prompt_manager = PromptManager::global();

        self.session_initializer
            .initialize(&req, &sessions, &session_manager, &prompt_manager)
            .await;

        let session_id = req
            .session_id
            .clone()
            .unwrap_or_else(|| "internal".to_string());

        self.agent_activator
            .activate_if_enabled(&req, &session_id, &session_manager, &prompt_manager)
            .await;

        let resp = self.executor.execute_stream(&req).await?;

        let provider_config = state
            .registry
            .get(&req.provider)
            .ok_or((StatusCode::BAD_REQUEST, "Unsupported provider".into()))?;

        let create_stream_fn = provider_config
            .create_stream
            .as_ref()
            .ok_or((StatusCode::BAD_REQUEST, "Streaming not supported".into()))?;

        let user_prompt = req
            .messages
            .iter()
            .rev()
            .find(|m| m.role == "user")
            .map(|m| m.content.clone())
            .unwrap_or_default();

        let base_stream = (create_stream_fn)(resp, req.provider.to_string(), user_prompt);

        let wrapped_stream = async_stream::stream! {
            let mut stream = Box::pin(base_stream);

            while let Some(event_res) = stream.next().await {
                if let Ok(event) = &event_res {
                    let data_str = format!("{:?}", event);
                    if !data_str.trim().is_empty() {
                        let pm = prompt_manager.clone();
                        let sid = session_id.clone();

                        tokio::spawn(async move {
                            let _ = pm.update_response(&sid, &data_str, None).await;
                        });
                    }
                }
                yield event_res;
            }
        };

        Ok(Sse::new(wrapped_stream))
    }
}

pub async fn generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Result<Response, (StatusCode, String)> {
    let pipeline = GenerationPipeline::new(&state);
    pipeline
        .execute_non_streaming(req, state.sessions.clone())
        .await
}

pub async fn stream_generate(
    State(state): State<AppState>,
    Json(req): Json<GenerateReq>,
) -> Result<Sse<impl Stream<Item = Result<Event, Infallible>>>, (StatusCode, String)> {
    let pipeline = GenerationPipeline::new(&state);
    pipeline
        .execute_streaming(req, state.sessions.clone(), &state)
        .await
}

pub async fn generate_text(
    state: AppState,
    session_manager: SessionManager,
    prompt_manager: PromptManager,
    prompt: String,
) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    let session_id = "internal".to_string();
    session_manager.register(&session_id).await;

    prompt_manager
        .add_prompt(
            &session_id,
            Prompt::new(prompt.clone(), "user", "generator".to_string()),
        )
        .await;

    let req = GenerateReq {
        provider: Provider::Ollama,
        model: "llama2".to_string(),
        messages: vec![Message {
            role: "user".to_string(),
            content: prompt.clone(),
        }],
        stream: false,
        api_key: None,
        session_id: Some(session_id.clone()),
        agent_mode: Some(true),
    };

    let executor = RequestExecutor::new(state.client.clone(), state.registry.clone());
    let parsed = executor
        .execute(&req)
        .await
        .map_err(|e| format!("{:?}", e))?;

    prompt_manager
        .add_prompt(
            &session_id,
            Prompt::new(parsed.clone(), "assistant", "generator".to_string()),
        )
        .await;

    session_manager.unregister(&session_id).await;
    Ok(parsed)
}
