use once_cell::sync::OnceCell;
use sqlx::{sqlite::SqlitePoolOptions, SqlitePool};

static POOL: OnceCell<SqlitePool> = OnceCell::new();

pub async fn init() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect("sqlite:storage.db")
        .await?;

    sqlx::query("CREATE TABLE IF NOT EXISTS storage (key TEXT PRIMARY KEY, value TEXT);")
        .execute(&pool)
        .await?;

    POOL.set(pool).unwrap();
    Ok(())
}

pub async fn save(key: &str, value: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let pool = POOL.get().unwrap();
    sqlx::query("INSERT OR REPLACE INTO storage (key, value) VALUES (?, ?)")
        .bind(key)
        .bind(value)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn load(key: &str) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
    let pool = POOL.get().unwrap();
    let row: Option<(String,)> = sqlx::query_as("SELECT value FROM storage WHERE key = ?")
        .bind(key)
        .fetch_optional(pool)
        .await?;
    Ok(row.map(|r| r.0))
}

pub async fn delete(key: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let pool = POOL.get().unwrap();
    sqlx::query("DELETE FROM storage WHERE key = ?")
        .bind(key)
        .execute(pool)
        .await?;
    Ok(())
}
