package clipbarquota

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeHTTP struct {
	mu       sync.Mutex
	requests []HTTPRequest
	response HTTPResponse
	err      error
}

func (f *fakeHTTP) Do(_ context.Context, request HTTPRequest) (HTTPResponse, error) {
	f.mu.Lock()
	f.requests = append(f.requests, request)
	f.mu.Unlock()
	return f.response, f.err
}

func rpcResult(value any) []byte {
	result, _ := json.Marshal(value)
	raw, _ := json.Marshal(Envelope{OK: true, Result: result})
	return raw
}

func TestConfigFromYAMLUsesDefaultsAndIgnoresCPAFields(t *testing.T) {
	config, err := ConfigFromYAML([]byte("enabled: true\npriority: 7\nrequest_timeout_seconds: 45\nmax_concurrency: 3\n"))
	if err != nil {
		t.Fatalf("ConfigFromYAML() error = %v", err)
	}
	if config.RequestTimeoutSeconds != 45 || config.MaxConcurrency != 3 {
		t.Fatalf("decoded config = %#v", config)
	}

	defaults, err := ConfigFromYAML(nil)
	if err != nil {
		t.Fatalf("ConfigFromYAML(nil) error = %v", err)
	}
	if defaults != DefaultConfig() {
		t.Fatalf("empty config = %#v, want %#v", defaults, DefaultConfig())
	}
}

func TestConfigFromYAMLRejectsMalformedInput(t *testing.T) {
	if _, err := ConfigFromYAML([]byte("request_timeout_seconds: [")); err == nil {
		t.Fatal("ConfigFromYAML() error = nil, want malformed YAML error")
	}
}

func TestConfigureYAMLReplacesConfigurationOnReconfigure(t *testing.T) {
	plugin := New(Host{}, DefaultConfig())
	if err := plugin.ConfigureYAML([]byte("request_timeout_seconds: 45\nmax_concurrency: 3\n")); err != nil {
		t.Fatalf("ConfigureYAML(first) error = %v", err)
	}
	plugin.mu.RLock()
	first := plugin.config
	plugin.mu.RUnlock()
	if first.RequestTimeoutSeconds != 45 || first.MaxConcurrency != 3 {
		t.Fatalf("first configuration = %#v", first)
	}

	if err := plugin.ConfigureYAML([]byte("enabled: false\npriority: 100\nrequest_timeout_seconds: 9\n")); err != nil {
		t.Fatalf("ConfigureYAML(second) error = %v", err)
	}
	plugin.mu.RLock()
	second := plugin.config
	plugin.mu.RUnlock()
	if second.RequestTimeoutSeconds != 9 || second.MaxConcurrency != DefaultConfig().MaxConcurrency {
		t.Fatalf("second configuration = %#v", second)
	}
}

func TestNormalizeProvider(t *testing.T) {
	cases := map[string]string{
		"OpenAI":      "codex",
		"anthropic":   "claude",
		"gemini":      "gemini-cli",
		"antigravity": "antigravity",
		"moonshot":    "kimi",
		"grok":        "xai",
		"other":       "unknown",
	}
	for raw, want := range cases {
		got, _ := normalizeProvider(raw)
		if got != want {
			t.Errorf("normalizeProvider(%q) = %q, want %q", raw, got, want)
		}
	}
}

func TestParseProviderSnapshots(t *testing.T) {
	codex := parseCodex(map[string]any{
		"plan_type": "plus",
		"rate_limit": map[string]any{
			"primary_window":   map[string]any{"used_percent": 20.0, "reset_after_seconds": 3600.0},
			"secondary_window": map[string]any{"used_percent": 40.0, "limit_window_seconds": 604800.0},
		},
	})
	if len(codex.Windows) != 2 || codex.Windows[0].RemainingPercent == nil || *codex.Windows[0].RemainingPercent != 80 {
		t.Fatalf("unexpected codex snapshot: %#v", codex)
	}
	if codex.Windows[1].Label != "Week" {
		t.Fatalf("codex weekly label = %q", codex.Windows[1].Label)
	}

	claude := parseClaude(map[string]any{"five_hour": map[string]any{"utilization": 25.0}})
	if len(claude.Windows) != 1 || claude.Windows[0].RemainingPercent == nil || *claude.Windows[0].RemainingPercent != 75 {
		t.Fatalf("unexpected Claude snapshot: %#v", claude)
	}

	gemini := parseGemini(map[string]any{"buckets": []any{
		map[string]any{"modelId": "gemini-2.0-flash-preview", "remainingFraction": 0.5},
	}})
	if len(gemini.Windows) != 1 || gemini.Windows[0].Label != "2.0-flash" || *gemini.Windows[0].RemainingPercent != 50 {
		t.Fatalf("unexpected Gemini snapshot: %#v", gemini)
	}

	antigravity := parseAntigravity(map[string]any{"currentTier": map[string]any{"name": "pro"}, "groups": []any{
		map[string]any{"buckets": []any{map[string]any{"window": "5h", "remainingFraction": 0.8}}},
		map[string]any{"buckets": []any{map[string]any{"window": "weekly", "remainingFraction": 0.6}}},
	}})
	if len(antigravity.Windows) != 2 || antigravity.PlanType != "Pro" {
		t.Fatalf("unexpected Antigravity snapshot: %#v", antigravity)
	}

	kimi := parseKimi(map[string]any{"usage": map[string]any{"detail": map[string]any{"limit": 100.0, "remaining": 25.0}}})
	if len(kimi.Windows) != 1 || *kimi.Windows[0].RemainingPercent != 25 {
		t.Fatalf("unexpected Kimi snapshot: %#v", kimi)
	}

	xai := parseXAI(map[string]any{"creditUsagePercent": 30.0, "productUsage": []any{
		map[string]any{"product": "Grok", "usagePercent": 10.0},
		map[string]any{"product": "GrokBuild", "usagePercent": 20.0},
	}})
	if len(xai.Windows) != 2 || xai.Windows[0].ID != "week" || xai.Windows[1].ID != "product-Grok" {
		t.Fatalf("unexpected xAI snapshot: %#v", xai)
	}
}

func TestRefreshUsesHostCallbacksAndHTTPBridgeWithoutLeakingCredential(t *testing.T) {
	bridge := &fakeHTTP{response: HTTPResponse{
		StatusCode: http.StatusOK,
		Body:       []byte(`{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":10,"reset_after_seconds":60}}}`),
	}}
	var calls []string
	var mu sync.Mutex
	host := Host{HTTP: bridge, Call: func(_ context.Context, method string, request []byte) ([]byte, error) {
		mu.Lock()
		calls = append(calls, method)
		mu.Unlock()
		switch method {
		case MethodHostAuthList:
			return rpcResult(HostAuthListResponse{Files: []HostAuthFile{{ID: "id-1", AuthIndex: "idx-1", Name: "account.json", Provider: "OpenAI", Status: "active"}}}), nil
		case MethodHostAuthGet:
			var req HostAuthGetRequest
			if err := json.Unmarshal(request, &req); err != nil || req.AuthIndex != "idx-1" {
				t.Fatalf("unexpected auth get request: %s", request)
			}
			return rpcResult(HostAuthGetResponse{AuthIndex: req.AuthIndex, JSON: json.RawMessage(`{"access_token":"placeholder-token","account_id":"acct-1"}`)}), nil
		default:
			return nil, nil
		}
	}}
	plugin := New(host, Config{RequestTimeoutSeconds: 2, MaxConcurrency: 1})
	snapshot, err := plugin.Refresh(context.Background(), "callback-1")
	if err != nil {
		t.Fatalf("Refresh() error = %v", err)
	}
	if len(snapshot.Accounts) != 1 || len(snapshot.Accounts[0].Snapshot.Windows) != 1 {
		t.Fatalf("unexpected refreshed snapshot: %#v", snapshot)
	}
	if snapshot.Accounts[0].Snapshot.Error != nil {
		t.Fatalf("account error = %v", *snapshot.Accounts[0].Snapshot.Error)
	}
	mu.Lock()
	defer mu.Unlock()
	if strings.Join(calls, ",") != MethodHostAuthList+","+MethodHostAuthGet {
		t.Fatalf("host callback calls = %v", calls)
	}
	bridge.mu.Lock()
	defer bridge.mu.Unlock()
	if len(bridge.requests) != 1 || bridge.requests[0].HostCallbackID != "callback-1" {
		t.Fatalf("HTTP bridge requests = %#v", bridge.requests)
	}
	if got := bridge.requests[0].Headers["Authorization"][0]; got != "Bearer placeholder-token" {
		t.Fatalf("authorization header = %q", got)
	}
}

func TestSnapshotReturnsIndependentNestedCopies(t *testing.T) {
	plugin := New(Host{}, DefaultConfig())
	remaining := 82.0
	reset := "2h"
	errMessage := "cached error"
	now := time.Now().UTC()
	plugin.mu.Lock()
	plugin.snapshot = Snapshot{
		SchemaVersion: SnapshotSchema,
		LastUpdatedAt: &now,
		Accounts: []AccountQuota{{Snapshot: QuotaSnapshot{
			Windows: []QuotaWindow{{RemainingPercent: &remaining, ResetText: &reset}},
			Error:   &errMessage,
		}}},
	}
	plugin.mu.Unlock()

	copy := plugin.Snapshot()
	*copy.LastUpdatedAt = copy.LastUpdatedAt.Add(time.Hour)
	*copy.Accounts[0].Snapshot.Windows[0].RemainingPercent = 1
	*copy.Accounts[0].Snapshot.Windows[0].ResetText = "changed"
	*copy.Accounts[0].Snapshot.Error = "changed"

	original := plugin.Snapshot()
	if original.LastUpdatedAt == nil || !original.LastUpdatedAt.Equal(now) {
		t.Fatalf("snapshot timestamp was aliased: %#v", original.LastUpdatedAt)
	}
	window := original.Accounts[0].Snapshot.Windows[0]
	if window.RemainingPercent == nil || *window.RemainingPercent != 82 || window.ResetText == nil || *window.ResetText != "2h" {
		t.Fatalf("nested quota values were aliased: %#v", window)
	}
	if original.Accounts[0].Snapshot.Error == nil || *original.Accounts[0].Snapshot.Error != "cached error" {
		t.Fatalf("nested error was aliased: %#v", original.Accounts[0].Snapshot.Error)
	}
}

func TestRefreshPreservesCachedAccountsOnTopLevelFailure(t *testing.T) {
	now := time.Now().UTC()
	previous := Snapshot{SchemaVersion: SnapshotSchema, LastUpdatedAt: &now, Accounts: []AccountQuota{{Account: Account{ID: "id-1"}, Snapshot: QuotaSnapshot{Windows: []QuotaWindow{{ID: "5h"}}}}}}
	plugin := New(Host{Call: func(context.Context, string, []byte) ([]byte, error) { return nil, context.DeadlineExceeded }}, DefaultConfig())
	plugin.mu.Lock()
	plugin.snapshot = previous
	plugin.mu.Unlock()

	snapshot, err := plugin.Refresh(context.Background(), "")
	if err == nil {
		t.Fatal("Refresh() error = nil, want host callback error")
	}
	if len(snapshot.Accounts) != 1 || snapshot.Accounts[0].Account.ID != "id-1" {
		t.Fatalf("cached accounts were not preserved: %#v", snapshot.Accounts)
	}
	if snapshot.Error == nil || !strings.Contains(*snapshot.Error, "host auth callback") {
		t.Fatalf("top-level error = %#v", snapshot.Error)
	}
}

func TestManagementRoutesAndResource(t *testing.T) {
	registration := ManagementRegistration()
	if len(registration.Routes) != 2 || registration.Routes[0].Path != "/plugins/clipbar-quota/snapshot" || registration.Resources[0].Path != "/status" {
		t.Fatalf("unexpected management registration: %#v", registration)
	}
	plugin := New(Host{}, DefaultConfig())
	response, err := plugin.HandleManagement(context.Background(), ManagementRequest{Method: http.MethodGet, Path: "/v0/resource/plugins/clipbar-quota/status"})
	if err != nil || response.StatusCode != http.StatusOK || !strings.Contains(string(response.Body), "AccessDeck Quota") {
		t.Fatalf("resource response = %#v, err=%v", response, err)
	}
}

func TestMalformedQuotaAndEmptyPayload(t *testing.T) {
	plugin := New(Host{HTTP: &fakeHTTP{response: HTTPResponse{StatusCode: http.StatusOK, Body: []byte("not-json")}}}, DefaultConfig())
	quota, err := plugin.fetchQuota(context.Background(), "", "claude", HostAuthFile{}, map[string]any{"access_token": "placeholder-token"})
	if err == nil || quota.Error != nil || !strings.Contains(err.Error(), "invalid JSON") {
		t.Fatalf("malformed quota result = %#v, err=%v", quota, err)
	}
	empty := parseProviderSnapshot("codex", map[string]any{})
	if empty.Error == nil || *empty.Error != "empty quota payload" {
		t.Fatalf("empty quota snapshot = %#v", empty)
	}
}
