/// Called when the Lua side triggers InlineAI:get_suggestions_for_selection()
pub async fn handle_record_activity(
    Json(payload): Json<FrontendActivity>
) -> Result<Json<bool>, String> {
