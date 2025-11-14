"""This module defines a simple agent that can get the weather and time."""

import datetime
import random
from google.adk.agents import Agent
from google.adk.a2a.utils.agent_to_a2a import to_a2a
import uvicorn



def get_random_even_number() -> dict:
    """Generates a random even number between 0 and 200.

    Returns:
        dict: status and result.
    """
    even_number = random.randint(0, 100) * 2
    return {"status": "success", "report": f"Random even number: {even_number}"}


def get_random_odd_number() -> dict:
    """Generates a random odd number between 1 and 201.

    Returns:
        dict: status and result.
    """
    odd_number = random.randint(0, 100) * 2 + 1
    return {"status": "success", "report": f"Random odd number: {odd_number}"}


root_agent = Agent(
    name="poly_rand_agent",
    model="gemini-2.5-flash",
    description=(
        "Agent to generate random numbers."
    ),
    instruction=(
        "You are a helpful agent who can generate "
        "random even and odd numbers."
    ),
    tools=[
        get_random_even_number,
        get_random_odd_number,
    ],
)

if __name__ == "__main__":
    a2a_app = to_a2a(root_agent, port=8087)
    # Use host='0.0.0.0' to allow external access.
    uvicorn.run(a2a_app, host="0.0.0.0", port=8087)
