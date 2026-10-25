# Example App

Smoke test for the SDK's OAuth flow. It links `PutioSDK` from this checkout and
registers its own callback URL scheme.

```bash
open Example/PutioSDK.xcodeproj
```

1. Run the `PutioSDK_Example` target on an iPhone simulator.
2. Enter your own put.io OAuth client ID.
3. Finish the `ASWebAuthenticationSession` sign-in.
4. Check that the app fetches account info and lists files.
