.PHONY: bootstrap verify verify-spm coverage-check live-test example-install print-simulator-destination secrets-setup secrets-clean clean

SECRETS_OUTPUT ?= .env.local

bootstrap:
	bundle config set --local path vendor/bundle
	bundle install

verify:
	swift test --enable-code-coverage --filter PutioSDKTests
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

verify-spm:
	swift build

coverage-check:
	./scripts/check-spm-coverage.sh 90

live-test:
	swift test --filter PutioSDKLiveTests

secrets-setup:
	@infisical export --domain https://eu.infisical.com/api --projectId b2fcfbd7-19e0-4b87-a797-93d125c432ce --env dev --path /sdk-swift --format dotenv --output-file $(SECRETS_OUTPUT)
	@chmod 600 $(SECRETS_OUTPUT)

secrets-clean:
	rm -f .env.local .env.local.* .env.local.swp

example-install:
	bundle exec pod install --project-directory=Example

print-simulator-destination:
	@./scripts/xcode-iphone-simulator-destination.sh --workspace Example/PutioSDK.xcworkspace --scheme PutioSDK

clean:
	rm -rf .build .bundle Package.resolved vendor/bundle Example/Pods
