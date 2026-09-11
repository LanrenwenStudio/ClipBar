package main

/*
#include <stdint.h>
#include <stdlib.h>

typedef struct {
	void* ptr;
	size_t len;
} cliproxy_buffer;

typedef int (*cliproxy_host_call_fn)(void*, const char*, const uint8_t*, size_t, cliproxy_buffer*);
typedef void (*cliproxy_host_free_fn)(void*, size_t);

typedef struct {
	uint32_t abi_version;
	void* host_ctx;
	cliproxy_host_call_fn call;
	cliproxy_host_free_fn free_buffer;
} cliproxy_host_api;

typedef int (*cliproxy_plugin_call_fn)(const char*, const uint8_t*, size_t, cliproxy_buffer*);
typedef void (*cliproxy_plugin_free_fn)(void*, size_t);
typedef void (*cliproxy_plugin_shutdown_fn)(void);

typedef struct {
	uint32_t abi_version;
	cliproxy_plugin_call_fn call;
	cliproxy_plugin_free_fn free_buffer;
	cliproxy_plugin_shutdown_fn shutdown;
} cliproxy_plugin_api;

extern int clipbarPluginCall(char*, uint8_t*, size_t, cliproxy_buffer*);
extern int clipbarPluginInit(cliproxy_host_api*, cliproxy_plugin_api*);
extern void clipbarPluginFree(void*, size_t);
extern void clipbarPluginShutdown(void);

// cgo cannot use const-qualified pointer parameters in //export declarations
// and also expose them as CPA's function-pointer types without conflicting
// declarations. Keep the Go exports cgo-compatible and make the exact native
// ABI visible through C adapters at this boundary.
static int clipbarPluginCallAdapter(const char* method, const uint8_t* request, size_t request_len, cliproxy_buffer* response) {
	return clipbarPluginCall((char*)method, (uint8_t*)request, request_len, response);
}

static void initialize_plugin_api(cliproxy_plugin_api* plugin) {
	if (plugin == NULL) {
		return;
	}
	plugin->abi_version = 1;
	plugin->call = (cliproxy_plugin_call_fn)clipbarPluginCallAdapter;
	plugin->free_buffer = (cliproxy_plugin_free_fn)clipbarPluginFree;
	plugin->shutdown = (cliproxy_plugin_shutdown_fn)clipbarPluginShutdown;
}

// CPA owns the host callback context and the allocated host API structure.
// Copy the callback table into plugin-owned storage, then guard the complete
// exported plugin call. The host callback context is borrowed only for the
// duration of call_host_api; this plugin never frees it or retains it after
// shutdown.
//
// CPA's guarded client must keep its callback-registry entry and native host
// allocations alive until the underlying plugin call has returned. The local
// active count protects direct calls and plugin-owned shutdown overlap, but it
// cannot extend CPA's lifetime or make cancellation interrupt a native call.
static cliproxy_host_api stored_host;
static volatile int stored_host_valid;
static volatile int stored_host_shutting_down;
static volatile int stored_plugin_calls;
static volatile int stored_host_lock;

static void lock_host_state(void) {
	while (!__sync_bool_compare_and_swap(&stored_host_lock, 0, 1)) {
	}
}

static void unlock_host_state(void) {
	__sync_lock_release(&stored_host_lock);
}

static void store_host_api(const cliproxy_host_api* host) {
	if (host == NULL) {
		return;
	}
	lock_host_state();
	stored_host = *host;
	stored_host_shutting_down = 0;
	stored_host_valid = 1;
	unlock_host_state();
}

static int begin_plugin_call(void) {
	int accepted = 0;
	lock_host_state();
	if (stored_host_valid != 0 && stored_host_shutting_down == 0) {
		stored_plugin_calls++;
		accepted = 1;
	}
	unlock_host_state();
	return accepted;
}

static void end_plugin_call(void) {
	lock_host_state();
	stored_plugin_calls--;
	unlock_host_state();
}

static int call_host_api(const char* method, const uint8_t* request, size_t request_len, cliproxy_buffer* response) {
	cliproxy_host_call_fn call;
	void* host_ctx;
	lock_host_state();
	if (stored_host_valid == 0 || stored_host_shutting_down != 0 || stored_host.call == NULL) {
		unlock_host_state();
		return 1;
	}
	call = stored_host.call;
	host_ctx = stored_host.host_ctx;
	unlock_host_state();
	return call(host_ctx, method, request, request_len, response);
}

static void free_host_buffer(void* ptr, size_t len) {
	cliproxy_host_free_fn free_buffer;
	if (ptr == NULL) {
		return;
	}
	lock_host_state();
	// An active plugin call may still be releasing a response after shutdown
	// has invalidated new host calls. Keep using the copied free callback until
	// begin_host_shutdown has drained stored_plugin_calls; otherwise a response
	// allocated by CPA would leak during a shutdown race.
	if (stored_host.free_buffer == NULL) {
		unlock_host_state();
		return;
	}
	free_buffer = stored_host.free_buffer;
	unlock_host_state();
	free_buffer(ptr, len);
}

static void begin_host_shutdown(void) {
	lock_host_state();
	stored_host_shutting_down = 1;
	stored_host_valid = 0;
	while (stored_plugin_calls != 0) {
		unlock_host_state();
		lock_host_state();
	}
	stored_host.call = NULL;
	stored_host.free_buffer = NULL;
	stored_host.host_ctx = NULL;
	unlock_host_state();
}

static void clear_host_callbacks(void) {
	lock_host_state();
	stored_host.call = NULL;
	stored_host.free_buffer = NULL;
	stored_host.host_ctx = NULL;
	stored_host_valid = 0;
	unlock_host_state();
}

static void reset_host_state(void) {
	lock_host_state();
	stored_host = (cliproxy_host_api){0};
	stored_host_shutting_down = 0;
	stored_plugin_calls = 0;
	stored_host_valid = 0;
	unlock_host_state();
}
*/
import "C"

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"unsafe"

	clipbarquota "github.com/LanrenwenStudio/AccessDeck/Integrations/clipbar-quota-plugin/internal/clipbarquota"
)

func main() {}

//export clipbarPluginInit
func clipbarPluginInit(host *C.cliproxy_host_api, plugin *C.cliproxy_plugin_api) C.int {
	if plugin == nil || host == nil || host.abi_version != C.uint32_t(clipbarquota.ABIVersion) {
		return 1
	}
	C.store_host_api(host)
	C.initialize_plugin_api(plugin)
	return 0
}

//export clipbarPluginCall
func clipbarPluginCall(method *C.char, request *C.uint8_t, requestLen C.size_t, response *C.cliproxy_buffer) C.int {
	// Always initialize the caller-owned output buffer, including when the
	// plugin is already shutting down and the call is rejected.
	if response != nil {
		response.ptr = nil
		response.len = 0
	}
	if C.begin_plugin_call() == 0 {
		return 1
	}
	defer C.end_plugin_call()
	if method == nil {
		writeResponse(response, envelopeError("invalid_method", "method is required"))
		return 1
	}
	requestBytes := []byte(nil)
	if request != nil && requestLen > 0 {
		requestBytes = C.GoBytes(unsafe.Pointer(request), C.int(requestLen))
	}
	result, err := handleMethod(C.GoString(method), requestBytes)
	if err != nil {
		writeResponse(response, envelopeError("plugin_error", err.Error()))
		return 1
	}
	writeResponse(response, result)
	return 0
}

//export clipbarPluginFree
func clipbarPluginFree(ptr unsafe.Pointer, length C.size_t) {
	if ptr != nil {
		C.free(ptr)
	}
	_ = length
}

//export clipbarPluginShutdown
func clipbarPluginShutdown() {
	C.begin_host_shutdown()
	runtime.mu.Lock()
	runtime.plugin = nil
	runtime.mu.Unlock()
	C.clear_host_callbacks()
	C.reset_host_state()
}

type lifecycleRequest struct {
	ConfigYAML    []byte `json:"config_yaml"`
	SchemaVersion uint32 `json:"schema_version"`
}

func handleMethod(method string, request []byte) ([]byte, error) {
	switch method {
	case clipbarquota.MethodPluginRegister, clipbarquota.MethodPluginReconfigure:
		if err := configureRuntime(request); err != nil {
			return nil, err
		}
		return okEnvelope(clipbarquota.Registration())
	case clipbarquota.MethodPluginShutdown:
		return okEnvelope(map[string]any{})
	case clipbarquota.MethodManagementRegister:
		return okEnvelope(clipbarquota.ManagementRegistration())
	case clipbarquota.MethodManagementHandle:
		return handleManagement(request)
	default:
		return envelopeError("unknown_method", "unknown method: "+method), nil
	}
}

func configureRuntime(raw []byte) error {
	var request lifecycleRequest
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &request); err != nil {
			return fmt.Errorf("decode lifecycle request: %w", err)
		}
	}
	if request.SchemaVersion > uint32(clipbarquota.SchemaVersion) {
		return fmt.Errorf("unsupported plugin schema version %d", request.SchemaVersion)
	}
	plugin := runtimePlugin()
	if err := plugin.ConfigureYAML(request.ConfigYAML); err != nil {
		return fmt.Errorf("configure plugin: %w", err)
	}
	return nil
}

var runtime = struct {
	mu     sync.Mutex
	plugin *clipbarquota.Plugin
}{}

func runtimePlugin() *clipbarquota.Plugin {
	runtime.mu.Lock()
	defer runtime.mu.Unlock()
	if runtime.plugin == nil {
		runtime.plugin = newRuntimePlugin()
	}
	return runtime.plugin
}

func handleManagement(raw []byte) ([]byte, error) {
	var request clipbarquota.ManagementRequest
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &request); err != nil {
			return nil, fmt.Errorf("decode management request: %w", err)
		}
	}
	response, err := runtimePlugin().HandleManagement(context.Background(), request)
	if err != nil {
		return nil, err
	}
	return okEnvelope(response)
}

func newRuntimePlugin() *clipbarquota.Plugin {
	return clipbarquota.New(clipbarquota.Host{
		Call: func(ctx context.Context, method string, request []byte) ([]byte, error) {
			return callHost(ctx, method, request)
		},
		HTTP: hostHTTPBridge{},
	}, clipbarquota.DefaultConfig())
}

type hostHTTPBridge struct{}

func (hostHTTPBridge) Do(ctx context.Context, request clipbarquota.HTTPRequest) (clipbarquota.HTTPResponse, error) {
	payload, err := json.Marshal(request)
	if err != nil {
		return clipbarquota.HTTPResponse{}, err
	}
	raw, err := callHost(ctx, clipbarquota.MethodHostHTTPDo, payload)
	if err != nil {
		return clipbarquota.HTTPResponse{}, err
	}
	var response clipbarquota.HTTPResponse
	if err := decodeHostResult(raw, &response); err != nil {
		return clipbarquota.HTTPResponse{}, fmt.Errorf("decode %s: %w", clipbarquota.MethodHostHTTPDo, err)
	}
	return response, nil
}

func callHost(ctx context.Context, method string, request []byte) ([]byte, error) {
	cMethod := C.CString(method)
	defer C.free(unsafe.Pointer(cMethod))
	var response C.cliproxy_buffer
	var requestPtr *C.uint8_t
	if len(request) > 0 {
		ptr := C.CBytes(request)
		if ptr == nil {
			return nil, fmt.Errorf("allocate host request %s", method)
		}
		defer C.free(ptr)
		requestPtr = (*C.uint8_t)(ptr)
	}
	code := C.call_host_api(cMethod, requestPtr, C.size_t(len(request)), &response)
	defer func() {
		if response.ptr != nil {
			C.free_host_buffer(response.ptr, response.len)
		}
	}()
	if response.ptr == nil || response.len == 0 {
		return nil, fmt.Errorf("host callback %s returned no response, code=%d", method, int(code))
	}
	raw := C.GoBytes(response.ptr, C.int(response.len))
	if code != 0 {
		return nil, fmt.Errorf("host callback %s returned code=%d", method, int(code))
	}
	return raw, nil
}

type rpcEnvelope struct {
	OK     bool            `json:"ok"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func decodeHostResult(raw []byte, target any) error {
	var envelope rpcEnvelope
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return err
	}
	if !envelope.OK {
		if envelope.Error != nil {
			return fmt.Errorf("%s: %s", envelope.Error.Code, envelope.Error.Message)
		}
		return fmt.Errorf("host callback failed")
	}
	return json.Unmarshal(envelope.Result, target)
}

func okEnvelope(value any) ([]byte, error) {
	result, err := json.Marshal(value)
	if err != nil {
		return nil, err
	}
	return json.Marshal(rpcEnvelope{OK: true, Result: result})
}

func envelopeError(code, message string) []byte {
	raw, _ := json.Marshal(rpcEnvelope{OK: false, Error: &rpcError{Code: code, Message: message}})
	return raw
}

func writeResponse(response *C.cliproxy_buffer, raw []byte) {
	if response == nil || len(raw) == 0 {
		return
	}
	ptr := C.CBytes(raw)
	if ptr == nil {
		return
	}
	response.ptr = ptr
	response.len = C.size_t(len(raw))
}
