import AppKit

enum SpriteMood {
    case idle
    case listening
    case reading
    case thinking
    case threadActive
    case working
    case success
    case failed
}

struct SpriteSheet {
    let image: NSImage?
    let columns: Int
    let frameSize: Int

    init(relativePath: [String], columns: Int = 5, frameSize: Int = 256) {
        self.columns = columns
        self.frameSize = frameSize

        let resourceURL = relativePath.reduce(Bundle.main.resourceURL) { url, component in
            url?.appendingPathComponent(component)
        }
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let developmentURL = relativePath.reduce(projectURL) { url, component in
            url.appendingPathComponent(component)
        }

        if let resourceURL, let image = Self.loadImage(at: resourceURL) {
            self.image = image
        } else if let image = Self.loadImage(at: developmentURL) {
            self.image = image
        } else {
            self.image = nil
        }
    }

    private static func loadImage(at url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        if let representation = image.representations.first {
            image.size = NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }
        return image
    }
}

private enum StandingFrame: Int {
    case frontNeutral = 0
    case frontBlink = 1
    case gazeUpRight = 2
    case gazeUp = 3
    case gazeUpLeft = 4
    case gazeRight = 5
    case gazeDownRight = 6
    case gazeDown = 7
    case gazeDownLeft = 8
    case gazeLeft = 9
}

private enum SittingFrame: Int {
    case frontNeutral = 0
    case frontBlink = 1
    case gazeUpRight = 2
    case gazeUp = 3
    case gazeUpLeft = 4
    case gazeRight = 5
    case gazeDownRight = 6
    case gazeDown = 7
    case gazeDownLeft = 8
    case gazeLeft = 9
}

private enum GazeDirection {
    case up
    case upRight
    case right
    case downRight
    case down
    case downLeft
    case left
    case upLeft

    var standingFrame: StandingFrame {
        switch self {
        case .up: return .gazeUp
        case .upRight: return .gazeUpRight
        case .right: return .gazeRight
        case .downRight: return .gazeDownRight
        case .down: return .gazeDown
        case .downLeft: return .gazeDownLeft
        case .left: return .gazeLeft
        case .upLeft: return .gazeUpLeft
        }
    }

    var sittingFrame: SittingFrame {
        switch self {
        case .up: return .gazeUp
        case .upRight: return .gazeUpRight
        case .right: return .gazeRight
        case .downRight: return .gazeDownRight
        case .down: return .gazeDown
        case .downLeft: return .gazeDownLeft
        case .left: return .gazeLeft
        case .upLeft: return .gazeUpLeft
        }
    }

    static func from(deltaX: CGFloat, deltaY: CGFloat) -> GazeDirection {
        let degrees = atan2(deltaY, deltaX) * 180 / .pi

        switch degrees {
        case -22.5..<22.5:
            return .right
        case 22.5..<67.5:
            return .upRight
        case 67.5..<112.5:
            return .up
        case 112.5..<157.5:
            return .upLeft
        case 157.5...180, -180..<(-157.5):
            return .left
        case -157.5..<(-112.5):
            return .downLeft
        case -112.5..<(-67.5):
            return .down
        default:
            return .downRight
        }
    }
}

@MainActor
final class SpriteWindowController {
    let window: NSPanel
    private let spriteView: SpriteView

    init(onClick: @escaping () -> Void) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 128, height: 128)
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 28,
            y: visibleFrame.minY + 96
        )

        window = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        window.collectionBehavior = [.ignoresCycle]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false

        spriteView = SpriteView(frame: NSRect(origin: .zero, size: size), onClick: onClick)
        window.contentView = spriteView
    }

    func show() {
        window.orderFrontRegardless()
        spriteView.start()
    }

    func setMood(_ mood: SpriteMood) {
        spriteView.setMood(mood)
    }

    func face(point: NSPoint) {
        spriteView.face(point: point)
    }
}

final class SpriteView: NSView {
    private static let sitAfterTicks = 540
    private static let successFailureTicks = 120

    private let onClick: () -> Void
    private let standingSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "standing-orientations", "standing-orientations-sheet.png"]
    )
    private let sittingSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "sitting-orientations", "sitting-orientations-sheet.png"]
    )

    private var mood: SpriteMood = .idle {
        didSet {
            if oldValue != mood {
                moodTicks = 0
                if mood != .idle {
                    idleTicks = 0
                }
            }
            needsDisplay = true
        }
    }

    private var animationTimer: Timer?
    private var frameTick = 0
    private var moodTicks = 0
    private var idleTicks = 0
    private var gazeDirection: GazeDirection?
    private var greetingTicks = 0
    private var dragInProgress = false
    private var dragged = false
    private var mouseDownLocation: NSPoint = .zero
    private var dragVelocity = CGVector(dx: 0, dy: 0)

    init(frame frameRect: NSRect, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        toolTip = "Ask Codex"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func start() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.frameTick = (self.frameTick + 1) % 1440
            self.moodTicks += 1

            if self.mood == .idle && !self.dragInProgress {
                self.idleTicks += 1
            }
            if self.greetingTicks > 0 {
                self.greetingTicks -= 1
            }
            if (self.mood == .success || self.mood == .failed), self.moodTicks > Self.successFailureTicks {
                self.setMood(.idle)
            }

            self.trackCursor()
            self.needsDisplay = true
        }
    }

    func setMood(_ nextMood: SpriteMood) {
        mood = nextMood
    }

    func face(point: NSPoint) {
        guard let window else { return }
        gazeDirection = GazeDirection.from(deltaX: point.x - window.frame.midX, deltaY: point.y - window.frame.midY)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        dragged = false
        dragInProgress = true
        dragVelocity = CGVector(dx: 0, dy: 0)
        idleTicks = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let location = event.locationInWindow
        let dx = location.x - mouseDownLocation.x
        let dy = location.y - mouseDownLocation.y

        if abs(dx) + abs(dy) > 4 {
            dragged = true
        }
        dragVelocity = CGVector(dx: dx, dy: dy)

        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        frame.origin = clamped(origin: frame.origin, for: window)
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        dragInProgress = false

        if dragged {
            idleTicks = 0
            return
        }

        greetingTicks = 72
        idleTicks = 0
        onClick()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        NSGraphicsContext.current?.shouldAntialias = false

        let drawRect = spriteDrawRect
        drawSpriteShadow(under: drawRect)

        if !drawCurrentFrame(in: drawRect) {
            drawFallbackSprite(in: drawRect)
        }

        if dragInProgress {
            drawDragTrail(around: drawRect)
        }
        if greetingTicks > 0 {
            drawGreetingBubble(around: drawRect)
        } else if shouldShowStatusBubble {
            drawStatusBubble(around: drawRect)
        }
    }

    private func trackCursor() {
        guard let window, !dragInProgress else { return }
        let mouse = NSEvent.mouseLocation
        gazeDirection = GazeDirection.from(deltaX: mouse.x - window.frame.midX, deltaY: mouse.y - window.frame.midY)
    }

    private var isSitting: Bool {
        mood == .idle && greetingTicks == 0 && !dragInProgress && idleTicks >= Self.sitAfterTicks
    }

    private var shouldBlink: Bool {
        let phase = frameTick % 96
        return phase == 0 || phase == 1
    }

    private var spriteDrawRect: NSRect {
        let bobPattern: [CGFloat]
        if dragInProgress {
            bobPattern = [2, 4, 3, 1, -1, 0]
        } else if isSitting {
            bobPattern = [0, 0, 1, 1, 0, 0, -1, -1]
        } else {
            bobPattern = [0, 1, 2, 3, 2, 1, 0, -1]
        }

        let bob = bobPattern[(frameTick / 2) % bobPattern.count]
        let breatheInset: CGFloat = mood == .idle && !dragInProgress && (frameTick / 18) % 2 == 0 ? 1 : 0
        return bounds
            .insetBy(dx: 7 + breatheInset, dy: 7 + breatheInset)
            .offsetBy(dx: 0, dy: bob)
    }

    private func drawCurrentFrame(in rect: NSRect) -> Bool {
        let sheet = isSitting ? sittingSheet : standingSheet
        guard let image = sheet.image else { return false }

        let frameIndex: Int
        if isSitting {
            frameIndex = sittingFrame.rawValue
        } else {
            frameIndex = standingFrame.rawValue
        }

        let col = frameIndex % sheet.columns
        let row = frameIndex / sheet.columns
        let sourceSize = CGFloat(sheet.frameSize)
        let sourceRect = NSRect(
            x: CGFloat(col) * sourceSize,
            y: image.size.height - CGFloat(row + 1) * sourceSize,
            width: sourceSize,
            height: sourceSize
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(
            in: rect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.none]
        )
        NSGraphicsContext.restoreGraphicsState()
        return true
    }

    private var standingFrame: StandingFrame {
        switch mood {
        case .failed:
            return .gazeDown
        case .success:
            return shouldBlink ? .frontBlink : .frontNeutral
        default:
            if shouldBlink && gazeDirection == nil {
                return .frontBlink
            }
            return gazeDirection?.standingFrame ?? (shouldBlink ? .frontBlink : .frontNeutral)
        }
    }

    private var sittingFrame: SittingFrame {
        if shouldBlink && gazeDirection == nil {
            return .frontBlink
        }
        return gazeDirection?.sittingFrame ?? (shouldBlink ? .frontBlink : .frontNeutral)
    }

    private var shouldShowStatusBubble: Bool {
        switch mood {
        case .thinking, .working:
            return moodTicks > 8
        default:
            return false
        }
    }

    private var statusColor: NSColor {
        switch mood {
        case .idle:
            return NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.94, alpha: 1)
        case .listening:
            return NSColor(calibratedRed: 0.32, green: 0.70, blue: 0.96, alpha: 1)
        case .reading:
            return NSColor(calibratedRed: 0.28, green: 0.78, blue: 0.72, alpha: 1)
        case .thinking, .threadActive:
            return NSColor(calibratedRed: 0.58, green: 0.58, blue: 0.96, alpha: 1)
        case .working:
            return NSColor(calibratedRed: 0.96, green: 0.60, blue: 0.20, alpha: 1)
        case .success:
            return NSColor(calibratedRed: 0.29, green: 0.72, blue: 0.42, alpha: 1)
        case .failed:
            return NSColor(calibratedRed: 0.90, green: 0.22, blue: 0.26, alpha: 1)
        }
    }

    private func drawSpriteShadow(under rect: NSRect) {
        let shadowY = bounds.minY + 9
        let lifted = dragInProgress
        let width = rect.width * (lifted ? 0.22 : 0.34)
        let height: CGFloat = lifted ? 4 : 5
        let shadowRect = NSRect(
            x: rect.midX - width / 2,
            y: shadowY,
            width: width,
            height: height
        )

        NSColor.black.withAlphaComponent(0.22).setFill()
        shadowRect.fill()
        NSColor.black.withAlphaComponent(0.10).setFill()
        shadowRect.insetBy(dx: 8, dy: -2).offsetBy(dx: 0, dy: -2).fill()
    }

    private func drawGreetingBubble(around rect: NSRect) {
        drawBubble(
            text: "how can I help?",
            around: rect,
            size: NSSize(width: 110, height: 28),
            textColor: statusColor
        )
    }

    private func drawStatusBubble(around rect: NSRect) {
        let dots = String(repeating: ".", count: 1 + (frameTick / 8) % 3)
        drawBubble(
            text: dots,
            around: rect,
            size: NSSize(width: 38, height: 24),
            textColor: statusColor
        )
    }

    private func drawBubble(text: String, around rect: NSRect, size: NSSize, textColor: NSColor) {
        var origin = NSPoint(
            x: rect.maxX - size.width - 8,
            y: min(bounds.maxY - size.height - 4, rect.maxY - 18)
        )
        origin.x = min(max(bounds.minX + 6, origin.x), bounds.maxX - size.width - 6)
        origin.y = min(max(bounds.minY + 58, origin.y), bounds.maxY - size.height - 4)

        let bubble = NSRect(origin: origin, size: size)
        NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.36, alpha: 0.92).setFill()
        bubble.fill()
        NSRect(x: bubble.minX + 8, y: bubble.minY - 4, width: 8, height: 4).fill()
        NSRect(x: bubble.minX + 10, y: bubble.minY - 8, width: 4, height: 4).fill()

        NSColor.white.withAlphaComponent(0.96).setFill()
        bubble.insetBy(dx: 2, dy: 2).fill()
        NSRect(x: bubble.minX + 10, y: bubble.minY - 2, width: 4, height: 4).fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping

        (text as NSString).draw(
            in: bubble.insetBy(dx: 7, dy: 6),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: text.count <= 3 ? 12 : 8.5, weight: .semibold),
                .foregroundColor: textColor,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func drawDragTrail(around rect: NSRect) {
        let accent = NSColor(calibratedRed: 0.36, green: 0.86, blue: 1.0, alpha: 0.82)
        let vertical = min(CGFloat(8), max(CGFloat(-8), dragVelocity.dy * 0.25))
        let trailingLeft = dragVelocity.dx > 0

        for index in 0..<5 {
            let fade = 0.72 - CGFloat(index) * 0.11
            let x = trailingLeft
                ? rect.minX + CGFloat(12 + index * 10)
                : rect.maxX - CGFloat(12 + index * 10)
            let y = rect.midY - CGFloat(index * 5) - vertical + CGFloat((frameTick + index) % 4)
            drawPixelSquare(x: x, y: y, size: CGFloat(max(2, 5 - index)), color: accent.withAlphaComponent(fade))
        }
    }

    private func drawFallbackSprite(in rect: NSRect) {
        statusColor.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 18, dy: 18)).fill()
        statusColor.setStroke()
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 22, dy: 22))
        ring.lineWidth = 3
        ring.stroke()
    }

    private func drawPixelSquare(x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor) {
        color.setFill()
        NSRect(
            x: round(x),
            y: round(y),
            width: size,
            height: size
        ).fill()
    }

    private func clamped(origin: NSPoint, for window: NSWindow) -> NSPoint {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 12
        let minX = visible.minX + margin
        let maxX = max(minX, visible.maxX - window.frame.width - margin)
        let minY = visible.minY + margin
        let maxY = max(minY, visible.maxY - window.frame.height - margin)

        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }
}
