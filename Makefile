SHELL := /bin/zsh
CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS := -c $(CONFIGURATION)

.PHONY: test build clean

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build build
