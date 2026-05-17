//! A complete HTTP example that runs both server and client together

use a2a_rs::adapter::{
    DefaultRequestProcessor, HttpServer, InMemoryTaskStorage, NoopPushNotificationSender,
    SimpleAgentInfo,
};

mod common;
use a2a_rs::observability;
use anyhow::Result;
use common::SimpleAgentHandler;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing for better observability
    observability::init_tracing();

    println!("🚀 Starting A2A Rust Server");
    println!("==============================");

    // Run the server indefinitely
    run_server().await?;

    println!("🏁 A2A Rust Server completed");
    Ok(())
}

async fn run_server() -> Result<()> {
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);

    println!("🌐 Starting HTTP server on {}...", addr);

    // Create server components
    let push_sender = NoopPushNotificationSender;
    let storage = InMemoryTaskStorage::with_push_sender(push_sender);
    let handler = SimpleAgentHandler::with_storage(storage);

    let processor = DefaultRequestProcessor::with_handler(handler);

    // Create agent info
    let agent_info = SimpleAgentInfo::new("A2A Rust Agent".to_string(), format!("http://{}", addr))
        .with_description("An A2A agent using the a2a-rs crate".to_string())
        .with_provider(
            "Example Organization".to_string(),
            "https://example.org".to_string(),
        )
        .with_documentation_url("https://example.org/docs".to_string())
        .with_streaming()
        .add_comprehensive_skill(
            "echo".to_string(),
            "Echo Skill".to_string(),
            Some("Echoes back the user's message".to_string()),
            Some(vec!["echo".to_string(), "respond".to_string()]),
            Some(vec!["Echo: Hello World".to_string()]),
            Some(vec!["text".to_string()]),
            Some(vec!["text".to_string()]),
        );

    // Server without authentication
    let server = HttpServer::new(processor, agent_info, addr.clone());

    println!("🔗 HTTP server listening on http://{}", addr);
    server.start().await.map_err(|e| anyhow::anyhow!(e))
}
