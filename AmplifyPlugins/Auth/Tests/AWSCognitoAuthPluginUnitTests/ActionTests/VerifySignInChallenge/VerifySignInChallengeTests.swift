//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AWSCognitoIdentityProvider
@_spi(UnknownAWSHTTPServiceError) import AWSClientRuntime
@testable import AWSPluginsTestCommon
@testable import AWSCognitoAuthPlugin

class VerifySignInChallengeTests: XCTestCase {

    typealias CognitoFactory = BasicSRPAuthEnvironment.CognitoUserPoolFactory

    let mockRespondAuthChallenge = RespondToAuthChallenge(challenge: .smsMfa,
                                                          availableChallenges: [],
                                                          username: "usernameMock",
                                                          session: "mockSession",
                                                          parameters: [:])
    let mockConfirmEvent = ConfirmSignInEventData(
        answer: "1233",
        attributes: [:],
        metadata: [:],
        friendlyDeviceName: nil,
        presentationAnchor: nil)

    /// Test if valid input are given the service call is made
    ///
    /// - Given: VerifySignInChallenge action with mocked cognito client and configuration
    /// - When:
    ///    - I invoke the action with valid input
    /// - Then:
    ///    - Cognito client should invoke the api `respondToAuthChallengeCallback`
    ///
    func testInitiateVerifyChallenge() async {
        let verifyPasswordInvoked = expectation(
            description: "verifyChallengeInvoked"
        )
        let identityProviderFactory: CognitoFactory = {
            MockIdentityProvider(
                mockRespondToAuthChallengeResponse: { _ in
                    verifyPasswordInvoked.fulfill()
                    return RespondToAuthChallengeOutput()
                })
        }

        let environment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: identityProviderFactory)
        let action = VerifySignInChallenge(challenge: mockRespondAuthChallenge,
                                           confirmSignEventData: mockConfirmEvent,
                                           signInMethod: .apiBased(.userSRP),
                                           currentSignInStep: .confirmSignInWithTOTPCode)

        await action.execute(
            withDispatcher: MockDispatcher { _ in },
            environment: environment
        )

        await fulfillment(
            of: [verifyPasswordInvoked],
            timeout: 0.1
        )
    }

    /// Test empty response is returned by Cognito proper error is thrown
    ///
    /// - Given: VerifySignInChallenge action with mocked cognito client and configuration
    /// - When:
    ///    - I invoke the action with valid input and mock empty response from service
    /// - Then:
    ///    - Should send an event with proper error
    ///
    func testVerifyChallengeWithEmptyResponse() async {

        let identityProviderFactory: CognitoFactory = {
            MockIdentityProvider(
                mockRespondToAuthChallengeResponse: { _ in
                    return RespondToAuthChallengeOutput()
                })
        }

        let environment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: identityProviderFactory)

        let action = VerifySignInChallenge(challenge: mockRespondAuthChallenge,
                                           confirmSignEventData: mockConfirmEvent,
                                           signInMethod: .apiBased(.userSRP),
                                           currentSignInStep: .confirmSignInWithTOTPCode)

        let passwordVerifierError = expectation(description: "passwordVerifierError")

        let dispatcher = MockDispatcher { event in
            defer { passwordVerifierError.fulfill() }

            guard let event = event as? SignInEvent else {
                XCTFail("Expected event to be SignInEvent but got \(event)")
                return
            }

            guard case let .throwAuthError(error) = event.eventType,
                  case .invalidServiceResponse = error
            else {
                      XCTFail("Should receive invalid service response")
                      return
                  }

        }

        await action.execute(withDispatcher: dispatcher, environment: environment)
        await fulfillment(
            of: [passwordVerifierError],
            timeout: 0.1
        )
    }

    /// Test  successful response from the VerifySignInChallenge
    ///
    /// - Given: VerifySignInChallenge action with mocked cognito client and configuration
    /// - When:
    ///    - I invoke the action with valid input
    /// - Then:
    ///    - Should send an event with the result
    ///
    func testSuccessfulRespondToAuthChallengePropagatesSuccess() async {
        let identityProviderFactory: CognitoFactory = {
            MockIdentityProvider(
                mockRespondToAuthChallengeResponse: { _ in
                    return RespondToAuthChallengeOutput.testData()
                })
        }

        let environment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: identityProviderFactory)

        let action = VerifySignInChallenge(challenge: mockRespondAuthChallenge,
                                           confirmSignEventData: mockConfirmEvent,
                                           signInMethod: .apiBased(.userSRP),
                                           currentSignInStep: .confirmSignInWithTOTPCode)

        let verifyChallengeComplete = expectation(description: "verifyChallengeComplete")

        let dispatcher = MockDispatcher { event in
            guard let event = event as? SignInEvent else {
                XCTFail("Expected event to be SignInEvent but got \(event)")
                return
            }

            if case let .finalizeSignIn(signedInData) = event.eventType {
                XCTAssertNotNil(signedInData)
                verifyChallengeComplete.fulfill()
            }
        }

        await action.execute(withDispatcher: dispatcher, environment: environment)
        await fulfillment(
            of: [verifyChallengeComplete],
            timeout: 0.1
        )
    }

    /// Test  successful response from the VerifySignInChallenge
    ///
    /// - Given: VerifySignInChallenge action with mocked cognito client and configuration
    /// - When:
    ///    - I invoke the action with valid input and mock error from service
    /// - Then:
    ///    - Should send an event with service error
    ///
    func testRespondToAuthChallengePropagatesError() async {
        let identityProviderFactory: CognitoFactory = {
            MockIdentityProvider(
                mockRespondToAuthChallengeResponse: { _ in
                    throw AWSClientRuntime.UnknownAWSHTTPServiceError(
                        httpResponse: MockHttpResponse.ok,
                        message: nil,
                        requestID: nil,
                        requestID2: nil,
                        typeName: nil
                    )
                })
        }

        let environment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: identityProviderFactory)

        let action = VerifySignInChallenge(challenge: mockRespondAuthChallenge,
                                           confirmSignEventData: mockConfirmEvent,
                                           signInMethod: .apiBased(.userSRP),
                                           currentSignInStep: .confirmSignInWithTOTPCode)

        let passwordVerifierError = expectation(
            description: "passwordVerifierError")

        let dispatcher = MockDispatcher { event in
            defer { passwordVerifierError.fulfill() }

            guard let event = event as? SignInEvent else {
                XCTFail("Expected event to be SignInEvent but got \(event)")
                return
            }

            guard case let .throwAuthError(error) = event.eventType,
                  case .service = error
            else {
                      XCTFail("Should receive invalid service response")
                      return
                  }
        }

        await action.execute(withDispatcher: dispatcher, environment: environment)
        await fulfillment(
            of: [passwordVerifierError],
            timeout: 0.1
        )
    }

    /// Test verify password retry on device not found
    ///
    /// - Given: VerifySignInChallenge action with mocked cognito client and configuration
    /// - When:
    ///    - I invoke the action with valid input and mock empty device not found error from Cognito
    /// - Then:
    ///    - Should send an event with retryVerifyChallengeAnswer
    ///
    func testPasswordVerifierWithDeviceNotFound() async {

        let identityProviderFactory: CognitoFactory = {
            MockIdentityProvider(
                mockRespondToAuthChallengeResponse: { _ in
                    throw AWSCognitoIdentityProvider.ResourceNotFoundException()
                })
        }

        let environment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: identityProviderFactory)

        let action = VerifySignInChallenge(challenge: mockRespondAuthChallenge,
                                           confirmSignEventData: mockConfirmEvent,
                                           signInMethod: .apiBased(.userSRP),
                                           currentSignInStep: .confirmSignInWithTOTPCode)
        let passwordVerifierError = expectation(description: "passwordVerifierError")

        let dispatcher = MockDispatcher { event in
            defer { passwordVerifierError.fulfill() }

            guard let event = event as? SignInChallengeEvent else {
                XCTFail("Expected event to be SignInEvent but got \(event)")
                return
            }

            guard case .retryVerifyChallengeAnswer = event.eventType
            else {
                XCTFail("Should receive retryRespondPasswordVerifier")
                return
            }
        }

        await action.execute(withDispatcher: dispatcher, environment: environment)
        await fulfillment(
            of: [passwordVerifierError],
            timeout: 0.1
        )
    }

    /// Test  successful response from the VerifySignInChallenge for confirmDevice
    ///
    /// - Given: VerifySignInChallenge action with mocked cognito client and configuration
    /// - When:
    ///    - I invoke the action with valid input and mock new device
    /// - Then:
    ///    - Should send an event confirmDevice
    ///
    func testRespondToAuthChallengeWithConfirmDevice() async {
        let identityProviderFactory: CognitoFactory = {
            MockIdentityProvider(
                mockRespondToAuthChallengeResponse: { _ in
                    return RespondToAuthChallengeOutput.testDataWithNewDevice()
                })
        }

        let environment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: identityProviderFactory)

        let action = VerifySignInChallenge(challenge: mockRespondAuthChallenge,
                                           confirmSignEventData: mockConfirmEvent,
                                           signInMethod: .apiBased(.userSRP),
                                           currentSignInStep: .confirmSignInWithTOTPCode)

        let verifyChallengeComplete = expectation(description: "verifyChallengeComplete")

        let dispatcher = MockDispatcher { event in
            guard let event = event as? SignInEvent else {
                XCTFail("Expected event to be SignInEvent but got \(event)")
                return
            }

            if case .confirmDevice(let signedInData) = event.eventType {
                XCTAssertNotNil(signedInData)
                verifyChallengeComplete.fulfill()
            }
        }

        await action.execute(withDispatcher: dispatcher, environment: environment)
        await fulfillment(
            of: [verifyChallengeComplete],
            timeout: 0.1
        )
    }

    /// Test  successful response from the VerifySignInChallenge for verify device
    ///
    /// - Given: VerifySignInChallenge action with mocked cognito client and configuration
    /// - When:
    ///    - I invoke the action with valid input and mock new device
    /// - Then:
    ///    - Should send an event initiateDeviceSRP
    ///
    func testRespondToAuthChallengeWithVerifyDevice() async {
        let identityProviderFactory: CognitoFactory = {
            MockIdentityProvider(
                mockRespondToAuthChallengeResponse: { _ in
                    return RespondToAuthChallengeOutput.testDataWithVerifyDevice()
                })
        }

        let environment = Defaults.makeDefaultAuthEnvironment(
            userPoolFactory: identityProviderFactory)

        let action = VerifySignInChallenge(challenge: mockRespondAuthChallenge,
                                           confirmSignEventData: mockConfirmEvent,
                                           signInMethod: .apiBased(.userSRP),
                                           currentSignInStep: .confirmSignInWithTOTPCode)

        let verifyChallengeComplete = expectation(description: "verifyChallengeComplete")

        let dispatcher = MockDispatcher { event in
            guard let event = event as? SignInEvent else {
                XCTFail("Expected event to be SignInEvent but got \(event)")
                return
            }

            if case .initiateDeviceSRP(_, let response) = event.eventType {
                XCTAssertNotNil(response)
                verifyChallengeComplete.fulfill()
            }
        }

        await action.execute(withDispatcher: dispatcher, environment: environment)
        await fulfillment(
            of: [verifyChallengeComplete],
            timeout: 0.1
        )
    }
}
