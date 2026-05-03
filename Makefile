SHELL := /bin/zsh
CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS := -c $(CONFIGURATION)
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/Adrenaline.app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
FRAMEWORKS_DIR := $(CONTENTS_DIR)/Frameworks
LAUNCH_SERVICES_DIR := $(CONTENTS_DIR)/Library/LaunchServices
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SWIFT_BIN_DIR := .build/$(CONFIGURATION)
SPARKLE_FRAMEWORK := $(SWIFT_BIN_DIR)/Sparkle.framework
TEAM_ID ?= B65K228Z97
CODE_SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' '/B65K228Z97/ {print $$2; exit}')
INSTALL_APP_DIR ?= /Applications/Adrenaline.app
RELEASE_ZIP ?= $(BUILD_DIR)/Adrenaline.zip

.PHONY: test build generate-app-icon app sign migration-pkg release-zip reinstall run clean verify-helper-sections

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS)

generate-app-icon:
	swift Scripts/generate-app-icon.swift Resources/Adrenaline/Adrenaline.icns

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(MACOS_DIR) $(FRAMEWORKS_DIR) $(LAUNCH_SERVICES_DIR) $(RESOURCES_DIR)
	cp Resources/Adrenaline/Info.plist $(CONTENTS_DIR)/Info.plist
	cp Resources/Adrenaline/Adrenaline.icns $(RESOURCES_DIR)/Adrenaline.icns
	cp $(SWIFT_BIN_DIR)/Adrenaline $(MACOS_DIR)/Adrenaline
	install_name_tool -add_rpath @executable_path/../Frameworks $(MACOS_DIR)/Adrenaline
	cp $(SWIFT_BIN_DIR)/AdrenalineHelper $(LAUNCH_SERVICES_DIR)/com.tonioriol.adrenaline.helper
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
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(LAUNCH_SERVICES_DIR)/com.tonioriol.adrenaline.helper"
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(APP_DIR)"

migration-pkg: app
	./Scripts/migration/build-migration-pkg.sh $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Adrenaline/Info.plist) "$(CODE_SIGN_IDENTITY)"

release-zip: app
	rm -f "$(RELEASE_ZIP)"
	ditto -c -k --keepParent "$(APP_DIR)" "$(RELEASE_ZIP)"

reinstall: app
	@if pgrep -f "$(INSTALL_APP_DIR)/Contents/MacOS/Adrenaline" >/dev/null; then \
		pkill -f "$(INSTALL_APP_DIR)/Contents/MacOS/Adrenaline"; \
		sleep 1; \
	fi
	rm -rf "$(INSTALL_APP_DIR)"
	cp -R "$(APP_DIR)" "$(INSTALL_APP_DIR)"
	open "$(INSTALL_APP_DIR)"

verify-helper-sections:
	otool -s __TEXT __info_plist $(SWIFT_BIN_DIR)/AdrenalineHelper >/dev/null
	otool -s __TEXT __launchd_plist $(SWIFT_BIN_DIR)/AdrenalineHelper >/dev/null

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
