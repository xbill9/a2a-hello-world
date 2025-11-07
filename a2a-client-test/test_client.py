import asyncio
import logging
import os
import sys
import traceback
from typing import Any
from uuid import uuid4

import httpx
from a2a.client import A2AClient, A2ACardResolver
from a2a.client.errors import A2AClientHTTPError
from a2a.types import (
    GetTaskRequest,
    GetTaskResponse,
    MessageSendParams,
    SendMessageRequest,
    SendMessageResponse,
    SendMessageSuccessResponse,
    Task,
    TaskQueryParams,
    TaskState,
)

AGENT_URL = os.getenv("AGENT_URL", "http://localhost:8080")


def create_send_message_payload(
    text: str, task_id: str | None = None, context_id: str | None = None
) -> dict[str, Any]:
    """Helper function to create the payload for sending a message."""
    payload: dict[str, Any] = {
        "message": {
            "role": "user",
            "parts": [{"kind": "text", "text": text}],
            "messageId": uuid4().hex,
        },
    }

    if task_id:
        payload["message"]["taskId"] = task_id

    if context_id:
        payload["message"]["contextId"] = context_id
    return payload


def log_json_response(response: Any, description: str) -> None:
    """Helper function to log the JSON representation of a response."""
    logging.info(f"--- {description} ---")
    if hasattr(response, "root"):
        logging.info(f"{response.root.model_dump_json(exclude_none=True)}\n")
    else:
        logging.info(f"{response.model_dump(mode='json', exclude_none=True)}\n")


async def run_single_turn_test(client: A2AClient) -> None:
    """Runs a single-turn non-streaming test."""

    send_message_payload = create_send_message_payload(
        text="what is the weather in new york"
    )
    request = SendMessageRequest(
        id=str(uuid4()), params=MessageSendParams(**send_message_payload)
    )

    logging.info("--- ✉️  Single Turn Request ---")
    # Send Message
    response: SendMessageResponse = await client.send_message(request)
    log_json_response(response, "📥 Single Turn Request Response")
    if not isinstance(response.root, SendMessageSuccessResponse):
        logging.warning("received non-success response. Aborting get task ")
        return

    if not isinstance(response.root.result, Task):
        logging.warning("received non-task response. Aborting get task ")
        return

    task_id: str = response.root.result.id
    logging.info("--- ❔ Query Task ---")
    # query the task
    get_request = GetTaskRequest(id=str(uuid4()), params=TaskQueryParams(id=task_id))
    get_response: GetTaskResponse = await client.get_task(get_request)
    log_json_response(get_response, "📥 Query Task Response")


async def run_multi_turn_test(client: A2AClient) -> None:
    """Runs a multi-turn non-streaming test."""
    logging.info("--- 📝 Multi-Turn Request ---")
    # --- First Turn ---

    first_turn_payload = create_send_message_payload(
        text="what is the time in new york"
    )
    request1 = SendMessageRequest(
        id=str(uuid4()), params=MessageSendParams(**first_turn_payload)
    )
    first_turn_response: SendMessageResponse = await client.send_message(request1)
    log_json_response(first_turn_response, "📥 Multi-Turn: First Turn Response")

    context_id: str | None = None
    if isinstance(first_turn_response.root, SendMessageSuccessResponse) and isinstance(
        first_turn_response.root.result, Task
    ):
        task: Task = first_turn_response.root.result
        context_id = task.context_id  # Capture context ID

        # --- Second Turn (if input required) ---
        if task.status.state == TaskState.input_required and context_id:
            logging.info("--- 📝 Multi-Turn: Second Turn (Input Required) ---")
            second_turn_payload = create_send_message_payload(
                " is the same time in hoboken NJ", task.id, context_id
            )
            request2 = SendMessageRequest(
                id=str(uuid4()), params=MessageSendParams(**second_turn_payload)
            )
            second_turn_response = await client.send_message(request2)
            log_json_response(
                second_turn_response, "Multi-Turn: Second Turn Response"
            )
        elif not context_id:
            logging.warning(
                "--- ⚠️ Warning: Could not get context ID from first turn response. ---"
            )
        else:
            logging.info(
                "--- 🚀 First turn completed, no further input required for this test case. ---"
            )


async def main() -> None:
    """Main function to run the tests."""
    logging.basicConfig(level=logging.INFO)
    logging.info(f"--- 🔄 Connecting to agent at {AGENT_URL}... ---")
    try:
        async with httpx.AsyncClient() as httpx_client:
            # Create a resolver to fetch the agent card
            resolver = A2ACardResolver(
                httpx_client=httpx_client,
                base_url=AGENT_URL,
            )
            agent_card = await resolver.get_agent_card()
            # Create a client to interact with the agent
            client = A2AClient(
                httpx_client=httpx_client,
                agent_card=agent_card,
            )
            logging.info("--- ✅ Connection successful. ---")

            await run_single_turn_test(client)
            await run_multi_turn_test(client)

    except A2AClientHTTPError as e:
        logging.error(f"--- ❌ A2A Client HTTP error: {e} ---")
        logging.error(f"Could not connect to the agent at {AGENT_URL}.")
        logging.error("Please ensure the a2a server is running and accessible.")
        sys.exit(1)
    except httpx.ConnectError as e:
        logging.error(f"--- ❌ Connection error: {e} ---")
        logging.error(f"Could not connect to the agent at {AGENT_URL}.")
        logging.error("Please ensure the a2a server is running and accessible.")
        sys.exit(1)
    except Exception as e:
        logging.error(f"--- ❌ An unexpected error occurred: {e} ---")
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
