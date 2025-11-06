# A2A Hello World

## Project Overview
This project serves as a foundational "Hello World" example for developing agents using the Google Agent Development Kit (ADK) and the Agent-to-Agent (A2A) protocol. It demonstrates how to build a simple Python-based agent capable of interacting with external tools (like fetching weather and time information) and provides a comprehensive set of scripts for local development, testing, and deployment to Google Cloud Run. The primary goal is to offer a clear, runnable template for developers to quickly get started with ADK and A2A agent development.

## Setup Scripts

*   `init.sh`: Initializes the environment by prompting the user for their Google Cloud project ID and Gemini API Key. It also runs `gcloud auth application-default login` to get user credentials.
*   `set_env.sh`: Sets various environment variables required for the other scripts to run. It reads the project ID and Gemini key from the files created by `init.sh`. This script also sets the `PUBLIC_URL` environment variable, which is used to configure the public URL for the agent.

## ADK Execution Scripts

These scripts facilitate running the agent in various modes and environments:

*   `cli.sh` / `run.sh`: Runs the agent in command-line mode, allowing you to interact with it from your terminal.
*   `local.sh`: Runs the agent in a local web server, accessible typically at `http://localhost:8080`.
*   `web.sh`: Runs the agent in a local web server and automatically opens the UI in your default web browser.
*   `webvm.sh`: Runs the agent in a local web server, listening on all network interfaces (`0.0.0.0`). This is particularly useful for accessing the agent from a host machine when running within a virtual machine or container.
*   `api_server.sh`: Runs the agent in API server mode, exposing its functionalities via a RESTful API.
*   `cloudrun.sh`: Deploys the agent as a scalable service to Google Cloud Run, making it accessible publicly.

## Agent Details

The core agent logic is defined in `src/agents/a2a_hello_world/agent.py`. This simple agent demonstrates:

*   **Tool Usage:** It utilizes two predefined tools: `get_weather` to retrieve current weather conditions for a specified city, and `get_current_time` to obtain the current time for a given location.
*   **Model Integration:** The agent is configured to use the `gemini-1.5-flash` model for its conversational capabilities and tool orchestration.

## Development

To extend or modify this agent:

1.  **Locate Agent Code:** The main agent implementation is in `src/agents/a2a_hello_world/agent.py`.
2.  **Add Tools:** Define new tools within the agent's `tools` list, similar to `get_weather` and `get_current_time`.
3.  **Modify Agent Logic:** Adjust the agent's prompt or add new functionalities within the `agent.py` file.
4.  **Dependencies:** If new Python packages are required, add them to `src/agents/a2a_hello_world/requirements.txt` and run `pip install -r src/agents/a2a_hello_world/requirements.txt`.
5.  **Testing:** Utilize the `cli.sh` or `local.sh` scripts for quick local testing during development.