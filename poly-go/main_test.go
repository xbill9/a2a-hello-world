package main

import (
	"testing"

	"google.golang.org/adk/tool"
)

func TestIsPrime(t *testing.T) {
	tests := []struct {
		name     string
		input    int
		expected bool
	}{
		{"Negative number", -1, false},
		{"Zero", 0, false},
		{"One", 1, false},
		{"Two (Prime)", 2, true},
		{"Three (Prime)", 3, true},
		{"Four (Not Prime)", 4, false},
		{"Nine (Not Prime)", 9, false},
		{"Seventeen (Prime)", 17, true},
		{"Large Prime", 97, true},
		{"Large Non-Prime", 100, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isPrime(tt.input); got != tt.expected {
				t.Errorf("isPrime(%d) = %v; want %v", tt.input, got, tt.expected)
			}
		})
	}
}

func TestCheckPrimeTool(t *testing.T) {
	tests := []struct {
		name     string
		args     checkPrimeToolArgs
		expected string
	}{
		{
			name:     "Mixed primes and non-primes",
			args:     checkPrimeToolArgs{Nums: []int{2, 4, 5, 9}},
			expected: "2, 5 are prime numbers.",
		},
		{
			name:     "No primes",
			args:     checkPrimeToolArgs{Nums: []int{4, 6, 8}},
			expected: "No prime numbers found.",
		},
		{
			name:     "All primes",
			args:     checkPrimeToolArgs{Nums: []int{2, 3, 7}},
			expected: "2, 3, 7 are prime numbers.",
		},
		{
			name:     "Empty list",
			args:     checkPrimeToolArgs{Nums: []int{}},
			expected: "No prime numbers found.",
		},
	}

	// Mock tool context (not used in logic, so can be empty/nil interface)
	var tc tool.Context

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := checkPrimeTool(tc, tt.args)
			if err != nil {
				t.Fatalf("checkPrimeTool() error = %v; want nil", err)
			}
			if got != tt.expected {
				t.Errorf("checkPrimeTool() = %q; want %q", got, tt.expected)
			}
		})
	}
}
