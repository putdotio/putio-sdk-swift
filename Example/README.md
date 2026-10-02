# Example App

Smoke-test surface for the SDK's OAuth flow. It links the Swift package from this checkout as `PutioSDK` and registers its own callback URL scheme for the OAuth redirect.

## Setup

From the repository root:

```bash
open Example/PutioSDK.xcodeproj
```

## Usage

- run the `PutioSDK_Example` target
- enter your own put.io OAuth client ID
- complete the `ASWebAuthenticationSession` sign-in flow
- confirm the app can fetch account info and list files after the state-validated callback

Keep personal tokens, client secrets, and test credentials from local smoke checks out of commits
