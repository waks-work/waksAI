mod ai;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    ai::run::run_server().await;
}
