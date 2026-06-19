import Foundation

var passed = 0
var failures: [String] = []

func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        passed += 1
    } else {
        failures.append(name)
        print("FAIL: \(name)")
    }
}

func manifest(at path: String) -> [String: Any] {
    guard
        let data = FileManager.default.contents(atPath: path),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        failures.append("manifest exists: \(path)")
        print("FAIL: manifest exists: \(path)")
        return [:]
    }
    passed += 1
    return object
}

func validateOrientationManifest(_ path: String, name: String) {
    let json = manifest(at: path)
    expect(json["columns"] as? Int == 5, "\(name): has five columns")
    expect(json["rows"] as? Int == 2, "\(name): has two rows")
    expect(json["frameWidth"] as? Int == 256, "\(name): frame width is 256")
    expect(json["frameHeight"] as? Int == 256, "\(name): frame height is 256")

    let roles = json["frameRoles"] as? [String] ?? []
    expect(roles.count == 10, "\(name): has ten gaze frames")
    expect(roles.first == "front_neutral", "\(name): first frame is neutral")
    expect(roles.contains("gaze_left"), "\(name): includes left gaze")
    expect(roles.contains("gaze_right"), "\(name): includes right gaze")
}

expect(AppConfig.appVersion == "0.7.1", "app version is 0.7.1")
expect(AppConfig.bundleIdentifier == "com.github.jj9276489.codexdesktopsprite", "bundle identifier remains stable")

let activeStatus: [String: Any] = [
    "type": "active",
    "activeFlags": ["tool_use", "reasoning"]
]
expect(CodexStatusFormatter.displayText(from: activeStatus) == "Codex is working...", "active status is human-readable")
expect(CodexStatusFormatter.displayText(from: activeStatus)?.contains("activeFlags") == false, "active flags are not leaked to UI")
expect(CodexStatusFormatter.displayText(from: ["type": "idle"]) == nil, "idle status is suppressed")
expect(CodexStatusFormatter.isIdle(["type": "idle"]), "idle dictionary is detected")
expect(CodexStatusFormatter.isIdle("idle"), "idle string is detected")
expect(CodexStatusFormatter.displayText(from: "Indexing workspace") == "Indexing workspace", "plain status strings pass through")

validateOrientationManifest(
    "Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.json",
    name: "standing"
)
validateOrientationManifest(
    "Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.json",
    name: "sitting"
)

expect(
    FileManager.default.fileExists(atPath: "Assets/ChibiAssistant/generated/action-sprites/action-sprites-sheet.png") == false,
    "action sprite sheet is removed"
)
expect(
    FileManager.default.fileExists(atPath: "Assets/ChibiAssistant/sprite-sheet.png") == false,
    "legacy primary sprite sheet is removed"
)

if failures.isEmpty {
    print("All \(passed) CodexSprite tests passed.")
} else {
    print("\(failures.count) failure(s), \(passed) passed.")
    exit(1)
}
