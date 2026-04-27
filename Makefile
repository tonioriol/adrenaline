SHELL := /bin/zsh
CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS := -c $(CONFIGURATION)
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/Insomnia.app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
FRAMEWORKS_DIR := $(CONTENTS_DIR)/Frameworks
LAUNCH_SERVICES_DIR := $(CONTENTS_DIR)/Library/LaunchServices
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SWIFT_BIN_DIR := .build/$(CONFIGURATION)
SPARKLE_FRAMEWORK := $(SWIFT_BIN_DIR)/Sparkle.framework
TEAM_ID ?= B65K228Z97
CODE_SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' '/B65K228Z97/ {print $$2; exit}')
INSTALL_APP_DIR ?= /Applications/Insomnia.app
RELEASE_ZIP ?= $(BUILD_DIR)/Insomnia.zip

.PHONY: test build generate-app-icon app sign release-zip reinstall run clean verify-helper-sections

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS)

generate-app-icon:
	swift Scripts/generate-app-icon.swift Resources/Insomnia/Insomnia.icns

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(MACOS_DIR) $(FRAMEWORKS_DIR) $(LAUNCH_SERVICES_DIR) $(RESOURCES_DIR)
	cp Resources/Insomnia/Info.plist $(CONTENTS_DIR)/Info.plist
	cp Resources/Insomnia/Insomnia.icns $(RESOURCES_DIR)/Insomnia.icns
	cp $(SWIFT_BIN_DIR)/Insomnia $(MACOS_DIR)/Insomnia
	install_name_tool -add_rpath @executable_path/../Frameworks $(MACOS_DIR)/Insomnia
	cp $(SWIFT_BIN_DIR)/InsomniaHelper $(LAUNCH_SERVICES_DIR)/com.tonioriol.insomnia.helper
	cp -R $(SPARKLE_FRAMEWORK) $(FRAMEWORKS_DIR)/Sparkle.framework
	$(MAKE) sign

sign:
	@if [ -z "$(CODE_SIGN_IDENTITY)" ]; then \
		echo "No Apple Development codesigning identity found for Team ID $(TEAM_ID)"; \
		exit 1; \
	fi
	# Sign inside-out: Sparkle nested components → framework → helper → app
	for xpc in "$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/XPCServices/"*.xpc; do \
		[ -d "$$xpc" ] && codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$$xpc"; \
	done
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/Autoupdate"
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/Updater.app"
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(FRAMEWORKS_DIR)/Sparkle.framework"
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(LAUNCH_SERVICES_DIR)/com.tonioriol.insomnia.helper"
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(APP_DIR)"

release-zip: app
	rm -f "$(RELEASE_ZIP)"
	ditto -c -k --keepParent "$(APP_DIR)" "$(RELEASE_ZIP)"

reinstall: app
	@if pgrep -f "$(INSTALL_APP_DIR)/Contents/MacOS/Insomnia" >/dev/null; then \
		pkill -f "$(INSTALL_APP_DIR)/Contents/MacOS/Insomnia"; \
		sleep 1; \
	fi
	rm -rf "$(INSTALL_APP_DIR)"
	cp -R "$(APP_DIR)" "$(INSTALL_APP_DIR)"
	open "$(INSTALL_APP_DIR)"

verify-helper-sections:
	otool -s __TEXT __info_plist $(SWIFT_BIN_DIR)/InsomniaHelper >/dev/null
	otool -s __TEXT __launchd_plist $(SWIFT_BIN_DIR)/InsomniaHelper >/dev/null

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
