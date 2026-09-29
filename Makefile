# SmallGame — SwiftUI + SpriteKit iOS app (Taiwanese retro mini games)
#
# Quick start after clone:
#   make setup      # install xcodegen/swiftlint (if needed) + generate the project
#   make test       # run the unit test suite
#   make run        # build, install, and launch the app on the iPhone simulator
#
# SmallGame.xcodeproj is generated from project.yml via xcodegen — it is not
# hand-edited and not committed. Edit project.yml, then `make generate`.

PROJECT   := SmallGame.xcodeproj
SCHEME    := SmallGame
CONFIGURATION := Debug
DERIVED   := build
APP       := $(DERIVED)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(SCHEME).app
ARCHIVE   := $(DERIVED)/$(SCHEME).xcarchive
EXPORT    := $(DERIVED)/export
BUNDLE_ID := com.zeyanlin.smallgame
TEAM_ID   := NKJSLB6HBR
SIMULATOR ?= iPhone 17

.DEFAULT_GOAL := help
.PHONY: help setup generate lint build test run open release archive ipa clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# --- Setup / housekeeping ---

setup: ## install xcodegen + swiftlint (if needed) and generate the Xcode project
	@which xcodegen > /dev/null || brew install xcodegen
	@which swiftlint > /dev/null || brew install swiftlint
	$(MAKE) generate

generate: ## regenerate SmallGame.xcodeproj from project.yml (source of truth)
	xcodegen generate

lint: ## run SwiftLint over the sources
	swiftlint

clean: ## Remove build artifacts
	rm -rf $(DERIVED)
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean >/dev/null 2>&1 || true

# --- App: requires the iOS simulator runtime ---

build: generate ## Compile the app for the simulator
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(DERIVED) build

test: generate ## Run unit tests (XCTest)
	@# Tests need a concrete simulator; the generic destination is build-only.
	xcodebuild test -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED) \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-enableCodeCoverage YES

run: build ## Build, then install & launch on the iPhone simulator
	@xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	@# Xcode 27 replaced Simulator.app with DeviceHub.app; `open -a Simulator` no longer resolves.
	open -a DeviceHub
	xcrun simctl install "$(SIMULATOR)" "$(APP)"
	xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

open: generate ## Open the project in Xcode
	open $(PROJECT)

# --- Release: signed App Store build (needs Xcode signed in to your Apple ID) ---

release: archive ipa ## Archive + export an uploadable .ipa

archive: generate ## Archive a signed Release build (auto signing)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE) \
		-allowProvisioningUpdates \
		archive

ipa: ## Export an uploadable .ipa from the archive (run `make archive` first)
	@# Force the system rsync first: a Homebrew rsync in PATH breaks the IPA
	@# packaging step with "Copy failed" (extended-attributes incompatibility).
	PATH="/usr/bin:/bin:/usr/sbin:/sbin:$$PATH" xcodebuild -exportArchive \
		-archivePath $(ARCHIVE) \
		-exportOptionsPlist exportOptions.plist \
		-exportPath $(EXPORT) \
		-allowProvisioningUpdates
	@echo "IPA → $(EXPORT)/$(SCHEME).ipa  (upload via Transporter)"
