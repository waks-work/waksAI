use crate::storage::db;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tokio::fs;

const STORAGE_DIR: &str = "storage_data";

// ===================================================
// 🧱 Generic Key-Value Backup (legacy support)
// ===================================================
pub async fn save(key: &str, value: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let path = PathBuf::from(STORAGE_DIR).join(format!("{}.json", key));
    fs::create_dir_all(STORAGE_DIR).await?;
    fs::write(&path, value).await?;
    Ok(())
}

pub async fn load(key: &str) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
    let path = PathBuf::from(STORAGE_DIR).join(format!("{}.json", key));
    if path.exists() {
        let content = fs::read_to_string(path).await?;
        Ok(Some(content))
    } else {
        Ok(None)
    }
}

#[allow(dead_code)]
pub async fn delete(key: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let path = PathBuf::from(STORAGE_DIR).join(format!("{}.json", key));
    if path.exists() {
        fs::remove_file(path).await?;
    }
    Ok(())
}

// ===================================================
// 🧠 Structured Sync Layer
// ===================================================
#[derive(Serialize, Deserialize)]
pub struct FileSyncLog {
    pub record_type: String,
    pub record_id: String,
    pub synced_at: String,
}

// ---------------------------------------------------
// 🔹 Helper for writing both record and sync log
// ---------------------------------------------------
async fn write_with_log(
    record_type: &str,
    record_id: &str,
    json: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    fs::create_dir_all(STORAGE_DIR).await?;

    // Write the record JSON
    let file_name = format!("{}_{}.json", record_type, record_id);
    let path = PathBuf::from(STORAGE_DIR).join(file_name);
    fs::write(&path, json).await?;

    // Write a sync log entry
    let log = FileSyncLog {
        record_type: record_type.to_string(),
        record_id: record_id.to_string(),
        synced_at: Utc::now().to_rfc3339(),
    };

    let log_path = PathBuf::from(STORAGE_DIR).join("sync_log.json");
    let _ = fs::write(&log_path, serde_json::to_string_pretty(&log)?).await;

    println!("📁 {} {} mirrored to file system", record_type, record_id);
    Ok(())
}

// ---------------------------------------------------
// 🧩 SYNC FUNCTIONS FOR EACH TABLE
// ---------------------------------------------------

/// Mirror AI session status from DB → file system
pub async fn sync_session_to_file(
    session_id: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if let Ok(Some(session)) = db::get_session(session_id).await {
        let json = serde_json::to_string_pretty(&session)?;
        write_with_log("session", session_id, &json).await?;
    }
    Ok(())
}

/// TODO: Fix it to match the database counterpart:  change in sync_code_changes..., response in
/// responses and activity in  activity,
/// Mirror all AI responses for a session
#[allow(dead_code)]
pub async fn sync_responses_to_file(
    session_id: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if let Ok(responses) = db::get_responses_by_session(session_id).await {
        let json = serde_json::to_string_pretty(&responses)?;
        write_with_log("responses", session_id, &json).await?;
    }
    Ok(())
}

/// Mirror all code changes for a session
#[allow(dead_code)]
pub async fn sync_code_changes_to_file(
    session_id: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if let Ok(changes) = db::get_code_changes(session_id).await {
        let json = serde_json::to_string_pretty(&changes)?;
        write_with_log("code_changes", session_id, &json).await?;
    }
    Ok(())
}

/// Mirror frontend activity logs for a session
#[allow(dead_code)]
pub async fn sync_frontend_activity_to_file(
    session_id: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if let Ok(activities) = db::get_frontend_activities(session_id).await {
        let json = serde_json::to_string_pretty(&activities)?;
        write_with_log("frontend_activity", session_id, &json).await?;
    }
    Ok(())
}
