use a2a_rs::{HttpClient, Message};
use a2a_rs::services::AsyncA2AClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = HttpClient::new("http://localhost:8080".to_string());

    let message = Message::user_text("what is the weather in new york".to_string(), "some-message-id".to_string());
    let task = client.send_task_message("get_weather", &message, None, None).await?;

    println!("Response: {:?}", task);
    Ok(())
}
