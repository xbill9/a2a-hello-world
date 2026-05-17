import asyncio
import json
import httpx
import sys

# Cloud Run Service URL provided by the user
CLOUD_RUN_URL = "https://a2a-server-rust-1056842563084.us-central1.run.app"

async def test_a2a_cloud_run(server_url: str):
    print(f"🧪 Validating A2A Server at: {server_url}")
    
    async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
        try:
            # 1. Test Discovery
            print("\n🔍 Step 1: Discovery...")
            
            # Try GET /
            print("  Trying GET / ...")
            resp = await client.get(f"{server_url}/")
            if resp.status_code == 200:
                print("  ✅ GET / success")
                info = resp.json()
            else:
                print(f"  ❌ GET / failed: {resp.status_code}")
                
                # Try GET /.well-known/agent-card.json
                print("  Trying GET /.well-known/agent-card.json ...")
                resp = await client.get(f"{server_url}/.well-known/agent-card.json")
                if resp.status_code == 200:
                    print("  ✅ GET /.well-known/agent-card.json success")
                    info = resp.json()
                else:
                    print(f"  ❌ GET /.well-known/agent-card.json failed: {resp.status_code}")
                    
                    # Try POST / with JSON-RPC discovery
                    print("  Trying POST / (JSON-RPC) ...")
                    rpc_payload = {
                        "jsonrpc": "2.0",
                        "method": "discovery",
                        "params": {},
                        "id": 1
                    }
                    resp = await client.post(f"{server_url}/", json=rpc_payload)
                    if resp.status_code == 200:
                        print("  ✅ POST / success")
                        rpc_resp = resp.json()
                        if "result" in rpc_resp:
                            info = rpc_resp["result"]
                        else:
                            print(f"  ⚠️ RPC Response: {rpc_resp}")
                            return
                    else:
                        print(f"  ❌ POST / failed: {resp.status_code}")
                        print(f"  Response: {resp.text}")
                        return

            print(f"📄 Agent Name: {info.get('name')}")
            skills = [s.get('name') for s in info.get('skills', [])]
            print(f"📄 Skills: {skills}")

            # 2. Test Create Task
            print("\n🧪 Step 2: Creating A2A Task...")
            task_id = "cloud-run-test-task"
            task_payload = {
                "task_id": task_id,
                "context_id": "cloud-run-validation-context"
            }
            
            # Try POST /tasks (REST)
            print("  Trying POST /tasks ...")
            resp = await client.post(f"{server_url}/tasks", json=task_payload)
            if resp.status_code in [200, 201]:
                print(f"  ✅ Task '{task_id}' created successfully (REST)")
            else:
                print(f"  ❌ POST /tasks failed: {resp.status_code}")
                
                # Try JSON-RPC create_task
                print("  Trying JSON-RPC create_task ...")
                rpc_payload = {
                    "jsonrpc": "2.0",
                    "method": "create_task",
                    "params": task_payload,
                    "id": 2
                }
                resp = await client.post(f"{server_url}/", json=rpc_payload)
                if resp.status_code == 200:
                    print(f"  ✅ Task '{task_id}' created successfully (RPC)")
                else:
                    print(f"  ❌ RPC create_task failed: {resp.status_code}")
                    return

            # 3. Test Message Processing
            print("\n🧪 Step 3: Sending Echo Message...")
            message_payload = {
                "role": "user",
                "content": [{"text": "Hello from Cloud Run Test Client! Echo this."}]
            }
            
            # Try REST
            print(f"  Trying POST /tasks/{task_id}/messages ...")
            resp = await client.post(
                f"{server_url}/tasks/{task_id}/messages", 
                json=message_payload
            )
            
            if resp.status_code == 200:
                result = resp.json()
                print("  ✅ Message processed (REST)")
            else:
                print(f"  ❌ REST message failed: {resp.status_code}")
                
                # Try RPC
                print("  Trying RPC process_message ...")
                rpc_payload = {
                    "jsonrpc": "2.0",
                    "method": "process_message",
                    "params": {
                        "task_id": task_id,
                        "message": message_payload
                    },
                    "id": 3
                }
                resp = await client.post(f"{server_url}/", json=rpc_payload)
                if resp.status_code == 200:
                    result = resp.json().get("result", {})
                    print("  ✅ Message processed (RPC)")
                else:
                    print(f"  ❌ RPC message failed: {resp.status_code}")
                    return

            # Check history
            history = result.get('history', [])
            if history:
                assistant_msgs = [m for m in history if m.get('role') == 'assistant']
                if assistant_msgs:
                    print(f"🤖 Agent Response: {json.dumps(assistant_msgs[-1], indent=2)}")
                else:
                    print("⚠️ No assistant message in history.")
            else:
                print("⚠️ No history returned.")

        except Exception as e:
            print(f"💥 Error during validation: {str(e)}")

if __name__ == "__main__":
    url = CLOUD_RUN_URL
    if len(sys.argv) > 1:
        url = sys.argv[1]
    if url.endswith("/"):
        url = url[:-1]
    asyncio.run(test_a2a_cloud_run(url))
