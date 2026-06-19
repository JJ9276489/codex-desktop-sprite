import AppKit
import Foundation

private let outputColumns = 8
private let outputRows = 9
private let outputFrameWidth = 192
private let outputFrameHeight = 208
private let outputWidth = outputColumns * outputFrameWidth
private let outputHeight = outputRows * outputFrameHeight

private enum SheetKind: String {
    case standing
    case sitting
}

private struct Manifest: Decodable {
    let frames: [FrameInfo]
}

private struct FrameInfo: Decodable {
    let role: String
    let frame: [Int]
    let bbox: [Int]
}

private struct LoadedSheet {
    let image: NSImage
    let pixelWidth: Int
    let pixelHeight: Int
    let framesByRole: [String: FrameInfo]
}

private struct FrameAssignment {
    let sheet: SheetKind
    let role: String
}

private enum SpriteError: Error, CustomStringConvertible {
    case missingArgument(String)
    case invalidArgument(String)
    case invalidManifest(String)
    case imageLoadFailed(String)
    case frameMissing(sheet: SheetKind, role: String)
    case renderFailed
    case writeFailed(String)

    var description: String {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidArgument(let message):
            return message
        case .invalidManifest(let path):
            return "Invalid sprite manifest: \(path)"
        case .imageLoadFailed(let path):
            return "Could not load sprite image: \(path)"
        case .frameMissing(let sheet, let role):
            return "No frame named \(role) in \(sheet.rawValue) sheet"
        case .renderFailed:
            return "Could not create output bitmap"
        case .writeFailed(let path):
            return "Could not write output PNG: \(path)"
        }
    }
}

private func usage() -> String {
    """
    Usage:
      swift generate_codex_pet_spritesheet.swift \\
        --standing-image path --standing-json path \\
        --sitting-image path --sitting-json path \\
        --output path

    Creates a 1536x1872 Codex custom-pet spritesheet from Lumi's 256px
    standing and sitting orientation sheets.
    """
}

private func parseArguments() throws -> [String: String] {
    var values: [String: String] = [:]
    var index = 1
    let args = CommandLine.arguments

    while index < args.count {
        let key = args[index]
        if key == "--help" || key == "-h" {
            print(usage())
            exit(0)
        }

        guard key.hasPrefix("--") else {
            throw SpriteError.invalidArgument("Unexpected argument: \(key)")
        }

        let nextIndex = index + 1
        guard nextIndex < args.count else {
            throw SpriteError.missingArgument(key)
        }

        values[key] = args[nextIndex]
        index += 2
    }

    for required in ["--standing-image", "--standing-json", "--sitting-image", "--sitting-json", "--output"] {
        if values[required] == nil {
            throw SpriteError.missingArgument(required)
        }
    }

    return values
}

private func loadSheet(imagePath: String, manifestPath: String) throws -> LoadedSheet {
    let manifestURL = URL(fileURLWithPath: manifestPath)
    let data = try Data(contentsOf: manifestURL)
    let manifest: Manifest

    do {
        manifest = try JSONDecoder().decode(Manifest.self, from: data)
    } catch {
        throw SpriteError.invalidManifest(manifestPath)
    }

    guard let image = NSImage(contentsOfFile: imagePath) else {
        throw SpriteError.imageLoadFailed(imagePath)
    }

    var proposedRect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
        throw SpriteError.imageLoadFailed(imagePath)
    }

    image.size = NSSize(width: cgImage.width, height: cgImage.height)

    let framesByRole = Dictionary(uniqueKeysWithValues: manifest.frames.map { ($0.role, $0) })
    return LoadedSheet(
        image: image,
        pixelWidth: cgImage.width,
        pixelHeight: cgImage.height,
        framesByRole: framesByRole
    )
}

private func cycle(_ frames: [FrameAssignment]) -> [FrameAssignment] {
    precondition(!frames.isEmpty)
    return (0..<outputColumns).map { frames[$0 % frames.count] }
}

private func framePlan() -> [[FrameAssignment]] {
    let stand: (String) -> FrameAssignment = { FrameAssignment(sheet: .standing, role: $0) }
    let sit: (String) -> FrameAssignment = { FrameAssignment(sheet: .sitting, role: $0) }

    return [
        // idle
        cycle([
            sit("front_neutral"), sit("front_blink"), sit("front_neutral"), sit("gaze_right"),
            sit("front_neutral"), sit("gaze_left")
        ]),
        // running-right
        cycle([
            stand("gaze_right"), stand("gaze_down_right"), stand("gaze_right"), stand("gaze_up_right")
        ]),
        // running-left
        cycle([
            stand("gaze_left"), stand("gaze_down_left"), stand("gaze_left"), stand("gaze_up_left")
        ]),
        // waving
        cycle([
            stand("front_neutral"), stand("front_blink"), stand("gaze_up_right"), stand("front_neutral")
        ]),
        // jumping
        cycle([
            stand("front_neutral"), stand("gaze_up"), stand("gaze_up_right"), stand("gaze_up"), stand("front_neutral")
        ]),
        // failed
        cycle([
            sit("gaze_down"), sit("gaze_down_left"), sit("gaze_down"), sit("gaze_down_right")
        ]),
        // waiting
        cycle([
            sit("front_neutral"), sit("front_blink"), sit("gaze_down"), sit("front_neutral"), sit("gaze_left"), sit("gaze_right")
        ]),
        // running
        cycle([
            stand("front_neutral"), stand("gaze_right"), stand("front_neutral"), stand("gaze_left"), stand("front_neutral"), stand("front_blink")
        ]),
        // review
        cycle([
            sit("gaze_up"), sit("gaze_up_right"), sit("gaze_up"), sit("gaze_up_left"), sit("front_neutral"), sit("front_blink")
        ])
    ]
}

private func draw(
    assignment: FrameAssignment,
    row: Int,
    column: Int,
    standing: LoadedSheet,
    sitting: LoadedSheet
) throws {
    let sheet = assignment.sheet == .standing ? standing : sitting
    guard let frame = sheet.framesByRole[assignment.role] else {
        throw SpriteError.frameMissing(sheet: assignment.sheet, role: assignment.role)
    }

    guard frame.frame.count == 4, frame.bbox.count == 4 else {
        throw SpriteError.invalidManifest("Frame \(assignment.role) in \(assignment.sheet.rawValue)")
    }

    let frameX = CGFloat(frame.frame[0])
    let frameYTop = CGFloat(frame.frame[1])
    let bboxLeft = CGFloat(frame.bbox[0])
    let bboxTop = CGFloat(frame.bbox[1])
    let bboxRight = CGFloat(frame.bbox[2])
    let bboxBottom = CGFloat(frame.bbox[3])
    let cropWidth = max(1, bboxRight - bboxLeft)
    let cropHeight = max(1, bboxBottom - bboxTop)

    let sourceX = frameX + bboxLeft
    let sourceYTop = frameYTop + bboxTop
    let sourceY = CGFloat(sheet.pixelHeight) - sourceYTop - cropHeight
    let sourceRect = NSRect(x: sourceX, y: sourceY, width: cropWidth, height: cropHeight)

    let maxDrawWidth: CGFloat = 188
    let maxDrawHeight: CGFloat = 202
    let scale = min(maxDrawWidth / cropWidth, maxDrawHeight / cropHeight)
    let drawWidth = floor(cropWidth * scale)
    let drawHeight = floor(cropHeight * scale)

    let cellX = CGFloat(column * outputFrameWidth)
    let cellY = CGFloat(outputHeight - ((row + 1) * outputFrameHeight))
    let destinationX = cellX + floor((CGFloat(outputFrameWidth) - drawWidth) / 2)
    let destinationY = cellY + 3
    let destinationRect = NSRect(x: destinationX, y: destinationY, width: drawWidth, height: drawHeight)

    sheet.image.draw(
        in: destinationRect,
        from: sourceRect,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high.rawValue]
    )
}

private func render(arguments: [String: String]) throws {
    let standing = try loadSheet(
        imagePath: arguments["--standing-image"]!,
        manifestPath: arguments["--standing-json"]!
    )
    let sitting = try loadSheet(
        imagePath: arguments["--sitting-image"]!,
        manifestPath: arguments["--sitting-json"]!
    )

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: outputWidth,
        pixelsHigh: outputHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw SpriteError.renderFailed
    }

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw SpriteError.renderFailed
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    graphicsContext.cgContext.clear(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

    let rows = framePlan()
    for rowIndex in 0..<outputRows {
        for columnIndex in 0..<outputColumns {
            try draw(
                assignment: rows[rowIndex][columnIndex],
                row: rowIndex,
                column: columnIndex,
                standing: standing,
                sitting: sitting
            )
        }
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw SpriteError.renderFailed
    }

    let outputPath = arguments["--output"]!
    let outputURL = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    do {
        try pngData.write(to: outputURL, options: .atomic)
    } catch {
        throw SpriteError.writeFailed(outputPath)
    }
}

do {
    try render(arguments: parseArguments())
} catch let error as SpriteError {
    fputs("error: \(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
