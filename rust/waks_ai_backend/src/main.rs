mod ai;
mod communication;
mod handlers;
mod storage;
mod types;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    ai::run::run_server().await;
}
