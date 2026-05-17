import asyncio
import json
import httpx
import sys

async def echo_test():
    server_url = "http://localhost:8080"
    print(f"🚀 Testing Local A2A Echo Skill at {server_url}")
    
    async with httpx.AsyncClient() as client:
        try:
            # 1. Create Task
            task_id = "local-echo-test"
            task_payload = {
                "task_id": task_id,
                "context_id": "local-test-context"
            }
            print(f"📝 Creating task '{task_id}'...")
            response = await client.post(f"{server_url}/tasks", json=task_payload)
            if response.status_code not in [200, 201]:
                print(f"❌ Task creation failed: {response.status_code}")
                print(response.text)
                return

            # 2. Send Echo Message
            test_message = "Hello from the local test program!"
            print(f"💬 Sending message: '{test_message}'")
            message_payload = {
                "role": "user",
                "content": [{"text": test_message}]
            }
            response = await client.post(
                f"{server_url}/tasks/{task_id}/messages", 
                json=message_payload
            )
            
            if response.status_code == 200:
                result = response.json()
                # The response from process_message includes the updated task state
                history = result.get('history', [])
                if history:
                    # Find the last message from the assistant
                    assistant_msgs = [m for m in history if m.get('role') == 'assistant']
                    if assistant_msgs:
                        last_reply = assistant_msgs[-1]
                        content = last_reply.get('content', [])
                        reply_text = ""
                        for item in content:
                            if 'text' in item:
                                reply_text += item['text']
                        
                        print(f"✅ Received echo: '{reply_text}'")
                        if test_message in reply_text:
                            print("🌟 Success! The echo skill is working correctly.")
                        else:
                            print("⚠️ The response received doesn't seem to be an echo.")
                    else:
                        print("⚠️ No assistant response found in history.")
                else:
                    print("⚠️ No message history returned.")
            else:
                print(f"❌ Message processing failed: {response.status_code}")
                print(response.text)

        except Exception as e:
            print(f"💥 Error: {str(e)}")
            print("Is the server running? Try 'make start' in another terminal.")

if __name__ == "__main__":
    asyncio.run(echo_test())
