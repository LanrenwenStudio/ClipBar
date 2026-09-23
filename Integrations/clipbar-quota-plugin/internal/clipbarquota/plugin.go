package clipbarquota

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"gopkg.in/yaml.v3"
)

const (
	PluginID       = "clipbar-quota"
	ABIVersion     = 1
	SchemaVersion  = 3
	SnapshotSchema = 1
)

const (
	MethodPluginRegister     = "plugin.register"
	MethodPluginReconfigure  = "plugin.reconfigure"
	MethodPluginShutdown     = "plugin.shutdown"
	MethodManagementRegister = "management.register"
	MethodManagementHandle   = "management.handle"
	MethodHostAuthList       = "host.auth.list"
	MethodHostAuthGet        = "host.auth.get"
	MethodHostHTTPDo         = "host.http.do"
)

type Envelope struct {
	OK     bool            `json:"ok"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  *EnvelopeError  `json:"error,omitempty"`
}

type EnvelopeError struct {
	Code       string `json:"code"`
	Message    string `json:"message"`
	Retryable  bool   `json:"retryable,omitempty"`
	HTTPStatus int    `json:"http_status,omitempty"`
}

type HostCall func(context.Context, string, []byte) ([]byte, error)
type HostAuthFile struct {
	ID            string `json:"id,omitempty"`
	AuthIndex     string `json:"auth_index,omitempty"`
	Name          string `json:"name"`
	Type          string `json:"type,omitempty"`
	Provider      string `json:"provider,omitempty"`
	Label         string `json:"label,omitempty"`
	Status        string `json:"status,omitempty"`
	StatusMessage string `json:"status_message,omitempty"`
	Disabled      bool   `json:"disabled,omitempty"`
	Unavailable   bool   `json:"unavailable,omitempty"`
	RuntimeOnly   bool   `json:"runtime_only,omitempty"`
	Email         string `json:"email,omitempty"`
	ProjectID     string `json:"project_id,omitempty"`
}

type HostAuthListResponse struct {
	Files []HostAuthFile `json:"files"`
}

type HostAuthGetRequest struct {
	AuthIndex string `json:"auth_index"`
}

type HostAuthGetResponse struct {
	AuthIndex string          `json:"auth_index"`
	Name      string          `json:"name,omitempty"`
	JSON      json.RawMessage `json:"json"`
}

type HTTPRequest struct {
	HostCallbackID string              `json:"host_callback_id,omitempty"`
	Method         string              `json:"method,omitempty"`
	URL            string              `json:"url,omitempty"`
	Headers        map[string][]string `json:"headers,omitempty"`
	Body           []byte              `json:"body,omitempty"`
}

type HTTPResponse struct {
	StatusCode int                 `json:"status_code"`
	Headers    map[string][]string `json:"headers,omitempty"`
	Body       []byte              `json:"body,omitempty"`
}

type ManagementRequest struct {
	Method         string              `json:"Method,omitempty"`
	Path           string              `json:"Path,omitempty"`
	Headers        map[string][]string `json:"Headers,omitempty"`
	Query          url.Values          `json:"Query,omitempty"`
	Body           []byte              `json:"Body,omitempty"`
	HostCallbackID string              `json:"host_callback_id,omitempty"`
}

type ManagementResponse struct {
	StatusCode int                 `json:"StatusCode"`
	Headers    map[string][]string `json:"Headers"`
	Body       []byte              `json:"Body"`
}

type RegistrationPayload struct {
	SchemaVersion uint32       `json:"schema_version"`
	Metadata      Metadata     `json:"metadata"`
	Capabilities  Capabilities `json:"capabilities"`
}

type Metadata struct {
	Name             string        `json:"Name"`
	Version          string        `json:"Version"`
	Author           string        `json:"Author"`
	GitHubRepository string        `json:"GitHubRepository"`
	ConfigFields     []ConfigField `json:"ConfigFields"`
}

type ConfigField struct {
	Name        string `json:"Name"`
	Type        string `json:"Type"`
	Description string `json:"Description"`
}

type Capabilities struct {
	ManagementAPI bool `json:"management_api"`
}

type ManagementRegistrationPayload struct {
	Routes    []ManagementRoute `json:"routes,omitempty"`
	Resources []ResourceRoute   `json:"resources,omitempty"`
}

type ManagementRoute struct {
	Method      string `json:"Method"`
	Path        string `json:"Path"`
	Description string `json:"Description,omitempty"`
}

type ResourceRoute struct {
	Path        string `json:"Path"`
	Menu        string `json:"Menu"`
	Description string `json:"Description"`
}

type Config struct {
	RequestTimeoutSeconds int
	MaxConcurrency        int
}

func DefaultConfig() Config {
	return Config{RequestTimeoutSeconds: 30, MaxConcurrency: 8}
}

func ParseConfig(values map[string]any) Config {
	cfg := DefaultConfig()
	if n, ok := intValue(values["request_timeout_seconds"]); ok && n > 0 {
		cfg.RequestTimeoutSeconds = n
	}
	if n, ok := intValue(values["max_concurrency"]); ok && n > 0 {
		cfg.MaxConcurrency = n
	}
	return cfg
}

// ConfigFromYAML decodes the host-normalized plugin configuration sent with
// plugin.register and plugin.reconfigure. Unknown fields, including CPA's
// enabled and priority fields, are intentionally ignored here because CPA
// owns plugin activation and scheduling priority.
func ConfigFromYAML(raw []byte) (Config, error) {
	if len(strings.TrimSpace(string(raw))) == 0 {
		return DefaultConfig(), nil
	}
	var values map[string]any
	if err := yaml.Unmarshal(raw, &values); err != nil {
		return Config{}, err
	}
	if values == nil {
		return DefaultConfig(), nil
	}
	return ParseConfig(values), nil
}

type QuotaWindow struct {
	ID               string   `json:"id"`
	Label            string   `json:"label"`
	RemainingPercent *float64 `json:"remainingPercent"`
	ResetText        *string  `json:"resetText"`
}

type QuotaSnapshot struct {
	PlanType string        `json:"planType"`
	Windows  []QuotaWindow `json:"windows"`
	Error    *string       `json:"error"`
}

type Account struct {
	ID            string `json:"id"`
	AuthIndex     string `json:"authIndex"`
	Name          string `json:"name"`
	Email         string `json:"email"`
	Provider      string `json:"provider"`
	ProviderRaw   string `json:"providerRaw"`
	Status        string `json:"status"`
	StatusMessage string `json:"statusMessage"`
	Disabled      bool   `json:"disabled"`
	Unavailable   bool   `json:"unavailable"`
	AccountID     string `json:"accountID"`
	ProjectID     string `json:"projectID"`
	FileName      string `json:"fileName"`
}

type AccountQuota struct {
	Account  Account       `json:"account"`
	Snapshot QuotaSnapshot `json:"snapshot"`
}

type Snapshot struct {
	SchemaVersion int            `json:"schema_version"`
	LastUpdatedAt *time.Time     `json:"last_updated_at"`
	LastAttemptAt *time.Time     `json:"last_attempt_at"`
	Accounts      []AccountQuota `json:"accounts"`
	Error         *string        `json:"error"`
}

type HTTPBridge interface {
	Do(context.Context, HTTPRequest) (HTTPResponse, error)
}

type Host struct {
	Call HostCall
	HTTP HTTPBridge
}

type Plugin struct {
	mu       sync.RWMutex
	host     Host
	config   Config
	snapshot Snapshot
}

func New(host Host, config Config) *Plugin {
	return &Plugin{host: host, config: normalizeConfig(config), snapshot: Snapshot{SchemaVersion: SnapshotSchema, Accounts: []AccountQuota{}}}
}

func normalizeConfig(config Config) Config {
	defaults := DefaultConfig()
	if config.RequestTimeoutSeconds <= 0 {
		config.RequestTimeoutSeconds = defaults.RequestTimeoutSeconds
	}
	if config.MaxConcurrency <= 0 {
		config.MaxConcurrency = defaults.MaxConcurrency
	}
	return config
}

func (p *Plugin) Snapshot() Snapshot {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return cloneSnapshot(p.snapshot)
}

func (p *Plugin) Configure(values map[string]any) {
	p.ConfigureConfig(ParseConfig(values))
}

func (p *Plugin) ConfigureConfig(config Config) {
	p.mu.Lock()
	p.config = normalizeConfig(config)
	p.mu.Unlock()
}

func (p *Plugin) ConfigureYAML(raw []byte) error {
	config, err := ConfigFromYAML(raw)
	if err != nil {
		return err
	}
	p.ConfigureConfig(config)
	return nil
}

func (p *Plugin) SetHost(host Host) {
	p.mu.Lock()
	p.host = host
	p.mu.Unlock()
}

func Registration(schemaVersion ...uint32) RegistrationPayload {
	v := uint32(SchemaVersion)
	if len(schemaVersion) > 0 && schemaVersion[0] > 0 {
		v = schemaVersion[0]
	}
	return RegistrationPayload{
		SchemaVersion: v,
		Metadata: Metadata{
			Name:             PluginID,
			Version:          "0.1.0",
			Author:           "LanrenwenStudio",
			GitHubRepository: "https://github.com/LanrenwenStudio/AccessDeck",
			ConfigFields: []ConfigField{
				{Name: "request_timeout_seconds", Type: "integer", Description: "Timeout for one provider quota request."},
				{Name: "max_concurrency", Type: "integer", Description: "Maximum concurrent account refreshes."},
			},
		},
		Capabilities: Capabilities{ManagementAPI: true},
	}
}

func ManagementRegistration() ManagementRegistrationPayload {
	return ManagementRegistrationPayload{
		Routes: []ManagementRoute{
			{Method: http.MethodGet, Path: "/plugins/clipbar-quota/snapshot", Description: "Return the cached AccessDeck-compatible quota snapshot."},
			{Method: http.MethodPost, Path: "/plugins/clipbar-quota/refresh", Description: "Refresh supported auth entries through CPA host callbacks."},
		},
		Resources: []ResourceRoute{{Path: "/status", Menu: "AccessDeck Quota", Description: "Show the cached AccessDeck quota snapshot."}},
	}
}

func (p *Plugin) HandleManagement(ctx context.Context, req ManagementRequest) (ManagementResponse, error) {
	switch {
	case req.Method == http.MethodGet && strings.HasSuffix(req.Path, "/snapshot"):
		return jsonManagementResponse(http.StatusOK, p.Snapshot())
	case req.Method == http.MethodPost && strings.HasSuffix(req.Path, "/refresh"):
		snapshot, err := p.Refresh(ctx, req.HostCallbackID)
		if err != nil {
			return jsonManagementResponse(http.StatusBadGateway, map[string]any{"error": err.Error(), "snapshot": snapshot})
		}
		return jsonManagementResponse(http.StatusOK, snapshot)
	case req.Method == http.MethodGet && strings.HasSuffix(req.Path, "/status"):
		return htmlManagementResponse(http.StatusOK, renderStatus(p.Snapshot()))
	default:
		return jsonManagementResponse(http.StatusNotFound, map[string]string{"error": "unknown plugin route"})
	}
}

func (p *Plugin) Refresh(ctx context.Context, callbackID string) (Snapshot, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	p.mu.RLock()
	host := p.host
	cfg := p.config
	p.mu.RUnlock()
	if host.Call == nil || host.HTTP == nil {
		return p.recordFailure(errors.New("host auth callback or HTTP bridge is unavailable"))
	}
	listRaw, err := p.callHost(ctx, MethodHostAuthList, []byte(`{}`))
	if err != nil {
		return p.recordFailure(fmt.Errorf("%s: %w", MethodHostAuthList, err))
	}
	var listed HostAuthListResponse
	if err := decodeHostResult(listRaw, &listed); err != nil {
		return p.recordFailure(fmt.Errorf("decode %s: %w", MethodHostAuthList, err))
	}
	accounts := make([]AccountQuota, 0, len(listed.Files))
	sem := make(chan struct{}, cfg.MaxConcurrency)
	results := make(chan AccountQuota, len(listed.Files))
	var wg sync.WaitGroup
	for _, entry := range listed.Files {
		entry := entry
		provider, rawProvider := normalizeProvider(firstNonEmpty(entry.Provider, entry.Type))
		if provider == "unknown" || strings.TrimSpace(entry.AuthIndex) == "" || entry.Disabled || entry.Unavailable {
			continue
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			select {
			case sem <- struct{}{}:
			case <-ctx.Done():
				results <- accountWithError(entry, provider, rawProvider, ctx.Err())
				return
			}
			defer func() { <-sem }()
			account, err := p.refreshAccount(ctx, callbackID, entry, provider, rawProvider, cfg.RequestTimeoutSeconds)
			if err != nil {
				account = accountWithError(entry, provider, rawProvider, err)
			}
			results <- account
		}()
	}
	wg.Wait()
	close(results)
	for result := range results {
		accounts = append(accounts, result)
	}
	sort.SliceStable(accounts, func(i, j int) bool {
		if accounts[i].Account.Provider != accounts[j].Account.Provider {
			return accounts[i].Account.Provider < accounts[j].Account.Provider
		}
		return accounts[i].Account.Name < accounts[j].Account.Name
	})
	now := time.Now().UTC()
	snapshot := Snapshot{SchemaVersion: SnapshotSchema, LastUpdatedAt: &now, LastAttemptAt: &now, Accounts: accounts}
	p.mu.Lock()
	p.snapshot = snapshot
	p.mu.Unlock()
	return cloneSnapshot(snapshot), nil
}

func (p *Plugin) refreshAccount(ctx context.Context, callbackID string, entry HostAuthFile, provider, rawProvider string, timeoutSeconds int) (AccountQuota, error) {
	requestCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()
	payload, err := json.Marshal(HostAuthGetRequest{AuthIndex: entry.AuthIndex})
	if err != nil {
		return AccountQuota{}, err
	}
	raw, err := p.callHost(requestCtx, MethodHostAuthGet, payload)
	if err != nil {
		return AccountQuota{}, fmt.Errorf("%s: %w", MethodHostAuthGet, err)
	}
	var auth HostAuthGetResponse
	if err := decodeHostResult(raw, &auth); err != nil {
		return AccountQuota{}, fmt.Errorf("decode %s: %w", MethodHostAuthGet, err)
	}
	credentials, err := decodeAuthJSON(auth.JSON)
	if err != nil {
		return AccountQuota{}, err
	}
	quota, err := p.fetchQuota(requestCtx, callbackID, provider, entry, credentials)
	account := makeAccount(entry, provider, rawProvider, credentials)
	if err != nil {
		return AccountQuota{Account: account, Snapshot: QuotaSnapshot{Windows: []QuotaWindow{}, Error: stringPtr(err.Error())}}, nil
	}
	return AccountQuota{Account: account, Snapshot: quota}, nil
}

func (p *Plugin) fetchQuota(ctx context.Context, callbackID, provider string, entry HostAuthFile, auth map[string]any) (QuotaSnapshot, error) {
	token := firstString(auth, "access_token", "accessToken", "token")
	if token == "" {
		return QuotaSnapshot{Windows: []QuotaWindow{}}, errors.New("provider credential has no supported access token")
	}
	headers := map[string][]string{
		"Authorization": {"Bearer " + token},
		"Accept":        {"application/json"},
		"Content-Type":  {"application/json"},
		"User-Agent":    {"AccessDeck-CPA-Quota/0.1"},
	}
	var endpoint string
	method := http.MethodGet
	var body []byte
	switch provider {
	case "codex":
		accountID := chatGPTAccountID(auth)
		if accountID == "" {
			return QuotaSnapshot{Windows: []QuotaWindow{}}, errors.New("missing chatgpt account id")
		}
		endpoint = "https://chatgpt.com/backend-api/wham/usage"
		headers["Chatgpt-Account-Id"] = []string{accountID}
	case "claude":
		endpoint = "https://api.anthropic.com/api/oauth/usage"
		headers["anthropic-beta"] = []string{"oauth-2025-04-20"}
	case "kimi":
		endpoint = "https://api.kimi.com/coding/v1/usages"
		headers["X-Msh-Platform"] = []string{"CLIProxyAPI"}
	case "xai":
		endpoint = "https://cli-chat-proxy.grok.com/v1/billing"
		headers["x-xai-token-auth"] = []string{"xai-grok-cli"}
	case "gemini-cli", "antigravity":
		project := firstString(auth, "project_id", "projectId")
		if project == "" {
			return QuotaSnapshot{Windows: []QuotaWindow{}}, errors.New("missing Google project id")
		}
		method = http.MethodPost
		if provider == "gemini-cli" {
			endpoint = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
		} else {
			endpoint = "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary"
		}
		body, _ = json.Marshal(map[string]any{"project": project})
	default:
		return QuotaSnapshot{Windows: []QuotaWindow{}}, errors.New("unsupported provider")
	}
	request := HTTPRequest{HostCallbackID: callbackID, Method: method, URL: endpoint, Headers: headers, Body: body}
	response, err := p.hostHTTP(ctx, request)
	if err != nil {
		return QuotaSnapshot{Windows: []QuotaWindow{}}, err
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return QuotaSnapshot{Windows: []QuotaWindow{}}, fmt.Errorf("quota endpoint returned HTTP %d", response.StatusCode)
	}
	var object map[string]any
	if err := json.Unmarshal(response.Body, &object); err != nil {
		return QuotaSnapshot{Windows: []QuotaWindow{}}, errors.New("quota endpoint returned invalid JSON")
	}
	return parseProviderSnapshot(provider, object), nil
}

func (p *Plugin) callHost(ctx context.Context, method string, payload []byte) ([]byte, error) {
	p.mu.RLock()
	call := p.host.Call
	p.mu.RUnlock()
	if call == nil {
		return nil, errors.New("host callback is unavailable")
	}
	return call(ctx, method, payload)
}

func (p *Plugin) hostHTTP(ctx context.Context, request HTTPRequest) (HTTPResponse, error) {
	p.mu.RLock()
	bridge := p.host.HTTP
	p.mu.RUnlock()
	if bridge == nil {
		return HTTPResponse{}, errors.New("host HTTP bridge is unavailable")
	}
	return bridge.Do(ctx, request)
}

func (p *Plugin) recordFailure(err error) (Snapshot, error) {
	now := time.Now().UTC()
	message := err.Error()
	p.mu.Lock()
	p.snapshot.LastAttemptAt = &now
	p.snapshot.Error = &message
	snapshot := cloneSnapshot(p.snapshot)
	p.mu.Unlock()
	return snapshot, err
}

func parseProviderSnapshot(provider string, obj map[string]any) QuotaSnapshot {
	switch provider {
	case "codex":
		return parseCodex(obj)
	case "claude":
		return parseClaude(obj)
	case "gemini-cli":
		return parseGemini(obj)
	case "antigravity":
		return parseAntigravity(obj)
	case "kimi":
		return parseKimi(obj)
	case "xai":
		return parseXAI(obj)
	default:
		return QuotaSnapshot{Windows: []QuotaWindow{}, Error: stringPtr("unsupported provider")}
	}
}

func parseCodex(obj map[string]any) QuotaSnapshot {
	windows := []QuotaWindow{}
	if window := codexWindow("5h", "5h", obj, "rate_limit.primary_window"); window != nil {
		windows = append(windows, *window)
	}
	if window := codexWindow("7d", "Week", obj, "rate_limit.secondary_window"); window != nil {
		windows = append(windows, *window)
	}
	return snapshotWithWindows(firstString(obj, "plan_type", "planType", "account_plan.plan_type"), windows)
}

func codexWindow(id, label string, obj map[string]any, prefix string) *QuotaWindow {
	used, hasUsed := numberAt(obj, prefix+".used_percent")
	reset, hasReset := numberAt(obj, prefix+".reset_after_seconds")
	limit, hasLimit := numberAt(obj, prefix+".limit_window_seconds")
	if !hasUsed && !hasReset && !hasLimit {
		return nil
	}
	if hasLimit && limit >= 86400 {
		label = "Week"
	}
	window := QuotaWindow{ID: id, Label: label}
	if hasUsed {
		value := clamp(100 - used)
		window.RemainingPercent = &value
	}
	if hasReset {
		text := formatDuration(reset)
		window.ResetText = &text
	}
	return &window
}

func parseClaude(obj map[string]any) QuotaSnapshot {
	windows := []QuotaWindow{}
	if window := utilizationWindow("5h", "5h", firstNumber(obj, "five_hour.utilization", "five_hour.used_percentage", "rate_limits.five_hour.used_percentage"), firstString(obj, "five_hour.resets_at", "rate_limits.five_hour.resets_at")); window != nil {
		windows = append(windows, *window)
	}
	if window := utilizationWindow("7d", "Week", firstNumber(obj, "seven_day.utilization", "seven_day.used_percentage", "rate_limits.seven_day.used_percentage"), firstString(obj, "seven_day.resets_at", "rate_limits.seven_day.resets_at")); window != nil {
		windows = append(windows, *window)
	}
	return snapshotWithWindows("claude", windows)
}

func utilizationWindow(id, label string, used *float64, reset string) *QuotaWindow {
	if used == nil && reset == "" {
		return nil
	}
	window := QuotaWindow{ID: id, Label: label}
	if used != nil {
		value := clamp(100 - *used)
		window.RemainingPercent = &value
	}
	if reset != "" {
		text := formatReset(reset)
		window.ResetText = &text
	}
	return &window
}

func parseGemini(obj map[string]any) QuotaSnapshot {
	windows := []QuotaWindow{}
	buckets, _ := obj["buckets"].([]any)
	for _, raw := range buckets {
		bucket, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		id := firstString(bucket, "modelId", "model_id")
		if id == "" {
			id = "model"
		}
		remaining := remainingPercent(bucket)
		reset := formatReset(firstString(bucket, "resetTime", "reset_time"))
		windows = append(windows, QuotaWindow{ID: id, Label: shortModelName(id), RemainingPercent: remaining, ResetText: optionalString(reset)})
	}
	if len(windows) > 6 {
		sort.Slice(windows, func(i, j int) bool {
			return valueOr(windows[i].RemainingPercent, 999) < valueOr(windows[j].RemainingPercent, 999)
		})
		windows = windows[:6]
	}
	return snapshotWithWindows("", windows)
}

func parseAntigravity(obj map[string]any) QuotaSnapshot {
	windows := []QuotaWindow{}
	if groups, ok := obj["groups"].([]any); ok {
		if window := groupedGoogleWindow(groups, "5h", "5h", isFiveHour); window != nil {
			windows = append(windows, *window)
		}
		if window := groupedGoogleWindow(groups, "7d", "Week", isWeekly); window != nil {
			windows = append(windows, *window)
		}
	}
	if len(windows) == 0 {
		if models, ok := obj["models"].(map[string]any); ok {
			var values []float64
			var reset string
			for _, raw := range models {
				model, ok := raw.(map[string]any)
				if !ok {
					continue
				}
				quota, _ := model["quotaInfo"].(map[string]any)
				if quota == nil {
					quota, _ = model["quota_info"].(map[string]any)
				}
				if quota == nil {
					continue
				}
				if value := remainingPercent(quota); value != nil {
					values = append(values, *value)
				}
				if reset == "" {
					reset = formatReset(firstString(quota, "resetTime", "reset_time"))
				}
			}
			if len(values) > 0 {
				average := 0.0
				for _, value := range values {
					average += value
				}
				average /= float64(len(values))
				windows = append(windows, QuotaWindow{ID: "5h", Label: "5h", RemainingPercent: &average, ResetText: optionalString(reset)})
			}
		}
	}
	return snapshotWithWindows(parseGoogleAssistTier(obj), windows)
}

func groupedGoogleWindow(groups []any, id, label string, matcher func(string) bool) *QuotaWindow {
	var values []float64
	var reset string
	for _, rawGroup := range groups {
		group, ok := rawGroup.(map[string]any)
		if !ok {
			continue
		}
		buckets, _ := group["buckets"].([]any)
		for _, rawBucket := range buckets {
			bucket, ok := rawBucket.(map[string]any)
			if !ok || !matcher(firstString(bucket, "window")) {
				continue
			}
			if value := remainingPercent(bucket); value != nil {
				values = append(values, *value)
			}
			if reset == "" {
				reset = formatReset(firstString(bucket, "resetTime", "reset_time"))
			}
		}
	}
	if len(values) == 0 {
		return nil
	}
	average := 0.0
	for _, value := range values {
		average += value
	}
	average /= float64(len(values))
	return &QuotaWindow{ID: id, Label: label, RemainingPercent: &average, ResetText: optionalString(reset)}
}

func parseKimi(obj map[string]any) QuotaSnapshot {
	windows := []QuotaWindow{}
	if detail := kimiDetail(obj); detail != nil {
		if window := kimiQuotaWindow("7d", "Week", detail); window != nil {
			windows = append(windows, *window)
		}
	}
	return snapshotWithWindows(kimiPlan(obj), windows)
}

func parseXAI(obj map[string]any) QuotaSnapshot {
	config := obj
	if nested, ok := obj["config"].(map[string]any); ok {
		config = nested
	}
	windows := []QuotaWindow{}
	period, _ := config["currentPeriod"].(map[string]any)
	if period == nil {
		period, _ = config["current_period"].(map[string]any)
	}
	if used, ok := firstNumberValue(config, "creditUsagePercent", "credit_usage_percent"); ok || len(period) > 0 {
		value := clamp(100 - used)
		reset := formatReset(firstString(period, "end"))
		if reset == "" {
			reset = formatReset(firstString(config, "periodEnd", "period_end"))
		}
		windows = append(windows, QuotaWindow{ID: "week", Label: "Week", RemainingPercent: &value, ResetText: optionalString(reset)})
	}
	if products, ok := config["productUsage"].([]any); ok {
		for _, raw := range products {
			product, ok := raw.(map[string]any)
			if !ok {
				continue
			}
			name := firstNonEmpty(firstString(product, "product"), "Grok")
			if strings.EqualFold(strings.TrimSpace(name), "grokbuild") {
				continue
			}
			if productUsed, productOK := firstNumberValue(product, "usagePercent", "usage_percent"); productOK {
				value := clamp(100 - productUsed)
				windows = append(windows, QuotaWindow{ID: "product-" + name, Label: name, RemainingPercent: &value})
			}
		}
	}
	if limit, ok := xaiCents(config, "monthlyLimit", "monthly_limit"); ok && limit > 0 {
		if used, usedOK := xaiCents(config, "used"); usedOK {
			if used > limit {
				used = limit
			}
			value := clamp(100 - used/limit*100)
			reset := formatReset(firstString(config, "billingPeriodEnd", "billing_period_end"))
			windows = append(windows, QuotaWindow{ID: "month", Label: "Month", RemainingPercent: &value, ResetText: optionalString(reset)})
		}
	}
	return snapshotWithWindows(xaiPlan(config), windows)
}

func snapshotWithWindows(plan string, windows []QuotaWindow) QuotaSnapshot {
	snapshot := QuotaSnapshot{PlanType: plan, Windows: windows}
	if len(windows) == 0 {
		snapshot.Error = stringPtr("empty quota payload")
	}
	return snapshot
}

func makeAccount(entry HostAuthFile, provider, rawProvider string, auth map[string]any) Account {
	name := firstNonEmpty(entry.Name, entry.ID, entry.AuthIndex, "unknown")
	return Account{ID: firstNonEmpty(entry.ID, entry.AuthIndex, name), AuthIndex: entry.AuthIndex, Name: name, Email: firstNonEmpty(entry.Email, firstString(auth, "email")), Provider: provider, ProviderRaw: rawProvider, Status: firstNonEmpty(entry.Status, "unknown"), StatusMessage: entry.StatusMessage, Disabled: entry.Disabled, Unavailable: entry.Unavailable, AccountID: chatGPTAccountID(auth), ProjectID: firstNonEmpty(entry.ProjectID, firstString(auth, "project_id", "projectId")), FileName: entry.Name}
}

func accountWithError(entry HostAuthFile, provider, rawProvider string, err error) AccountQuota {
	message := err.Error()
	return AccountQuota{Account: makeAccount(entry, provider, rawProvider, nil), Snapshot: QuotaSnapshot{Windows: []QuotaWindow{}, Error: &message}}
}

func decodeAuthJSON(raw json.RawMessage) (map[string]any, error) {
	var object map[string]any
	if len(raw) == 0 || json.Unmarshal(raw, &object) != nil || object == nil {
		return nil, errors.New("host auth JSON is invalid")
	}
	return object, nil
}

func decodeHostResult(raw []byte, target any) error {
	var env Envelope
	if err := json.Unmarshal(raw, &env); err != nil {
		return err
	}
	if !env.OK {
		if env.Error != nil {
			return errors.New(env.Error.Message)
		}
		return errors.New("host callback failed")
	}
	return json.Unmarshal(env.Result, target)
}

func jsonManagementResponse(status int, value any) (ManagementResponse, error) {
	body, err := json.Marshal(value)
	if err != nil {
		return ManagementResponse{}, err
	}
	return ManagementResponse{StatusCode: status, Headers: map[string][]string{"content-type": {"application/json; charset=utf-8"}}, Body: body}, nil
}

func htmlManagementResponse(status int, body []byte) (ManagementResponse, error) {
	return ManagementResponse{StatusCode: status, Headers: map[string][]string{"content-type": {"text/html; charset=utf-8"}}, Body: body}, nil
}

func renderStatus(snapshot Snapshot) []byte {
	body, _ := json.Marshal(snapshot)
	return []byte("<!doctype html><meta charset=\"utf-8\"><title>AccessDeck Quota</title><h1>AccessDeck Quota</h1><pre>" + htmlEscape(string(body)) + "</pre>")
}

func htmlEscape(value string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", "\"", "&quot;", "'", "&#39;").Replace(value)
}

func normalizeProvider(raw string) (string, string) {
	raw = strings.TrimSpace(raw)
	switch strings.ToLower(raw) {
	case "codex", "openai", "chatgpt":
		return "codex", raw
	case "claude", "anthropic":
		return "claude", raw
	case "gemini", "gemini-cli", "aistudio":
		return "gemini-cli", raw
	case "antigravity":
		return "antigravity", raw
	case "kimi", "kimi-ai", "moonshot":
		return "kimi", raw
	case "xai", "x-ai", "grok":
		return "xai", raw
	default:
		return "unknown", raw
	}
}

func chatGPTAccountID(auth map[string]any) string {
	if id := firstString(auth, "account_id", "chatgpt_account_id", "metadata.account_id"); id != "" {
		return id
	}
	for _, key := range []string{"id_token", "access_token", "metadata.id_token", "metadata.access_token"} {
		if token := firstString(auth, key); token != "" {
			if id := jwtClaim(token, "chatgpt_account_id"); id != "" {
				return id
			}
		}
	}
	return ""
}

func jwtClaim(token, key string) string {
	parts := strings.Split(token, ".")
	if len(parts) < 2 {
		return ""
	}
	decoded, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		decoded, err = base64.URLEncoding.DecodeString(parts[1])
	}
	if err != nil {
		return ""
	}
	var object map[string]any
	if json.Unmarshal(decoded, &object) != nil {
		return ""
	}
	return firstString(object, key, "https://api.openai.com/auth."+key)
}

func firstString(obj map[string]any, paths ...string) string {
	for _, path := range paths {
		value := valueAt(obj, path)
		switch value := value.(type) {
		case string:
			if strings.TrimSpace(value) != "" {
				return strings.TrimSpace(value)
			}
		case float64:
			return strconv.FormatFloat(value, 'f', -1, 64)
		}
	}
	return ""
}
func firstNumber(obj map[string]any, paths ...string) *float64 {
	value, ok := firstNumberValue(obj, paths...)
	if !ok {
		return nil
	}
	return &value
}
func firstNumberValue(obj map[string]any, paths ...string) (float64, bool) {
	for _, path := range paths {
		if value, ok := numberAt(obj, path); ok {
			return value, true
		}
	}
	return 0, false
}
func numberAt(obj map[string]any, path string) (float64, bool) {
	value := valueAt(obj, path)
	switch value := value.(type) {
	case float64:
		return value, true
	case int:
		return float64(value), true
	case json.Number:
		n, err := value.Float64()
		return n, err == nil
	case string:
		n, err := strconv.ParseFloat(strings.TrimSpace(strings.TrimSuffix(value, "%")), 64)
		return n, err == nil
	}
	return 0, false
}
func valueAt(obj map[string]any, path string) any {
	var current any = obj
	for _, part := range strings.Split(path, ".") {
		nested, ok := current.(map[string]any)
		if !ok {
			return nil
		}
		current, ok = nested[part]
		if !ok {
			return nil
		}
	}
	return current
}
func intValue(value any) (int, bool) {
	switch value := value.(type) {
	case int:
		return value, true
	case float64:
		return int(value), true
	case string:
		n, err := strconv.Atoi(value)
		return n, err == nil
	}
	return 0, false
}
func remainingPercent(obj map[string]any) *float64 {
	for _, path := range []string{"remainingFraction", "remaining_fraction", "remaining"} {
		if value, ok := numberAt(obj, path); ok {
			if value <= 1.5 {
				value *= 100
			}
			value = clamp(value)
			return &value
		}
	}
	return nil
}
func clamp(value float64) float64 {
	if value < 0 {
		return 0
	}
	if value > 100 {
		return 100
	}
	return value
}
func formatDuration(seconds float64) string {
	total := int(seconds + 0.5)
	if total < 0 {
		total = 0
	}
	hours, remainder := total/3600, total%3600
	minutes := remainder / 60
	if hours >= 48 {
		return fmt.Sprintf("%dd %dh", hours/24, hours%24)
	}
	if hours > 0 {
		return fmt.Sprintf("%dh %dm", hours, minutes)
	}
	return fmt.Sprintf("%dm", minutes)
}
func formatReset(raw string) string {
	if raw == "" {
		return ""
	}
	parsed, err := time.Parse(time.RFC3339Nano, raw)
	if err != nil {
		return raw
	}
	return formatDuration(time.Until(parsed).Seconds())
}
func shortModelName(raw string) string {
	return strings.NewReplacer("gemini-", "", "-preview", "", "-thinking", "").Replace(raw)
}
func isFiveHour(raw string) bool {
	value := strings.ToLower(strings.ReplaceAll(strings.TrimSpace(raw), "_", "-"))
	return value == "5h" || value == "five-hour" || value == "fivehour" || strings.Contains(value, "5-hour")
}
func isWeekly(raw string) bool {
	value := strings.ToLower(strings.ReplaceAll(strings.TrimSpace(raw), "_", "-"))
	return value == "7d" || value == "7-day" || value == "7day" || value == "seven-day" || value == "sevenday" || value == "weekly" || value == "week" || strings.Contains(value, "7-day") || strings.Contains(value, "seven-day") || strings.Contains(value, "weekly")
}
func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}
func stringPtr(value string) *string { return &value }
func optionalString(value string) *string {
	if value == "" {
		return nil
	}
	return &value
}
func valueOr(value *float64, fallback float64) float64 {
	if value == nil {
		return fallback
	}
	return *value
}
func cloneSnapshot(snapshot Snapshot) Snapshot {
	clone := snapshot
	clone.LastUpdatedAt = cloneTime(snapshot.LastUpdatedAt)
	clone.LastAttemptAt = cloneTime(snapshot.LastAttemptAt)
	clone.Accounts = make([]AccountQuota, len(snapshot.Accounts))
	for index, account := range snapshot.Accounts {
		clone.Accounts[index] = account
		clone.Accounts[index].Snapshot = cloneQuotaSnapshot(account.Snapshot)
	}
	return clone
}

func cloneQuotaSnapshot(snapshot QuotaSnapshot) QuotaSnapshot {
	clone := snapshot
	clone.Windows = make([]QuotaWindow, len(snapshot.Windows))
	for index, window := range snapshot.Windows {
		clone.Windows[index] = window
		clone.Windows[index].RemainingPercent = cloneFloat(window.RemainingPercent)
		clone.Windows[index].ResetText = cloneString(window.ResetText)
	}
	clone.Error = cloneString(snapshot.Error)
	return clone
}

func cloneTime(value *time.Time) *time.Time {
	if value == nil {
		return nil
	}
	clone := *value
	return &clone
}

func cloneFloat(value *float64) *float64 {
	if value == nil {
		return nil
	}
	clone := *value
	return &clone
}

func cloneString(value *string) *string {
	if value == nil {
		return nil
	}
	clone := *value
	return &clone
}

func kimiDetail(obj map[string]any) map[string]any {
	if usage, ok := obj["usage"].(map[string]any); ok {
		if detail, ok := usage["detail"].(map[string]any); ok {
			return detail
		}
		return usage
	}
	if detail, ok := obj["detail"].(map[string]any); ok {
		return detail
	}
	if _, ok := obj["limit"]; ok {
		return obj
	}
	return nil
}
func kimiQuotaWindow(id, label string, detail map[string]any) *QuotaWindow {
	limit, ok := numberAt(detail, "limit")
	if !ok || limit <= 0 {
		return nil
	}
	value, ok := numberAt(detail, "remaining")
	if !ok {
		used, usedOK := numberAt(detail, "used")
		if !usedOK {
			return nil
		}
		value = limit - used
	}
	value = clamp(value / limit * 100)
	return &QuotaWindow{ID: id, Label: label, RemainingPercent: &value, ResetText: optionalString(formatReset(firstString(detail, "resetTime", "reset_time", "resetAt", "reset_at")))}
}
func kimiPlan(obj map[string]any) string {
	raw := firstString(obj, "user.membership.level", "user.membership.name", "membership.level", "membership.name", "plan_type", "planType", "plan", "subscription", "tier", "level")
	return strings.Title(strings.ReplaceAll(strings.ReplaceAll(strings.TrimPrefix(strings.TrimPrefix(strings.ToUpper(raw), "LEVEL_"), "PLAN_"), "_", " "), "-", " "))
}
func xaiCents(obj map[string]any, paths ...string) (float64, bool) {
	for _, path := range paths {
		value := valueAt(obj, path)
		if nested, ok := value.(map[string]any); ok {
			value = nested["val"]
		}
		switch value := value.(type) {
		case float64:
			return value, true
		case int:
			return float64(value), true
		case string:
			number, err := strconv.ParseFloat(strings.TrimSpace(value), 64)
			if err == nil {
				return number, true
			}
		}
	}
	return 0, false
}

func parseGoogleAssistTier(obj map[string]any) string {
	raw := firstString(obj, "currentTier.name", "currentTier.id", "paidTier.name", "paidTier.id")
	if raw == "" {
		return ""
	}
	normalized := strings.ToLower(strings.ReplaceAll(strings.ReplaceAll(strings.TrimSpace(raw), "_", "-"), " ", "-"))
	switch normalized {
	case "plus":
		return "Plus"
	case "pro":
		return "Pro"
	case "prolite", "pro-lite":
		return "Pro Lite"
	case "ultra", "antigravity-ultra":
		return "Ultra"
	case "free", "free-tier", "legacy", "legacy-tier":
		return "Free"
	case "standard":
		return "Standard"
	default:
		return strings.Title(strings.ReplaceAll(raw, "_", " "))
	}
}

func xaiPlan(obj map[string]any) string {
	if limit, ok := xaiCents(obj, "monthlyLimit", "monthly_limit"); ok {
		if limit == 15000 {
			return "SuperGrok"
		}
		if limit == 150000 {
			return "SuperGrok Heavy"
		}
	}
	raw := firstString(obj, "planType", "plan_type", "plan", "subscription", "product")
	return strings.Title(strings.ReplaceAll(raw, "_", " "))
}
