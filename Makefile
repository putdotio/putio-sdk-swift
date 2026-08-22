.PHONY: bootstrap verify verify-concurrency verify-spm coverage-check sendable-audit live-test example-install print-simulator-destination secrets-setup secrets-clean clean

bootstrap:
	bundle config set --local path vendor/bundle
	bundle install

verify:
	swift format lint --strict --recursive --parallel Package.swift PutioSDK Tests Example/PutioSDK Example/Tests scripts
	./scripts/check-sendable-audit.sh
	swift test --enable-code-coverage --filter PutioSDKTests --filter PutioSDKStrictConcurrencyTests
	./scripts/check-spm-coverage.sh 90
	swift build
	bundle exec pod install --project-directory=Example
	@destination="$$(./scripts/xcode-iphone-simulator-destination.sh --workspace Example/PutioSDK.xcworkspace --scheme PutioSDK 2>/dev/null || true)"; \
	if [ -n "$$destination" ]; then \
		echo "Using Xcode iPhone simulator destination: $$destination"; \
		xcodebuild -workspace Example/PutioSDK.xcworkspace -scheme PutioSDK -configuration Debug -destination "$$destination" build CODE_SIGNING_ALLOWED=NO; \
	else \
		echo "No Xcode-advertised iPhone simulator destination on iOS 26.0 or newer. Falling back to the installed iphonesimulator SDK."; \
		xcodebuild -workspace Example/PutioSDK.xcworkspace -scheme PutioSDK -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO; \
	fi

# Focused lane for the strict-concurrency consumer proof only. `verify` above already
# runs this same filter together with PutioSDKTests in one combined `swift test`
# invocation, so use this target for a quicker concurrency-only check during iteration.
verify-concurrency:
	swift test --filter PutioSDKStrictConcurrencyTests

verify-spm:
	swift build

coverage-check:
	./scripts/check-spm-coverage.sh 90

sendable-audit:
	./scripts/check-sendable-audit.sh

live-test:
	swift test --filter PutioSDKLiveTests

secrets-setup:
	./scripts/secrets-setup.sh

secrets-clean:
	rm -f .env.local .env.local.* .env.local.swp

example-install:
	bundle exec pod install --project-directory=Example

print-simulator-destination:
	@./scripts/xcode-iphone-simulator-destination.sh --workspace Example/PutioSDK.xcworkspace --scheme PutioSDK

clean:
	rm -rf .build .bundle Package.resolved vendor/bundle Example/Pods
