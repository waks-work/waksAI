use once_cell::sync::OnceCell;
use sqlx::{sqlite::SqlitePoolOptions, SqlitePool};
<<<<<<< HEAD
use std::{fs, path::Path};

static POOL: OnceCell<SqlitePool> = OnceCell::new();

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

pub async fn init() -> DbResult<()> {
    let dir = "storage_data";
    let db_path = format!("{}/storage.db", dir);

    tokio::fs::create_dir_all(dir).await?;

    if !Path::new(&db_path).exists() {
        fs::File::create(&db_path)?;
        println!("🆕 Created new SQLite database file at {}", db_path);
    } else {
        println!("🔄 Opened existing SQLite database at {}", db_path);
    }

    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(&format!("sqlite:{}", db_path))
        .await?;

    sqlx::query(
        "CREATE TABLE IF NOT EXISTS storage (
            key TEXT PRIMARY KEY,
            value TEXT
        );",
    )
    .execute(&pool)
    .await?;

    if POOL.set(pool).is_err() {
        return Err("Database pool already initialized".into());
    }

    println!("✅ SQLite initialized and ready at {}", db_path);
    Ok(())
}

fn get_pool() -> &'static SqlitePool {
    POOL.get().expect("DB not initialized. Call init() first.")
}

pub async fn save(key: &str, value: &str) -> DbResult<()> {
    sqlx::query("INSERT OR REPLACE INTO storage (key, value) VALUES (?, ?)")
        .bind(key)
        .bind(value)
        .execute(get_pool())
=======

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
>>>>>>> c7277b6daca621643918d9cab9510edec67d0fce
        .await?;
    Ok(())
}

<<<<<<< HEAD
/// by key
pub async fn load(key: &str) -> DbResult<Option<String>> {
    let row: Option<(String,)> = sqlx::query_as("SELECT value FROM storage WHERE key = ?")
        .bind(key)
        .fetch_optional(get_pool())
=======
pub async fn load(key: &str) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
    let pool = POOL.get().unwrap();
    let row: Option<(String,)> = sqlx::query_as("SELECT value FROM storage WHERE key = ?")
        .bind(key)
        .fetch_optional(pool)
>>>>>>> c7277b6daca621643918d9cab9510edec67d0fce
        .await?;
    Ok(row.map(|r| r.0))
}

<<<<<<< HEAD
/// Delete a key-value pair
pub async fn delete(key: &str) -> DbResult<()> {
    sqlx::query("DELETE FROM storage WHERE key = ?")
        .bind(key)
        .execute(get_pool())
        .await?;
    Ok(())
}

/// Check if a key exists
pub async fn exists(key: &str) -> DbResult<bool> {
    let row: Option<(i64,)> = sqlx::query_as("SELECT 1 FROM storage WHERE key = ?")
        .bind(key)
        .fetch_optional(get_pool())
        .await?;
    Ok(row.is_some())
}

/// List all keys
pub async fn list() -> DbResult<Vec<String>> {
    let rows: Vec<(String,)> = sqlx::query_as("SELECT key FROM storage")
        .fetch_all(get_pool())
        .await?;
    Ok(rows.into_iter().map(|r| r.0).collect())
}

/// List all key-value pairs
pub async fn list_with_values() -> DbResult<Vec<(String, String)>> {
    let rows: Vec<(String, String)> = sqlx::query_as("SELECT key, value FROM storage")
        .fetch_all(get_pool())
        .await?;
    Ok(rows)
}

/// Count total key-value pairs
pub async fn count() -> DbResult<i64> {
    let row: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM storage")
        .fetch_one(get_pool())
        .await?;
    Ok(row.0)
}

/// Clear all data
pub async fn clear() -> DbResult<()> {
    sqlx::query("DELETE FROM storage")
        .execute(get_pool())
=======
pub async fn delete(key: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let pool = POOL.get().unwrap();
    sqlx::query("DELETE FROM storage WHERE key = ?")
        .bind(key)
        .execute(pool)
>>>>>>> c7277b6daca621643918d9cab9510edec67d0fce
        .await?;
    Ok(())
}
