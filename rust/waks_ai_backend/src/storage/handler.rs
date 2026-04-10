use crate::storage::db;
use axum::Json;
use tracing::info;

/// Endpoint: POST /activity
///
/// Receives telemetry from Neovim. Used for tracking both software UI
/// events and manual hardware diagnostic entries.
pub async fn handle_record_activity(
    Json(payload): Json<db::FrontendActivity>,
) -> Result<Json<bool>, (axum::http::StatusCode, String)> {
    db::insert_frontend_activity(&payload)
        .await
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    info!(action = %payload.action, "Frontend activity logged successfully");
    Ok(Json(true))
}

/// Endpoint: POST /code_change
///
/// Records the "Before" and "After" state of code blocks modified by the AI.
pub async fn handle_code_change(
    Json(payload): Json<db::CodeChange>,
) -> Result<Json<bool>, (axum::http::StatusCode, String)> {
    db::insert_code_change(&payload)
        .await
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    info!(file = ?payload.file_name, "Code change persisted");
    Ok(Json(true))
}

/// Starts a new session or updates an existing one
pub async fn handle_session_status(
    Json(payload): Json<db::AiSessionStatus>,
) -> Result<Json<bool>, String> {
    db::insert_session(&payload)
        .await
        .map_err(|e| e.to_string())?;

    Ok(Json(true))
}
