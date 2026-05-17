# Makefile for the Rust project

# Variables
SERVICE_NAME := a2a-server-rust
REGION := us-central1
PROJECT_ID := $(shell gcloud config get-value project)

.PHONY: all build run start clean release test lint format check-fmt clippy check docker-build deploy publish doc endpoint status help

# The default target
all: build

# Build the project for development
build:
	@echo "Building the Rust project..."
	@cargo build

# Run the project
run:
	@echo "Running the Rust project..."
	PROJECT_ID=$(PROJECT_ID) cargo run

# Start the A2A server locally
start:
	@echo "Starting the A2A Rust server on port 8080..."
	@PORT=8080 PROJECT_ID=$(PROJECT_ID) cargo run

# Get the Cloud Run service endpoint
endpoint:
	@gcloud run services describe $(SERVICE_NAME) --platform managed --region $(REGION) --format 'value(status.url)'

# Check local and remote service status
status:
	@echo "--- Service Status ---"
	@echo -n "Local (8080): "
	@curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/ || echo "OFFLINE"
	@echo -n "Remote ($(SERVICE_NAME)): "
	@URL=$$(gcloud run services describe $(SERVICE_NAME) --platform managed --region $(REGION) --format 'value(status.url)' 2>/dev/null); \
	if [ -n "$$URL" ]; then \
		curl -s -o /dev/null -w "%{http_code} ($$URL)\n" $$URL; \
	else \
		echo "NOT DEPLOYED"; \
	fi

# Clean the project
clean:
	@echo "Cleaning the project..."
	@cargo clean

# Build the project for release
release:
	@echo "Building Release..."
	@cargo build --release

# Run tests
test:
	@echo "Running tests..."
	@cargo test

# Format the code
format:
	@echo "Formatting code..."
	@cargo fmt --all

# Check formatting
check-fmt:
	@echo "Checking formatting..."
	@cargo fmt --all -- --check

# Lint the code
lint: clippy check-fmt

clippy:
	@echo "Linting code..."
	@cargo clippy -- -D warnings

# Check the code
check:
	@echo "Checking the code..."
	@cargo check

# Publish the crate
publish:
	@echo "Publishing the crate..."
	@cargo publish

update:
	@cargo update --verbose

# Generate documentation
doc:
	@echo "Generating documentation..."
	@cargo doc

# Build the Docker image
docker-build:
	@echo "Building the Docker image..."
	@docker build -t gcr.io/$(PROJECT_ID)/$(SERVICE_NAME):latest .

# Submit the build to Google Cloud Build and deploy to Cloud Run
deploy:
	@echo "Submitting build to Google Cloud Build..."
	@gcloud builds submit . --config cloudbuild.yaml --substitutions=_SERVICE_NAME=$(SERVICE_NAME)

help:
	@echo "Makefile for the Rust project"
	@echo ""
	@echo "Usage:"
	@echo "    make <target>"
	@echo ""
	@echo "Targets:"
	@echo "    all          (default) same as 'build'"
	@echo "    build        Build the project for development"
	@echo "    run          Run the project"
	@echo "    start        Start the local A2A server"
	@echo "    clean        Clean the project"
	@echo "    release      Build the project for release"
	@echo "    test         Run tests"
	@echo "    lint         Lint the code (clippy + fmt check)"
	@echo "    format       Format the code"
	@echo "    check-fmt    Check code formatting"
	@echo "    clippy       Lint the code"
	@echo "    check        Check the code"
	@echo "    publish      Publish the crate"
	@echo "    doc          Generate documentation"
	@echo "    endpoint     Get Cloud Run service endpoint"
	@echo "    status       Check local and remote service status"
	@echo "    docker-build Build the Docker image"
	@echo "    deploy       Deploy the A2A agent to Google Cloud Run (via Cloud Build)"
