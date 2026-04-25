SHELL := /bin/zsh
CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS := -c $(CONFIGURATION)
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/Cocaine.app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
LAUNCH_SERVICES_DIR := $(CONTENTS_DIR)/Library/LaunchServices
SWIFT_BIN_DIR := .build/$(CONFIGURATION)
CODE_SIGN_IDENTITY ?= -

.PHONY: test build app sign run clean verify-helper-sections

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS)

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(MACOS_DIR) $(LAUNCH_SERVICES_DIR)
	cp Resources/Cocaine/Info.plist $(CONTENTS_DIR)/Info.plist
	cp $(SWIFT_BIN_DIR)/Cocaine $(MACOS_DIR)/Cocaine
	cp $(SWIFT_BIN_DIR)/CocaineHelper $(LAUNCH_SERVICES_DIR)/com.tr0n.Cocaine.Helper
	$(MAKE) sign

sign:
	codesign --force --sign "$(CODE_SIGN_IDENTITY)" $(LAUNCH_SERVICES_DIR)/com.tr0n.Cocaine.Helper
	codesign --force --sign "$(CODE_SIGN_IDENTITY)" --deep $(APP_DIR)

verify-helper-sections:
	otool -s __TEXT __info_plist $(SWIFT_BIN_DIR)/CocaineHelper >/dev/null
	otool -s __TEXT __launchd_plist $(SWIFT_BIN_DIR)/CocaineHelper >/dev/null

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
