#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define CLIPROXY_EXPORT __declspec(dllexport)
#else
#define CLIPROXY_EXPORT __attribute__((visibility("default")))
#endif

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

extern int clipbarPluginInit(cliproxy_host_api*, cliproxy_plugin_api*);

// Keep the exported CPA entry point in a standalone C translation unit. cgo
// copies the preamble of files containing //export directives into multiple
// generated objects, so defining this non-static symbol in a Go preamble
// causes duplicate-symbol linker errors.
CLIPROXY_EXPORT int cliproxy_plugin_init(const cliproxy_host_api* host, cliproxy_plugin_api* plugin) {
	return clipbarPluginInit((cliproxy_host_api*)host, plugin);
}
