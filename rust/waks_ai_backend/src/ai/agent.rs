use crate::ai::session::{PromptManager, SessionManager};
use notify::{Config, Event, RecommendedWatcher, RecursiveMode, Watcher};
use std::{
    path::PathBuf,
    sync::{Arc, RwLock},
    time::SystemTime,
};
use tokio::sync::mpsc;
use tokio::task;

#[derive(Clone)]
pub struct AgentManager {
    session_manager: Arc<SessionManager>,
    prompt_manager: Arc<PromptManager>,
    rules_file: PathBuf,
    cached_rules: Arc<RwLock<Vec<String>>>,
    last_modified: Arc<RwLock<Option<SystemTime>>>,
}

impl AgentManager {
    pub fn new(
        session_manager: Arc<SessionManager>,
        prompt_manager: Arc<PromptManager>,
        rules_file: PathBuf,
    ) -> Self {
        let manager = Self {
            session_manager,
            prompt_manager,
            rules_file: rules_file.clone(),
            cached_rules: Arc::new(RwLock::new(Vec::new())),
            last_modified: Arc::new(RwLock::new(None)),
        };

        // reload
        manager.watch_rules_file();

        manager
    }

    // {}
    async fn load_rules(&self) -> Vec<String> {
        let metadata = match tokio::fs::metadata(&self.rules_file).await {
            Ok(meta) => meta,
            Err(_) => return Vec::new(),
        };

        let modified = metadata.modified().ok();
        {
            let last = self.last_modified.read().unwrap();
            if let Some(last_time) = *last {
                if Some(last_time) == modified {
                    // No changes, return cached rules
                    let cached = self.cached_rules.read().unwrap();
                    return cached.clone();
                }
            }
        }

        // File changed or first load
        let content = tokio::fs::read_to_string(&self.rules_file)
            .await
            .unwrap_or_default();

        let mut rules = Vec::new();
        let mut buffer = Vec::new();
        let mut inside_block = false;

        for line in content.lines() {
            let l = line.trim();
            if l.starts_with('{') {
                inside_block = true;
                buffer.clear();
            } else if l.ends_with('}') && inside_block {
                inside_block = false;
                if !buffer.is_empty() {
                    rules.push(buffer.join("\n"));
                }
                buffer.clear();
            } else if inside_block && !l.is_empty() {
                buffer.push(l.to_string());
            }
        }

        // Update cache
        {
            let mut cache_write = self.cached_rules.write().unwrap();
            *cache_write = rules.clone();
        }
        {
            let mut last_write = self.last_modified.write().unwrap();
            *last_write = modified;
        }

        println!("AI Rules reloaded! Total rules: {}", rules.len());
        rules
    }

    /// Watch rules file for changes using notify
    fn watch_rules_file(&self) {
        let path = self.rules_file.clone();
        let cache = self.cached_rules.clone();
        let last_modified = self.last_modified.clone();

        std::thread::spawn(move || {
            let (tx, mut rx) = mpsc::unbounded_channel();

            let mut watcher: RecommendedWatcher = RecommendedWatcher::new(
                move |res: Result<Event, notify::Error>| {
                    if let Ok(event) = res {
                        let _ = tx.send(event).unwrap_or_else(|e| {
                            eprintln!("Failed to send event: {:?}", e);
                        });
                    }
                },
                Config::default(),
            )
            .expect("Failed to create file watcher");

            watcher
                .watch(&path, RecursiveMode::NonRecursive)
                .expect("Failed to watch rules file");

            // Event loop
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async move {
                while let Some(_event) = rx.recv().await {
                    // Reload rules
                    let new_rules = tokio::fs::read_to_string(&path).await.unwrap_or_default();

                    let mut parsed_rules = Vec::new();
                    let mut buffer = Vec::new();
                    let mut inside_block = false;

                    for line in new_rules.lines() {
                        let l = line.trim();
                        if l.starts_with('{') {
                            inside_block = true;
                            buffer.clear();
                        } else if l.ends_with('}') && inside_block {
                            inside_block = false;
                            if !buffer.is_empty() {
                                parsed_rules.push(buffer.join("\n"));
                            }
                            buffer.clear();
                        } else if inside_block && !l.is_empty() {
                            buffer.push(l.to_string());
                        }
                    }

                    // Update cache
                    {
                        let mut cache_write = cache.write().unwrap();
                        *cache_write = parsed_rules.clone();
                    }

                    {
                        let mut last_write = last_modified.write().unwrap();
                        *last_write = Some(std::time::SystemTime::now());
                    }

                    println!(
                        "📄 Rules reloaded via watcher! Total rules: {}",
                        parsed_rules.len()
                    );
                }
            });
        });
    }

    /// Start agent for a session
    pub async fn start_agent(&self, session_id: &str) {
        let prompt_man = self.prompt_manager.clone();
        let session_id = session_id.to_string();
        let this = self.clone();

        task::spawn(async move {
            loop {
                if let Some(prompts) = prompt_man.get_prompts(&session_id).await {
                    if let Some(last) = prompts.last() {
                        println!("🤖 Agent processing session {}...", session_id);

                        // Load rules (cached if unchanged)
                        let rules = this.load_rules().await;
                        for rule in &rules {
                            if last.content.contains(rule) {
                                println!("➡️ Rule triggered in session {}: \n{}", session_id, rule);
                                // Additional actions can be implemented here
                            }
                        }
                    }
                }

                tokio::time::sleep(std::time::Duration::from_secs(3)).await;
            }
        });
    }
}
