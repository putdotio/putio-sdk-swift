# Example App

Smoke test for the SDK's OAuth flow. It links `PutioSDK` from this checkout and
registers the `putioswift://auth` callback URL.

```bash
open Example/PutioSDK.xcodeproj
```

1. Register `putioswift://auth` as a redirect URI on your put.io OAuth app.
2. Run the `PutioSDK-Example` scheme on an iPhone simulator.
3. Enter your put.io OAuth client ID and complete the
   `ASWebAuthenticationSession` sign-in.
4. Confirm the account alert shows your username, tap `OK`, and check the Xcode
   console for `Files result: <count>`.
