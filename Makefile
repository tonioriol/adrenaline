SHELL := /bin/zsh
CONFIGURATION ?= debug
# Universal build. The deployment target comes from Package.swift (.macOS(.v10_13));
# SDKs that can't deploy that far back (Xcode 26+) raise it to their own minimum,
# so release builds for macOS 10.13 come from CI on Xcode 16.4.
SWIFT_BUILD_FLAGS := -c $(CONFIGURATION) --arch arm64 --arch x86_64
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/Adrenaline.app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
FRAMEWORKS_DIR := $(CONTENTS_DIR)/Frameworks
LAUNCH_SERVICES_DIR := $(CONTENTS_DIR)/Library/LaunchServices
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
HELPERS_DIR := $(CONTENTS_DIR)/Helpers
# The products directory differs between toolchains, so ask SwiftPM for it.
SWIFT_BIN_DIR := $(shell swift build $(SWIFT_BUILD_FLAGS) --show-bin-path)
SPARKLE_FRAMEWORK := $(SWIFT_BIN_DIR)/Sparkle.framework
# macOS < 10.14.4 has no Swift runtime in the OS; embed the toolchain's back-deployment copy.
SWIFT_BACKDEPLOY_LIBS := $(shell dirname "$$(xcrun --find swift)")/../lib/swift-5.0/macosx
TEAM_ID ?= B65K228Z97
CODE_SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' '/B65K228Z97/ {print $$2; exit}')
INSTALL_APP_DIR ?= /Applications/Adrenaline.app
RELEASE_ZIP ?= $(BUILD_DIR)/Adrenaline.zip

.PHONY: test build generate-app-icon app sign migration-pkg release-zip reinstall run clean verify-helper-sections verify-deployment-target

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS)

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
	install_name_tool -add_rpath @executable_path/../Frameworks $(HELPERS_DIR)/adrenaline
	cp -R $(SPARKLE_FRAMEWORK) $(FRAMEWORKS_DIR)/Sparkle.framework
	# The privileged helper is Objective-C and needs no Swift runtime; only the
	# executables that stay inside the bundle load the embedded copy.
	xcrun swift-stdlib-tool --copy --platform macosx \
		--source-libraries "$(SWIFT_BACKDEPLOY_LIBS)" \
		--scan-executable $(MACOS_DIR)/Adrenaline \
		--scan-executable $(HELPERS_DIR)/adrenaline \
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
	# The Swift runtime is only embedded when deploying below macOS 10.14.4.
	find "$(FRAMEWORKS_DIR)" -maxdepth 1 -name 'libswift*.dylib' \
		-exec codesign --force --options runtime --sign "$(CODE_SIGN_IDENTITY)" {} \;
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

# Release builds must run on macOS 10.13 Intel Macs.
verify-deployment-target:
	for product in Adrenaline AdrenalineHelper AdrenalineCLI; do \
		lipo -info $(SWIFT_BIN_DIR)/$$product; \
		vtool -arch x86_64 -show-build $(SWIFT_BIN_DIR)/$$product | grep 'minos 10.13$$' \
			|| { echo "$$product: x86_64 slice does not target macOS 10.13"; exit 1; }; \
	done

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
