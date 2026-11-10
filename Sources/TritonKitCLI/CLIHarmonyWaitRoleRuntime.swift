import Foundation
import TritonKitShared

enum HarmonyWaitRoleValidationError: Error {
    case emptyRole
}

func normalizedHarmonyWaitRole(_ role: String?) throws -> String? {
    guard let role else { return nil }
    let normalized = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else { throw HarmonyWaitRoleValidationError.emptyRole }
    return normalized
}

/// Harmony roles are native ArkUI `type` values, compared case-insensitively.
/// Do not infer a role from clickable state, ancestors, or another text node.
func harmonyWaitTextMatch(in data: Data, text: String, role: String?) throws -> TKHarmonyLayoutTextMatch? {
    guard let requestedRole = try normalizedHarmonyWaitRole(role) else {
        return try TKHarmonyLayoutParser.firstTextMatch(in: data, text: text)
    }
    return try TKHarmonyLayoutParser.nodeSummaries(in: data)
        .first { node in
            guard node.text == text, node.bounds != nil, let type = node.type else { return false }
            return type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == requestedRole
        }
        .flatMap { node in
            node.bounds.map { TKHarmonyLayoutTextMatch(text: text, bounds: $0) }
        }
}
