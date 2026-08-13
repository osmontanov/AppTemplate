import Foundation
import Testing
@testable import AppTemplate

struct JWTExpiryDecoderTests {
    @Test func numericExpiryReturnsUnixDate() {
        let token = "e30.eyJleHAiOjE3MzU2ODk2MDB9.c2ln"

        #expect(
            JWTExpiryDecoder.expiryDate(from: token)
                == Date(timeIntervalSince1970: 1_735_689_600)
        )
    }

    @Test func missingAndMalformedJWTMetadataReturnNil() {
        let tokens = [
            "",
            "one-segment",
            "e30.e30",
            "e30.%%%.c2ln",
            "e30.bm90LWpzb24.c2ln",
            "e30.e30.c2ln"
        ]

        for token in tokens {
            #expect(JWTExpiryDecoder.expiryDate(from: token) == nil)
        }
    }

    @Test func unsupportedExpiryClaimTypesReturnNil() {
        let tokens = [
            "e30.eyJleHAiOiIxNzM1Njg5NjAwIn0.c2ln",
            "e30.eyJleHAiOnRydWV9.c2ln"
        ]

        for token in tokens {
            #expect(JWTExpiryDecoder.expiryDate(from: token) == nil)
        }
    }
}
