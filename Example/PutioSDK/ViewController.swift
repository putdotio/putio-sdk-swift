import AuthenticationServices
import PutioSDK
import UIKit

class ViewController: UIViewController {
  var api: PutioSDK?
  var session: ASWebAuthenticationSession?
  var pendingOAuthState: String?

  private let authCallbackScheme = "putioswift"
  private let authCallbackHost = "auth"

  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var startButton: UIButton!

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  @IBAction func startButtonTapped(_ sender: Any) {
    guard let clientID = textField.text else { return }
    createAPI(clientID: clientID)
  }

  func createAPI(clientID: String) {
    api = PutioSDK(config: PutioSDKConfig(clientID: clientID))
    startAuthFlow()
  }

  // https://developer.apple.com/documentation/authenticationservices/authenticating_a_user_through_a_web_service
  func startAuthFlow() {
    guard let api = api else { return }

    let state: String
    do {
      state = try PutioSDK.generateOAuthState()
    } catch {
      return handleAuthCallbackFailure(error: error)
    }

    pendingOAuthState = state
    let url = api.getAuthURL(
      redirectURI: "\(authCallbackScheme)://\(authCallbackHost)", state: state)

    session = ASWebAuthenticationSession(url: url, callbackURLScheme: authCallbackScheme) {
      [weak self] callbackURL, error in
      guard let self else { return }
      self.session = nil

      guard error == nil, let callbackURL = callbackURL else {
        return self.handleAuthCallbackFailure(
          error: error ?? self.makeAuthError("Missing OAuth callback URL"))
      }

      // Callback URL: putioswift://auth#access_token={TOKEN}
      return self.handleAuthCallbackSuccess(callbackURL: callbackURL)
    }

    session?.presentationContextProvider = self
    session?.start()
  }

  func handleAuthCallbackFailure(error: Error) {
    pendingOAuthState = nil
    session = nil

    let alertController = UIAlertController(
      title: "Auth Failure", message: error.localizedDescription, preferredStyle: .alert)
    let closeButton = UIAlertAction(title: "OK", style: .cancel, handler: nil)
    alertController.addAction(closeButton)
    present(alertController, animated: true, completion: nil)
  }

  func handleAuthCallbackSuccess(callbackURL: URL) {
    defer {
      pendingOAuthState = nil
      session = nil
    }

    guard let api else { return }
    guard let pendingOAuthState else {
      return handleAuthCallbackFailure(error: makeAuthError("Missing pending OAuth state"))
    }

    let token: String
    do {
      token = try api.accessToken(
        fromOAuthCallback: callbackURL,
        expectedScheme: authCallbackScheme,
        expectedHost: authCallbackHost,
        expectedState: pendingOAuthState
      )
    } catch {
      return handleAuthCallbackFailure(error: error)
    }

    Task {
      await fetchAccountInfo(token: token)
    }
  }

  func makeAuthError(_ message: String) -> NSError {
    NSError(domain: "PutioSDKExampleAuth", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
  }

  @MainActor
  func fetchAccountInfo(token: String) async {
    api?.setToken(token: token)

    guard let api else { return }

    do {
      let account = try await api.getAccountInfo()
      fetchAccountInfoSuccess(account: account)
    } catch {
      fetchAccountInfoFailure(error: error)
    }
  }

  func fetchAccountInfoFailure(error: Error) {
    let alertController = UIAlertController(
      title: "API: Fetch Account Info Failure", message: error.localizedDescription,
      preferredStyle: .alert)
    let closeButton = UIAlertAction(title: "OK", style: .cancel, handler: nil)
    alertController.addAction(closeButton)
    present(alertController, animated: true, completion: nil)
  }

  func fetchAccountInfoSuccess(account: PutioAccount) {
    let alertController = UIAlertController(
      title: "API: Fetch Account Info Success", message: account.username, preferredStyle: .alert)
    let closeButton = UIAlertAction(
      title: "OK", style: .cancel,
      handler: { _ in
        guard let api = self.api else { return }
        Task {
          do {
            let response = try await api.getFiles(parentID: 0)
            print("Files result: \(response.children.count)")
          } catch let error as PutioSDKError {
            print("Files error: \(error.type)")
          } catch {
            print("Files error: \(error.localizedDescription)")
          }
        }
      })
    alertController.addAction(closeButton)
    present(alertController, animated: true, completion: nil)
  }
}

extension ViewController: ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    return view.window ?? ASPresentationAnchor()
  }
}
