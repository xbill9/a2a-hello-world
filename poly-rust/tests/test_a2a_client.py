import asyncio
import json
import httpx

async def test_a2a_server():
    print("🧪 Validating A2A Server Discovery...")
    server_url = "http://localhost:8080"
    
    async with httpx.AsyncClient() as client:
        try:
            # 1. Test Discovery Endpoint (GET /)
            response = await client.get(f"{server_url}/")
            if response.status_code == 200:
                print("✅ Discovery endpoint reachable")
                info = response.json()
                print(f"📄 Agent Name: {info.get('name')}")
                print(f"📄 Skills: {[s.get('name') for s in info.get('skills', [])]}")
            else:
                print(f"❌ Discovery endpoint failed: {response.status_code}")
                return

            # 2. Test Create Task (POST /tasks)
            print("\n🧪 Creating A2A Task...")
            task_id = "test-task-python"
            task_payload = {
                "task_id": task_id,
                "context_id": "python-validation-context"
            }
            response = await client.post(f"{server_url}/tasks", json=task_payload)
            if response.status_code in [200, 201]:
                print(f"✅ Task '{task_id}' created successfully")
            else:
                print(f"❌ Task creation failed: {response.status_code}")
                print(response.text)
                return

            # 3. Test Message Processing (POST /tasks/{id}/messages)
            # The A2A protocol typically expects a JSON body matching the Message domain object
            print("\n🧪 Sending Echo Message...")
            message_payload = {
                "role": "user",
                "content": [{"text": "Hello Rust A2A Server! Echo this."}]
            }
            response = await client.post(
                f"{server_url}/tasks/{task_id}/messages", 
                json=message_payload
            )
            
            if response.status_code == 200:
                result = response.json()
                print("✅ Message processed")
                print(f"🔄 Task State: {result.get('state')}")
                
                # Check for echo response in history
                history = result.get('history', [])
                if history:
                    last_msg = history[-1]
                    print(f"🤖 Agent Response: {json.dumps(last_msg, indent=2)}")
                else:
                    print("⚠️ No message history returned in the response.")
            else:
                print(f"❌ Message processing failed: {response.status_code}")
                print(response.text)

        except Exception as e:
            print(f"💥 Error during validation: {str(e)}")

if __name__ == "__main__":
    asyncio.run(test_a2a_server())
