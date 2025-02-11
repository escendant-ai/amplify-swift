//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

#if os(iOS) || os(macOS)
import Foundation

import XCTest
@testable import Amplify
@testable import AWSCognitoAuthPlugin
import AuthenticationServices
import AWSCognitoIdentityProvider

class AWSAuthHostedUISignInTests: XCTestCase {

    var plugin: AWSCognitoAuthPlugin!
    let networkTimeout = TimeInterval(5)
    var mockIdentityProvider: CognitoUserPoolBehavior!
    var mockHostedUIResult: Result<[URLQueryItem], HostedUIError>!
    var mockTokenResult = ["id_token": AWSCognitoUserPoolTokens.testData.idToken,
                           "access_token": AWSCognitoUserPoolTokens.testData.accessToken,
                           "refresh_token": AWSCognitoUserPoolTokens.testData.refreshToken,
                           "expires_in": 10] as [String: Any]
    var mockState = "someState"
    var mockProof = "someProof"
    var mockJson: Data!

    var configuration = HostedUIConfigurationData(clientId: "clientId", oauth: .init(
        domain: "cognitodomain",
        scopes: ["name"],
        signInRedirectURI: "myapp://",
        signOutRedirectURI: "myapp://"))
    let initialState = AuthState.configured(.signedOut(.init(lastKnownUserName: nil)), .configured, .notStarted)

    func urlSessionMock() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func customPlugin(with cusotmConfiguration: HostedUIConfigurationData?) -> AWSCognitoAuthPlugin {
        let plugin = AWSCognitoAuthPlugin()
        mockJson = try! JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        func sessionFactory() -> HostedUISessionBehavior {
            MockHostedUISession(result: mockHostedUIResult)
        }

        func mockRandomString() -> RandomStringBehavior {
            return MockRandomStringGenerator(mockString: mockState, mockUUID: mockState)
        }

        let environment = BasicHostedUIEnvironment(configuration: cusotmConfiguration ?? configuration,
                                                   hostedUISessionFactory: sessionFactory,
                                                   urlSessionFactory: urlSessionMock,
                                                   randomStringFactory: mockRandomString)
        let authEnvironment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: { self.mockIdentityProvider },
            hostedUIEnvironment: environment)
        let stateMachine = Defaults.authStateMachineWith(
            environment: authEnvironment,
            initialState: initialState
        )

        plugin.configure(
            authConfiguration: Defaults.makeDefaultAuthConfigData(withHostedUI: configuration),
            authEnvironment: authEnvironment,
            authStateMachine: stateMachine,
            credentialStoreStateMachine: Defaults.makeDefaultCredentialStateMachine(),
            hubEventHandler: MockAuthHubEventBehavior(),
            analyticsHandler: MockAnalyticsHandler())
        return plugin
    }

    override func setUp() {
        plugin = AWSCognitoAuthPlugin()
        mockJson = try! JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        func sessionFactory() -> HostedUISessionBehavior {
            MockHostedUISession(result: mockHostedUIResult)
        }

        func mockRandomString() -> RandomStringBehavior {
            return MockRandomStringGenerator(mockString: mockState, mockUUID: mockState)
        }

        let environment = BasicHostedUIEnvironment(configuration: configuration,
                                                   hostedUISessionFactory: sessionFactory,
                                                   urlSessionFactory: urlSessionMock,
                                                   randomStringFactory: mockRandomString)
        let authEnvironment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: { self.mockIdentityProvider },
            hostedUIEnvironment: environment)
        let stateMachine = Defaults.authStateMachineWith(
            environment: authEnvironment,
            initialState: initialState
        )

        plugin.configure(
            authConfiguration: Defaults.makeDefaultAuthConfigData(withHostedUI: configuration),
            authEnvironment: authEnvironment,
            authStateMachine: stateMachine,
            credentialStoreStateMachine: Defaults.makeDefaultCredentialStateMachine(),
            hubEventHandler: MockAuthHubEventBehavior(),
            analyticsHandler: MockAnalyticsHandler())
    }

    @MainActor
    func testSuccessfulSignIn() async throws {
        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])
        let result = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
        XCTAssertTrue(result.isSignedIn)
    }

    @MainActor
    func testSuccessfulSignIn_missingExpiresIn() async throws {
        mockTokenResult = ["id_token": AWSCognitoUserPoolTokens.testData.idToken,
                           "access_token": AWSCognitoUserPoolTokens.testData.accessToken,
                           "refresh_token": AWSCognitoUserPoolTokens.testData.refreshToken] as [String: Any]
        mockJson = try! JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])
        let result = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
        XCTAssertTrue(result.isSignedIn)
    }

    @MainActor
    func testSuccessfulSignIn_missingExpiresIn_testTokenMissingExp() async throws {
        mockTokenResult = ["id_token": AWSCognitoUserPoolTokens.testDataWithoutExp.idToken,
                           "access_token": AWSCognitoUserPoolTokens.testData.accessToken,
                           "refresh_token": AWSCognitoUserPoolTokens.testData.refreshToken] as [String: Any]
        mockJson = try! JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])
        let result = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
        XCTAssertTrue(result.isSignedIn)
    }

    @MainActor
    func testSuccessfulSignIn_missingExpiresIn_testBothTokenMissingExp() async throws {
        mockTokenResult = ["id_token": AWSCognitoUserPoolTokens.testDataWithoutExp.idToken,
                           "access_token": AWSCognitoUserPoolTokens.testDataWithoutExp.accessToken,
                           "refresh_token": AWSCognitoUserPoolTokens.testData.refreshToken] as [String: Any]
        mockJson = try! JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])
        let result = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
        XCTAssertTrue(result.isSignedIn)
    }

    @MainActor
    func testUserCancelSignIn() async {
        mockHostedUIResult = .failure(.cancelled)
        let expectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.service(_, _, let underlyingError) = error,
                  case .userCancelled = (underlyingError as? AWSCognitoAuthError) else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: networkTimeout)
    }

    @MainActor
    func testRestartAfterError() async throws {
        mockHostedUIResult = .failure(.cancelled)
        let errorExpectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.service(_, _, let underlyingError) = error,
                  case .userCancelled = (underlyingError as? AWSCognitoAuthError) else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            errorExpectation.fulfill()
        }

        await fulfillment(of: [errorExpectation], timeout: networkTimeout)
        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])
        let signInExpectation = expectation(description: "SignIn operation should complete")
        do {
            let result = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTAssertTrue(result.isSignedIn)
            signInExpectation.fulfill()
        } catch {
            XCTFail("Should not fail with error = \(error)")
        }
        await fulfillment(of: [signInExpectation], timeout: networkTimeout)
    }

    @MainActor
    func testInvalidCodeSignIn() async {
        mockHostedUIResult = .success([
            .init(name: "state", value: "differentState"),
            .init(name: "code", value: mockProof)
        ])
        let expectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.service = error else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: networkTimeout)
    }

    @MainActor
    func testInvalidPresentationContextError() async {
        mockHostedUIResult = .failure(.invalidContext)
        let expectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.invalidState = error else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: networkTimeout)
    }

    func testUnableToStartASWebAuthenticationSession() async {
        mockHostedUIResult = .failure(.unableToStartASWebAuthenticationSession)
        let expectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.service = error else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: networkTimeout)
    }

    @MainActor
    func testTokenParsingFailure() async {
        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])
        mockTokenResult = [
            "refresh_token": AWSCognitoUserPoolTokens.testData.refreshToken,
            "expires_in": 10] as [String: Any]
        mockJson = try! JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        let expectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.service = error else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: networkTimeout)
    }

    @MainActor
    /// Given: A HostedUI response with `error` and `error_description` query parameters.
    /// When: Invoking `signInWithWebUI`
    /// Then: The caller should receive an `AuthError.service` where the `errorDescription`
    /// is `"\(error) \(error_description)"`
    func testTokenErrorResponse() async throws {
        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])

        let (errorMessage, errorDescription) = ("invalid_grant", "Some error")
        mockTokenResult = [
            "error": errorMessage,
            "error_description": errorDescription
        ]
        mockJson = try JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        let expectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.service(let message, _, _) = error else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            let expectedErrorDescription = "\(errorMessage) \(errorDescription)"
            XCTAssertEqual(expectedErrorDescription, message)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: networkTimeout)
    }

    @MainActor
    func testInvalidRedirectConfigurationFailure() async {
        let invalidRedirectConfig = HostedUIConfigurationData(clientId: "clientId", oauth: .init(
            domain: "cognitodomain",
            scopes: ["name"],
            signInRedirectURI: "@#$%junk1343",
            signOutRedirectURI: "@3451://"))
        let testPlugin = customPlugin(with: invalidRedirectConfig)

        mockHostedUIResult = .success([
            .init(name: "state", value: mockState),
            .init(name: "code", value: mockProof)
        ])
        mockTokenResult = [
            "refresh_token": AWSCognitoUserPoolTokens.testData.refreshToken,
            "expires_in": 10] as [String: Any]
        mockJson = try! JSONSerialization.data(withJSONObject: mockTokenResult)
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(), self.mockJson)
        }

        let expectation  = expectation(description: "SignIn operation should complete")
        do {
            _ = try await testPlugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTFail("Should not succeed")
        } catch {
            guard case AuthError.configuration = error else {
                XCTFail("Should not fail with error = \(error)")
                return
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: networkTimeout)
    }



    /// Test a signIn restart while another sign in is in progress
    ///
    /// - Given: Given an auth plugin with mocked service and a in progress signIn waiting for SMS verification
    ///
    /// - When:
    ///    - I invoke another signIn with valid values
    /// - Then:
    ///    - I should get a .done response
    ///
    @MainActor
    func testRestartSignInWithWebUI() async {

        self.mockIdentityProvider = MockIdentityProvider(mockInitiateAuthResponse: { _ in
            InitiateAuthOutput(
                authenticationResult: .none,
                challengeName: .passwordVerifier,
                challengeParameters: InitiateAuthOutput.validChalengeParams,
                session: "someSession")
        }, mockRespondToAuthChallengeResponse: { _ in
            RespondToAuthChallengeOutput(
                authenticationResult: .none,
                challengeName: .smsMfa,
                challengeParameters: [:],
                session: "session")
        })

        let pluginOptions = AWSAuthSignInOptions(metadata: ["somekey": "somevalue"])
        let options = AuthSignInRequest.Options(pluginOptions: pluginOptions)

        do {
            let result = try await plugin.signIn(username: "username", password: "password", options: options)
            guard case .confirmSignInWithSMSMFACode =  result.nextStep else {
                XCTFail("Result should be .confirmSignInWithSMSMFACode for next step")
                return
            }
            XCTAssertFalse(result.isSignedIn)
            mockHostedUIResult = .success([
                .init(name: "state", value: mockState),
                .init(name: "code", value: mockProof)
            ])
            let result2 = try await plugin.signInWithWebUI(presentationAnchor: ASPresentationAnchor(), options: nil)
            XCTAssertTrue(result2.isSignedIn)
        } catch {
            XCTFail("Received failure with error \(error)")
        }
    }
}
#endif
