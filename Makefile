.PHONY: verify markdown-check verify-concurrency verify-spm verify-platforms coverage-check sendable-audit transport-isolation-check simulator-destination-check live-test print-simulator-destination secrets-setup secrets-clean clean

# Same oxfmt release the put.io TypeScript repos run through Vite+; needs Node on PATH.
OXFMT = npx --yes oxfmt@0.70.0

verify:
	swift format lint --strict --recursive --parallel Package.swift PutioSDK Tests Example/PutioSDK Example/Tests scripts
	$(OXFMT) --check '**/*.md'
	./scripts/check-sendable-audit.sh
	./scripts/check-transport-isolation.sh
	./scripts/check-platform-simulator-destination.sh
	swift test --enable-code-coverage --filter PutioSDKTests --filter PutioSDKStrictConcurrencyTests
	./scripts/check-spm-coverage.sh 90
	swift build
	@destination="$$(./scripts/xcode-iphone-simulator-destination.sh --project Example/PutioSDK.xcodeproj --scheme PutioSDK-Example 2>/dev/null || true)"; \
	if [ -n "$$destination" ]; then \
		echo "Using Xcode iPhone simulator destination: $$destination"; \
		xcodebuild -project Example/PutioSDK.xcodeproj -scheme PutioSDK-Example -configuration Debug -destination "$$destination" build CODE_SIGNING_ALLOWED=NO; \
	else \
		echo "No Xcode-advertised iPhone simulator destination on iOS 26.0 or newer. Falling back to a generic iOS Simulator destination."; \
		xcodebuild -project Example/PutioSDK.xcodeproj -scheme PutioSDK-Example -destination "generic/platform=iOS Simulator" -configuration Debug build CODE_SIGNING_ALLOWED=NO; \
	fi

# Focused lane for the strict-concurrency consumer proof only. `verify` above already
# runs this same filter together with PutioSDKTests in one combined `swift test`
# invocation, so use this target for a quicker concurrency-only check during iteration.
verify-concurrency:
	swift test --filter PutioSDKStrictConcurrencyTests

markdown-check:
	$(OXFMT) --check '**/*.md'

verify-spm:
	swift build

# tvOS and watchOS unit-test runs (each builds the library for its platform first).
verify-platforms:
	@set -e; for platform in tvOS watchOS; do \
		destination="$$(./scripts/platform-simulator-destination.sh $$platform)"; \
		echo "Testing PutioSDK on $$platform simulator ($$destination)"; \
		xcodebuild -scheme PutioSDK -only-testing:PutioSDKTests -destination "$$destination" test CODE_SIGNING_ALLOWED=NO; \
	done

coverage-check:
	./scripts/check-spm-coverage.sh 90

sendable-audit:
	./scripts/check-sendable-audit.sh

transport-isolation-check:
	./scripts/check-transport-isolation.sh

simulator-destination-check:
	./scripts/check-platform-simulator-destination.sh

live-test:
	swift test --filter PutioSDKLiveTests

secrets-setup:
	./scripts/secrets-setup.sh

secrets-clean:
	rm -f .env.local .env.local.* .env.local.swp

print-simulator-destination:
	@./scripts/xcode-iphone-simulator-destination.sh --project Example/PutioSDK.xcodeproj --scheme PutioSDK-Example

clean:
	rm -rf .build Package.resolved
