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
HELPERS_DIR := $(CONTENTS_DIR)/Helpers
# Universal build: each architecture is built separately and merged with lipo.
# The deployment target is forced via -Xswiftc because newer SDKs silently
# raise the manifest's .macOS(.v10_13) to their own minimum (e.g. 12.0).
ARM64_TRIPLE := arm64-apple-macosx11.0
X86_64_TRIPLE := x86_64-apple-macosx10.13
ARM64_BIN_DIR := .build/arm64-apple-macosx/$(CONFIGURATION)
X86_64_BIN_DIR := .build/x86_64-apple-macosx/$(CONFIGURATION)
SWIFT_BIN_DIR := $(BUILD_DIR)/universal-$(CONFIGURATION)
SPARKLE_FRAMEWORK := $(ARM64_BIN_DIR)/Sparkle.framework
# macOS < 10.14.4 has no Swift runtime in the OS; embed the toolchain's back-deployment copy.
SWIFT_BACKDEPLOY_LIBS := $(shell dirname "$$(xcrun --find swift)")/../lib/swift-5.0/macosx
INSTALLED_FRAMEWORKS_DIR := /Applications/Adrenaline.app/Contents/Frameworks
TEAM_ID ?= B65K228Z97
CODE_SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' '/B65K228Z97/ {print $$2; exit}')
INSTALL_APP_DIR ?= /Applications/Adrenaline.app
RELEASE_ZIP ?= $(BUILD_DIR)/Adrenaline.zip

.PHONY: test build generate-app-icon app sign migration-pkg release-zip reinstall run clean verify-helper-sections

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS) --build-system native --triple $(ARM64_TRIPLE) -Xswiftc -target -Xswiftc $(ARM64_TRIPLE)
	swift build $(SWIFT_BUILD_FLAGS) --build-system native --triple $(X86_64_TRIPLE) -Xswiftc -target -Xswiftc $(X86_64_TRIPLE)
	mkdir -p $(SWIFT_BIN_DIR)
	for product in Adrenaline AdrenalineHelper; do \
		lipo -create $(ARM64_BIN_DIR)/$$product $(X86_64_BIN_DIR)/$$product -output $(SWIFT_BIN_DIR)/$$product; \
	done

generate-app-icon:
	swift Scripts/generate-app-icon.swift Resources/Adrenaline/Adrenaline.icns

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(MACOS_DIR) $(FRAMEWORKS_DIR) $(LAUNCH_SERVICES_DIR) $(RESOURCES_DIR) $(HELPERS_DIR)
	cp Resources/Adrenaline/Info.plist $(CONTENTS_DIR)/Info.plist
	cp Resources/Adrenaline/Adrenaline.icns $(RESOURCES_DIR)/Adrenaline.icns
	cp $(SWIFT_BIN_DIR)/Adrenaline $(MACOS_DIR)/Adrenaline
	install_name_tool -add_rpath @executable_path/../Frameworks $(MACOS_DIR)/Adrenaline
	cp $(SWIFT_BIN_DIR)/AdrenalineHelper $(LAUNCH_SERVICES_DIR)/com.tonioriol.adrenaline.helper
	cp $(SWIFT_BIN_DIR)/AdrenalineCLI $(HELPERS_DIR)/adrenaline
	# The blessed helper runs from /Library/PrivilegedHelperTools, so it finds the
	# embedded Swift runtime through the installed app's Frameworks directory.
	install_name_tool -add_rpath $(INSTALLED_FRAMEWORKS_DIR) $(LAUNCH_SERVICES_DIR)/com.tonioriol.adrenaline.helper
	cp -R $(SPARKLE_FRAMEWORK) $(FRAMEWORKS_DIR)/Sparkle.framework
	xcrun swift-stdlib-tool --copy --platform macosx \
		--source-libraries "$(SWIFT_BACKDEPLOY_LIBS)" \
		--scan-executable $(MACOS_DIR)/Adrenaline \
		--scan-executable $(LAUNCH_SERVICES_DIR)/com.tonioriol.adrenaline.helper \
		--destination $(FRAMEWORKS_DIR)
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
	for dylib in "$(FRAMEWORKS_DIR)/"libswift*.dylib; do \
		[ -f "$$dylib" ] && codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$$dylib"; \
	done
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(LAUNCH_SERVICES_DIR)/com.tonioriol.adrenaline.helper"
	codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" "$(HELPERS_DIR)/adrenaline"
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
