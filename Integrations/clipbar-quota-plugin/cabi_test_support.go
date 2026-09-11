//go:build cgo && clipbar_cabi_test

package main

/*
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
	void* ptr;
	size_t len;
} cliproxy_test_buffer;

typedef int (*cliproxy_test_host_call_fn)(void*, const char*, const uint8_t*, size_t, cliproxy_test_buffer*);
typedef void (*cliproxy_test_host_free_fn)(void*, size_t);

typedef struct {
	uint32_t abi_version;
	void* host_ctx;
	cliproxy_test_host_call_fn call;
	cliproxy_test_host_free_fn free_buffer;
} cliproxy_test_host_api;

typedef int (*cliproxy_test_plugin_call_fn)(const char*, const uint8_t*, size_t, cliproxy_test_buffer*);
typedef void (*cliproxy_test_plugin_free_fn)(void*, size_t);
typedef void (*cliproxy_test_plugin_shutdown_fn)(void);

typedef struct {
	uint32_t abi_version;
	cliproxy_test_plugin_call_fn call;
	cliproxy_test_plugin_free_fn free_buffer;
	cliproxy_test_plugin_shutdown_fn shutdown;
} cliproxy_test_plugin_api;

extern int cliproxy_plugin_init(const cliproxy_test_host_api*, cliproxy_test_plugin_api*);

static volatile int test_block_host;
static volatile int test_host_started;
static volatile int test_release_host;
static volatile int test_host_mode;
static volatile int test_host_free_count;

static int test_load(volatile int* value) {
	return __atomic_load_n(value, __ATOMIC_SEQ_CST);
}

static void test_store(volatile int* value, int next) {
	__atomic_store_n(value, next, __ATOMIC_SEQ_CST);
}

static void test_reset_host(void) {
	test_store(&test_block_host, 0);
	test_store(&test_host_started, 0);
	test_store(&test_release_host, 0);
	test_store(&test_host_mode, 0);
	test_store(&test_host_free_count, 0);
}

static void test_set_blocking_host(void) {
	test_store(&test_block_host, 1);
	test_store(&test_host_started, 0);
	test_store(&test_release_host, 0);
}

static void test_release_blocking_host(void) {
	test_store(&test_release_host, 1);
}

static int test_is_host_started(void) {
	return test_load(&test_host_started);
}

static void test_set_host_mode(int mode) {
	test_store(&test_host_mode, mode);
}

static int test_get_host_free_count(void) {
	return test_load(&test_host_free_count);
}

static void test_write_response(cliproxy_test_buffer* response, const char* body) {
	if (response == NULL) {
		return;
	}
	size_t length = strlen(body);
	response->ptr = malloc(length);
	response->len = length;
	if (response->ptr != NULL) {
		memcpy(response->ptr, body, length);
	} else {
		response->len = 0;
	}
}

static int test_host_call(void* context, const char* method, const uint8_t* request, size_t request_len, cliproxy_test_buffer* response) {
	(void)context;
	(void)method;
	(void)request;
	(void)request_len;
	if (test_load(&test_block_host) != 0) {
		test_store(&test_host_started, 1);
		while (test_load(&test_release_host) == 0) {
		}
	}
	if (test_load(&test_host_mode) == 1) {
		test_write_response(response, "{\"ok\":false,\"error\":{\"code\":\"host_failure\",\"message\":\"host unavailable\"}}");
		return 1;
	}
	test_write_response(response, "{\"ok\":true,\"result\":{\"files\":[]}}");
	return 0;
}

static void test_host_free(void* ptr, size_t length) {
	(void)length;
	test_store(&test_host_free_count, test_load(&test_host_free_count) + 1);
	free(ptr);
}

static int test_init_plugin(cliproxy_test_plugin_api* plugin) {
	cliproxy_test_host_api host = {
		.abi_version = 1,
		.host_ctx = NULL,
		.call = test_host_call,
		.free_buffer = test_host_free,
	};
	return cliproxy_plugin_init(&host, plugin);
}

static int test_call_plugin(cliproxy_test_plugin_api* plugin, const char* method, const uint8_t* request, size_t request_len, cliproxy_test_buffer* response) {
	return plugin->call(method, request, request_len, response);
}

static void test_free_plugin_response(cliproxy_test_plugin_api* plugin, cliproxy_test_buffer* response) {
	if (plugin == NULL || response == NULL || response->ptr == NULL) {
		return;
	}
	plugin->free_buffer(response->ptr, response->len);
	response->ptr = NULL;
	response->len = 0;
}
*/
import "C"

import (
	"unsafe"
)

type cabiTestPlugin struct {
	api C.cliproxy_test_plugin_api
}

func resetCABIHostState() {
	C.test_reset_host()
	clipbarPluginShutdown()
}

func newCABIPlugin() (*cabiTestPlugin, int) {
	var api C.cliproxy_test_plugin_api
	code := C.test_init_plugin(&api)
	return &cabiTestPlugin{api: api}, int(code)
}

func (plugin *cabiTestPlugin) valid() bool {
	return plugin != nil && plugin.api.abi_version == 1 && plugin.api.call != nil && plugin.api.free_buffer != nil && plugin.api.shutdown != nil
}

func (plugin *cabiTestPlugin) call(method string, request []byte) (int, []byte) {
	cMethod := C.CString(method)
	defer C.free(unsafe.Pointer(cMethod))

	var requestPtr *C.uint8_t
	if len(request) > 0 {
		ptr := C.CBytes(request)
		defer C.free(ptr)
		requestPtr = (*C.uint8_t)(ptr)
	}

	var response C.cliproxy_test_buffer
	code := C.test_call_plugin(
		&plugin.api,
		cMethod,
		requestPtr,
		C.size_t(len(request)),
		&response,
	)
	defer C.test_free_plugin_response(&plugin.api, &response)
	if response.ptr == nil || response.len == 0 {
		return int(code), nil
	}
	return int(code), C.GoBytes(response.ptr, C.int(response.len))
}

func setCABIHostMode(mode int) {
	C.test_set_host_mode(C.int(mode))
}

func setCABIBlockingHost() {
	C.test_set_blocking_host()
}

func releaseCABIBlockingHost() {
	C.test_release_blocking_host()
}

func isCABIHostStarted() bool {
	return C.test_is_host_started() != 0
}

func CABIHostFreeCount() int {
	return int(C.test_get_host_free_count())
}
