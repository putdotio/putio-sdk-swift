.PHONY: bootstrap verify verify-concurrency verify-spm verify-platforms coverage-check podspec-package-check sendable-audit transport-isolation-check simulator-destination-check live-test example-install print-simulator-destination secrets-setup secrets-clean clean

bootstrap:
	bundle config set --local path vendor/bundle
	bundle install

verify:
	swift format lint --strict --recursive --parallel Package.swift PutioSDK Tests Example/PutioSDK Example/Tests scripts
	bundle exec ruby scripts/check-podspec-package.rb
	./scripts/check-sendable-audit.sh
	./scripts/check-transport-isolation.sh
	./scripts/check-platform-simulator-destination.sh
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

# tvOS and watchOS unit-test runs (each builds the library for its platform
# first). The PlatformVerify workspace wraps the package because the tracked
# CocoaPods _Pods.xcodeproj symlink breaks xcodebuild package discovery at the
# repository root.
verify-platforms:
	@set -e; for platform in tvOS watchOS; do \
		destination="$$(./scripts/platform-simulator-destination.sh $$platform)"; \
		echo "Testing PutioSDK on $$platform simulator ($$destination)"; \
		xcodebuild -workspace PlatformVerify.xcworkspace -scheme PutioSDKPlatformTests -destination "$$destination" test CODE_SIGNING_ALLOWED=NO; \
	done

coverage-check:
	./scripts/check-spm-coverage.sh 90

podspec-package-check:
	bundle exec ruby scripts/check-podspec-package.rb

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

example-install:
	bundle exec pod install --project-directory=Example

print-simulator-destination:
	@./scripts/xcode-iphone-simulator-destination.sh --workspace Example/PutioSDK.xcworkspace --scheme PutioSDK

clean:
	rm -rf .build .bundle Package.resolved vendor/bundle Example/Pods
