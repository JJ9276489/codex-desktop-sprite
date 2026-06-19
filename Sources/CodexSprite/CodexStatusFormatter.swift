import Foundation

enum CodexStatusFormatter {
    static func displayText(from status: Any?) -> String? {
        if let text = status as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == "idle" ? nil : trimmed
        }

        guard let status = status as? [String: Any] else {
            return nil
        }

        switch status["type"] as? String {
        case "active":
            return "Codex is working..."
        case "waiting_for_input", "waitingForInput":
            return "Codex needs input in the main app."
        case "idle":
            return nil
        default:
            return nil
        }
    }

    static func isIdle(_ status: Any?) -> Bool {
        if let text = status as? String {
            return text == "idle"
        }

        guard let status = status as? [String: Any] else {
            return false
        }
        return status["type"] as? String == "idle"
    }
}
