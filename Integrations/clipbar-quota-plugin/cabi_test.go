//go:build cgo && clipbar_cabi_test

package main

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func resetCABILifecycle(t *testing.T) {
	t.Helper()
	resetCABIHostState()
}

func callCABI(t *testing.T, plugin *cabiTestPlugin, method string, request []byte) (int, []byte) {
	t.Helper()
	return plugin.call(method, request)
}

func TestCABIInitUsesExactWrapperAndOwnsResponseBuffer(t *testing.T) {
	resetCABILifecycle(t)
	defer resetCABILifecycle(t)

	plugin, code := newCABIPlugin()
	if code != 0 {
		t.Fatalf("cliproxy_plugin_init() code = %d", code)
	}
	if !plugin.valid() {
		t.Fatalf("plugin API was not initialized")
	}

	code, raw := callCABI(t, plugin, "plugin.register", []byte(`{"schema_version":3,"config_yaml":"bWF4X2NvbmN1cnJlbmN5OiAy"}`))
	if code != 0 {
		t.Fatalf("plugin.register() code = %d, response = %s", code, raw)
	}
	var envelope struct {
		OK     bool            `json:"ok"`
		Result json.RawMessage `json:"result"`
	}
	if err := json.Unmarshal(raw, &envelope); err != nil {
		t.Fatalf("plugin.register() response is invalid JSON: %v", err)
	}
	if !envelope.OK || !strings.Contains(string(envelope.Result), `"schema_version":3`) {
		t.Fatalf("plugin.register() response = %s", raw)
	}

	if _, raw = callCABI(t, plugin, "unknown.method", nil); raw == nil || !strings.Contains(string(raw), `"unknown_method"`) {
		t.Fatalf("unknown method response = %s", raw)
	}
}

func TestCABIHostResponseIsFreedAfterCallbackFailure(t *testing.T) {
	resetCABILifecycle(t)
	defer resetCABILifecycle(t)

	plugin, code := newCABIPlugin()
	if code != 0 {
		t.Fatalf("cliproxy_plugin_init() code = %d", code)
	}
	setCABIHostMode(1)
	code, raw := callCABI(t, plugin, "management.handle", []byte(`{"Method":"POST","Path":"/v0/management/plugins/clipbar-quota/refresh"}`))
	if code != 0 {
		t.Fatalf("management.handle() code = %d, response = %s", code, raw)
	}
	if raw == nil || !strings.Contains(string(raw), `"StatusCode":502`) {
		t.Fatalf("host failure response = %s", raw)
	}
	if CABIHostFreeCount() != 1 {
		t.Fatalf("host response free count = %d, want 1", CABIHostFreeCount())
	}
}

func TestCABIShutdownWaitsForAnActiveCallBeforeClearingHostState(t *testing.T) {
	resetCABILifecycle(t)
	defer resetCABILifecycle(t)

	plugin, code := newCABIPlugin()
	if code != 0 {
		t.Fatalf("cliproxy_plugin_init() code = %d", code)
	}
	setCABIBlockingHost()

	callDone := make(chan struct{})
	go func() {
		_, _ = callCABI(t, plugin, "management.handle", []byte(`{"Method":"POST","Path":"/v0/management/plugins/clipbar-quota/refresh"}`))
		close(callDone)
	}()

	deadline := time.Now().Add(2 * time.Second)
	for !isCABIHostStarted() && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if !isCABIHostStarted() {
		t.Fatal("host callback did not start")
	}

	shutdownDone := make(chan struct{})
	go func() {
		clipbarPluginShutdown()
		close(shutdownDone)
	}()
	select {
	case <-shutdownDone:
		t.Fatal("shutdown returned while the host callback was blocked")
	case <-time.After(20 * time.Millisecond):
	}

	releaseCABIBlockingHost()
	select {
	case <-callDone:
	case <-time.After(2 * time.Second):
		t.Fatal("plugin call did not finish after releasing the host callback")
	}
	select {
	case <-shutdownDone:
	case <-time.After(2 * time.Second):
		t.Fatal("shutdown did not finish after the plugin call returned")
	}
	if runtimePlugin() == nil {
		t.Fatal("runtime plugin was not recreated after shutdown")
	}
}
