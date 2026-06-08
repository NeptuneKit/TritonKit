import ArgumentParser
import Foundation
import TritonKitShared

// MARK: - Host-Side Command Shared Helpers

func requireConfirmation(
    _ confirmed: Bool,
    action: String,
    hint: String,
    outputFormat: ClientOutputFormat
) throws {
    guard confirmed else {
        try failHostValidation(
            code: "confirmation_required",
            message: "\(action) requires --confirm.",
            hint: hint,
            outputFormat: outputFormat
        )
    }
}

func requireExactlyOneSelector(
    selected: Int,
    code: String,
    message: String,
    hint: String,
    outputFormat: ClientOutputFormat
) throws {
    guard selected == 1 else {
        try failHostValidation(code: code, message: message, hint: hint, outputFormat: outputFormat)
    }
}
