//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import Foundation

extension MFAType: DefaultLogger {

    internal init?(rawValue: String) {
        if rawValue.caseInsensitiveCompare("SMS_MFA") == .orderedSame {
            self = .sms
        } else if rawValue.caseInsensitiveCompare("SOFTWARE_TOKEN_MFA") == .orderedSame {
            self = .totp
        } else if rawValue.caseInsensitiveCompare("EMAIL_OTP") == .orderedSame {
            self = .email
        } else {
            Self.log.error("Tried to initialize an unsupported MFA type with value: \(rawValue)")
            return nil
        }
    }

    /// String value of MFA Type
    public var rawValue: String {
        return challengeResponse
    }

    /// String value to be used as an input parameter during MFA selection for confirmSignIn API
    public var challengeResponse: String {
        switch self {
        case .sms:
            return "SMS_MFA"
        case .totp:
            return "SOFTWARE_TOKEN_MFA"
        case .email:
            return "EMAIL_OTP"
        }
    }
}
