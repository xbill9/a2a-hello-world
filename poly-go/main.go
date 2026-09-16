// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/a2aproject/a2a-go/a2a"
	"github.com/a2aproject/a2a-go/a2asrv"
	"google.golang.org/adk/agent/llmagent"
	"google.golang.org/adk/model/gemini"
	"google.golang.org/adk/runner"
	"google.golang.org/adk/server/adka2a"
	"google.golang.org/adk/session"
	"google.golang.org/adk/tool"
	"google.golang.org/adk/tool/functiontool"
	"google.golang.org/genai"
)

// apiPath is where the JSON-RPC endpoint is served, matching the ADK launcher.
const apiPath = "/a2a/invoke"

// isPrime checks if a number is prime.
func isPrime(n int) bool {
	if n <= 1 {
		return false
	}
	for i := 2; i*i <= n; i++ {
		if n%i == 0 {
			return false
		}
	}
	return true
}

type checkPrimeToolArgs struct {
	Nums []int `json:"nums" jsonschema:"A list of numbers to check for primality."`
}

func checkPrimeTool(tc tool.Context, args checkPrimeToolArgs) (string, error) {
	var primes []int
	for _, num := range args.Nums {
		if isPrime(num) {
			primes = append(primes, num)
		}
	}
	if len(primes) == 0 {
		return "No prime numbers found.", nil
	}
	var primeStrings []string
	for _, p := range primes {
		primeStrings = append(primeStrings, strconv.Itoa(p))
	}
	return fmt.Sprintf("%s are prime numbers.", strings.Join(primeStrings, ", ")), nil
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	ctx := context.Background()
	primeTool, err := functiontool.New(functiontool.Config{
		Name:        "prime_checking",
		Description: "Check if numbers in a list are prime using efficient mathematical algorithms",
	}, checkPrimeTool)
	if err != nil {
		slog.Error("Failed to create prime_checking tool", "error", err)
		os.Exit(1)
	}

	modelName := os.Getenv("MODEL_NAME")
	if modelName == "" {
		modelName = "gemini-2.5-flash"
	}

	model, err := gemini.NewModel(ctx, modelName, &genai.ClientConfig{})
	if err != nil {
		slog.Error("Failed to create model", "error", err)
		os.Exit(1)
	}

	primeAgent, err := llmagent.New(llmagent.Config{
		Name:        "check_prime_agent",
		Description: "check prime agent that can check whether numbers are prime.",
		Instruction: `
			You check whether numbers are prime.
			When checking prime numbers, call the check_prime tool with a list of integers. Be sure to pass in a list of integers. You should never pass in a string.
			You should not rely on the previous history on prime results.
    `,
		Model: model,
		Tools: []tool.Tool{primeTool},
	})
	if err != nil {
		slog.Error("Failed to create agent", "error", err)
		os.Exit(1)
	}

	// Allow PORT to be set by the environment (e.g., Cloud Run), default to 8086
	portStr := os.Getenv("PORT")
	if portStr == "" {
		portStr = "8086"
	}

	// URL advertised in the agent card. ADK's RemoteA2aAgent only accepts plain
	// http on a loopback host (0.0.0.0 is rejected), so default to localhost.
	agentURL := os.Getenv("A2A_AGENT_URL")
	if agentURL == "" {
		agentURL = "http://localhost:" + portStr
	}
	publicURL, err := url.JoinPath(agentURL, apiPath)
	if err != nil {
		slog.Error("Invalid A2A_AGENT_URL", "url", agentURL, "error", err)
		os.Exit(1)
	}

	// The card is built here rather than by the ADK launcher so it can declare
	// ProtocolVersion. a2a-go serves A2A v0.3 JSON-RPC (message/send); without a
	// declared version, a2a-sdk 1.x clients such as the Python ADK masters
	// assume v1.0 and call SendMessage, which this server rejects.
	agentCard := &a2a.AgentCard{
		Name:               primeAgent.Name(),
		Description:        primeAgent.Description(),
		ProtocolVersion:    "0.3.0",
		DefaultInputModes:  []string{"text/plain"},
		DefaultOutputModes: []string{"text/plain"},
		URL:                publicURL,
		PreferredTransport: a2a.TransportProtocolJSONRPC,
		Skills:             adka2a.BuildAgentSkills(primeAgent),
		Capabilities:       a2a.AgentCapabilities{Streaming: true},
	}

	executor := adka2a.NewExecutor(adka2a.ExecutorConfig{
		RunnerConfig: runner.Config{
			AppName:        primeAgent.Name(),
			Agent:          primeAgent,
			SessionService: session.InMemoryService(),
		},
	})

	mux := http.NewServeMux()
	mux.Handle(a2asrv.WellKnownAgentCardPath, a2asrv.NewStaticAgentCardHandler(agentCard))
	mux.Handle(apiPath, a2asrv.NewJSONRPCHandler(a2asrv.NewHandler(executor)))

	server := &http.Server{
		Addr:              ":" + portStr,
		Handler:           mux,
		ReadHeaderTimeout: 15 * time.Second,
	}

	slog.Info("Starting A2A prime checker server", "port", portStr, "card_url", publicURL)
	if err := server.ListenAndServe(); err != nil {
		slog.Error("A2A server stopped", "error", err)
		os.Exit(1)
	}
}
