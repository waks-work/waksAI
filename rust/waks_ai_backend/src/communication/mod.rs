pub mod backend_bridge;
pub mod channel;
pub mod frontend_bridge;
pub mod protocol;

use crate::ai::state::AppState;
use crate::storage::state::StrongHandle;
use crate::types::AppResult;
use std::sync::Arc;
use tokio::spawn;

/// Initialize the communication system
pub async fn init(ai_state: Arc<AppState>, storage: StrongHandle) -> AppResult<()> {
    // Start async message passing loop
    spawn(async move {
        if let Err(e) = frontend_bridge::start(ai_state.clone(), storage.clone()).await {
            eprintln!("Frontend bridge error: {e:?}");
        }
    });

    Ok(())
}
