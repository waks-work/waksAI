use chrono::{DateTime, Utc};
use once_cell::sync::OnceCell;
use serde::{Deserialize, Serialize};
use sqlx::{sqlite::SqlitePoolOptions, FromRow, SqlitePool};
use std::{fs, path::Path};

/// Global database pool initialized once at start up.
static POOL: OnceCell<SqlitePool> = OnceCell::new();

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

// db models
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AiSessionStatus {
    pub session_id: String,
    pub ai_model: String,
    pub provider: String,
    pub user_prompt: Option<String>,
    pub system_prompt: Option<String>,
    pub metadata: Option<String>,
    pub status: Option<String>,
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AiResponse {
    pub id: i64,
    pub session_id: String,
    pub ai_response: String,
    pub tokens_used: Option<i64>,
    pub response_time_ms: Option<i64>,
    pub created_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct CodeChange {
    pub code_change_id: i64,
    pub session_id: String,
    pub file_name: Option<String>,
    pub previous_code: Option<String>,
    pub changed_code: Option<String>,
    pub description: Option<String>,
    pub backup_path: Option<String>,
    pub created_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct FrontendActivity {
    pub activity_id: i64,
    pub session_id: Option<String>,
    pub action: String,
    pub payload: Option<String>,
    pub timestamp: Option<DateTime<Utc>>,
}

pub async fn init() -> DbResult<()> {
    let dir = "storage_data";
    let db_path = format!("{}/storage.db", dir);

    tokio::fs::create_dir_all(dir).await?;
    if !Path::new(&db_path).exists() {
        fs::File::create(&db_path)?;
        println!("DB Created new SQLite database file at {}", db_path);
    }

    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(&format!("sqlite:{}", db_path))
        .await?;

    // tabe creation
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS ai_session_status (
            session_id TEXT PRIMARY KEY,
            ai_model TEXT NOT NULL,
            provider TEXT NOT NULL,
            user_prompt TEXT,
            system_prompt TEXT,
            metadata TEXT,
            status TEXT DEFAULT 'completed',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    "#,
    )
    .execute(&pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS ai_response (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            ai_response TEXT NOT NULL,
            tokens_used INTEGER,
            response_time_ms INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(session_id) REFERENCES ai_session_status(session_id)
        );
    "#,
    )
    .execute(&pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS code_changes (
            code_change_id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            file_name TEXT,
            previous_code TEXT,
            changed_code TEXT,
            description TEXT,
            backup_path TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(session_id) REFERENCES ai_session_status(session_id)
        );
    "#,
    )
    .execute(&pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS frontend_activity (
            activity_id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT,
            action TEXT NOT NULL,
            payload TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(session_id) REFERENCES ai_session_status(session_id)
        );
    "#,
    )
    .execute(&pool)
    .await?;

    if POOL.set(pool).is_err() {
        return Err("Database pool already initialized".into());
    }

    println!("Database ready at {}", db_path);
    Ok(())
}

fn get_pool() -> &'static SqlitePool {
    POOL.get()
        .expect("DB failde to initialize — call init() first")
}

// crud
pub async fn insert_session(session: &AiSessionStatus) -> DbResult<()> {
    sqlx::query(
        "INSERT OR REPLACE INTO ai_session_status 
         (session_id, ai_model, provider, user_prompt, system_prompt, metadata, status)
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&session.session_id)
    .bind(&session.ai_model)
    .bind(&session.provider)
    .bind(&session.user_prompt)
    .bind(&session.system_prompt)
    .bind(&session.metadata)
    .bind(&session.status)
    .execute(get_pool())
    .await?;
    Ok(())
}

pub async fn get_session(session_id: &str) -> DbResult<Option<AiSessionStatus>> {
    let row = sqlx::query_as::<_, AiSessionStatus>(
        "SELECT * FROM ai_session_status WHERE session_id = ?",
    )
    .bind(session_id)
    .fetch_optional(get_pool())
    .await?;
    Ok(row)
}

pub async fn insert_response(resp: &AiResponse) -> DbResult<()> {
    sqlx::query(
        "INSERT INTO ai_response (session_id, ai_response, tokens_used, response_time_ms)
         VALUES (?, ?, ?, ?)",
    )
    .bind(&resp.session_id)
    .bind(&resp.ai_response)
    .bind(&resp.tokens_used)
    .bind(&resp.response_time_ms)
    .execute(get_pool())
    .await?;
    Ok(())
}
#[allow(dead_code)]
pub async fn get_responses_by_session(session_id: &str) -> DbResult<Vec<AiResponse>> {
    let rows = sqlx::query_as::<_, AiResponse>("SELECT * FROM ai_response WHERE session_id = ?")
        .bind(session_id)
        .fetch_all(get_pool())
        .await?;
    Ok(rows)
}

pub async fn insert_code_change(change: &CodeChange) -> DbResult<()> {
    sqlx::query(
        "INSERT INTO code_changes 
         (session_id, file_name, previous_code, changed_code, description, backup_path)
         VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(&change.session_id)
    .bind(&change.file_name)
    .bind(&change.previous_code)
    .bind(&change.changed_code)
    .bind(&change.description)
    .bind(&change.backup_path)
    .execute(get_pool())
    .await?;
    Ok(())
}

pub async fn get_code_changes(session_id: &str) -> DbResult<Vec<CodeChange>> {
    let rows = sqlx::query_as::<_, CodeChange>("SELECT * FROM code_changes WHERE session_id = ?")
        .bind(session_id)
        .fetch_all(get_pool())
        .await?;
    Ok(rows)
}

pub async fn insert_frontend_activity(activity: &FrontendActivity) -> DbResult<()> {
    sqlx::query(
        "INSERT INTO frontend_activity (session_id, action, payload)
         VALUES (?, ?, ?)",
    )
    .bind(&activity.session_id)
    .bind(&activity.action)
    .bind(&activity.payload)
    .execute(get_pool())
    .await?;
    Ok(())
}

#[allow(dead_code)]
pub async fn get_frontend_activities(session_id: &str) -> DbResult<Vec<FrontendActivity>> {
    let rows = sqlx::query_as::<_, FrontendActivity>(
        "SELECT * FROM frontend_activity WHERE session_id = ?",
    )
    .bind(session_id)
    .fetch_all(get_pool())
    .await?;
    Ok(rows)
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_database_flow() {
        let pool = SqlitePoolOptions::new()
            .connect("sqlite::memory:")
            .await
            .unwrap();

        sqlx::query("CREATE TABLE ai_session_status (session_id TEXT PRIMARY KEY, ai_model TEXT, provider TEXT, status TEXT)")
            .execute(&pool).await.unwrap();

        sqlx::query("CREATE TABLE frontend_activity (activity_id INTEGER PRIMARY KEY, session_id TEXT, action TEXT, payload TEXT)")
            .execute(&pool).await.unwrap();

        let res = sqlx::query("INSERT INTO ai_session_status (session_id, ai_model, provider, status) VALUES (?, ?, ?, ?)")
            .bind("test_session_1")
            .bind("llama3")
            .bind("ollama")
            .bind("active")
            .execute(&pool).await;

        assert!(res.is_ok());

        let res = sqlx::query(
            "INSERT INTO frontend_activity (session_id, action, payload) VALUES (?, ?, ?)",
        )
        .bind("test_session_1")
        .bind("Multimeter Trace")
        .bind("3.3V stable on VCC rail")
        .execute(&pool)
        .await;

        assert!(res.is_ok());
    }
}
