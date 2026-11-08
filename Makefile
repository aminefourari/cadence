SHELL := /bin/bash
PROJECT := Cadence.xcodeproj
DERIVED := build
RELEASE_DERIVED := build-release
APP := $(DERIVED)/Build/Products/Debug/Cadence.app
RELEASE_APP := $(RELEASE_DERIVED)/Build/Products/Release/Cadence.app
CARGO_HOME_DIR := $(CURDIR)/.cargo-home
VERSION := $(shell sed -nE 's/.*MARKETING_VERSION: "([^"]*)".*/\1/p' project.yml)

.PHONY: project build run release zip test clean icon

project:
	@if command -v xcodegen >/dev/null 2>&1; then \
		xcodegen generate; \
	elif [ ! -f "$(PROJECT)/project.pbxproj" ]; then \
		echo "error: xcodegen is required to create $(PROJECT)." >&2; \
		exit 1; \
	else \
		echo "xcodegen not installed; using the checked-in Xcode project."; \
	fi

build: project
	xcodebuild -project "$(PROJECT)" -scheme Cadence -configuration Debug -derivedDataPath "$(DERIVED)" build

run: build
	open "$(APP)"

release: project
	xcodebuild -project "$(PROJECT)" -scheme Cadence -configuration Release -derivedDataPath "$(RELEASE_DERIVED)" build
	mkdir -p dist
	rm -rf dist/Cadence.app
	ditto "$(RELEASE_APP)" dist/Cadence.app
	@echo "Built dist/Cadence.app"

zip: release
	ditto -c -k --norsrc --keepParent dist/Cadence.app dist/Cadence-$(VERSION).zip
	@echo "Built dist/Cadence-$(VERSION).zip"

test:
	@CARGO="$$(command -v cargo | head -1)"; \
	if [ -z "$$CARGO" ]; then \
		echo "error: Cargo is required." >&2; \
		exit 1; \
	fi; \
	mkdir -p "$(CARGO_HOME_DIR)"; \
	cd core && unset MACOSX_DEPLOYMENT_TARGET && CARGO_HOME="$(CARGO_HOME_DIR)" "$$CARGO" test

icon:
	python3 scripts/generate_icon.py

clean:
	rm -rf "$(DERIVED)" "$(RELEASE_DERIVED)" .module-cache .tmpcheck
	rm -rf core/target .cargo-home dist
