PLUGIN_ID := clipbar-quota
BIN_DIR := bin

UNAME_S := $(shell uname -s)

ifeq ($(OS),Windows_NT)
PLUGIN_EXT := dll
else ifeq ($(UNAME_S),Darwin)
PLUGIN_EXT := dylib
else
PLUGIN_EXT := so
endif

PLUGIN_PATH := $(BIN_DIR)/$(PLUGIN_ID).$(PLUGIN_EXT)

.PHONY: all build check test test-cabi fmt clean

all: check

# Development build only. This target intentionally does not use -trimpath,
# -ldflags release settings, packaging, signing, or publishing.
build: $(PLUGIN_PATH)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(PLUGIN_PATH): cabi.go cabi_export.c internal/clipbarquota/*.go go.mod | $(BIN_DIR)
	go build -buildmode=c-shared -o "$@" .
	rm -f "$(BIN_DIR)/$(PLUGIN_ID).h"

fmt:
	test -z "$$(gofmt -l *.go)"

gofmt:
	gofmt -w *.go

test:
	CGO_ENABLED=0 go test ./...

test-cabi:
	CGO_ENABLED=1 go test -tags clipbar_cabi_test .

check: fmt test

clean:
	rm -rf $(BIN_DIR)
