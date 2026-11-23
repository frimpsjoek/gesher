import AppKit
import Foundation
import GesherPlatform

/// Native Freeform basic shapes (`CRLBasicShapeLibraryShape`).
public enum FreeformShapeKind: String, Sendable, CaseIterable, Codable {
    case rectangle
    case roundedRectangle = "rounded_rectangle"
    case circle
    case triangle
    case rightTriangle = "right_triangle"
    case arrow
    case doubleArrow = "double_arrow"
    case diamond
    case quoteBubble = "quote_bubble"
    case callout
    case pentagon
    case star
    case line
    case lineArrow = "line_arrow"

    public var nativeShapeType: Int {
        switch self {
        case .line: return 1
        case .rectangle: return 3
        case .roundedRectangle: return 4
        case .circle: return 5
        case .triangle: return 6
        case .rightTriangle: return 7
        case .arrow: return 8
        case .doubleArrow: return 9
        case .diamond: return 10
        case .quoteBubble: return 11
        case .callout: return 12
        case .pentagon: return 13
        case .star: return 14
        case .lineArrow: return 16
        }
    }

    public static func parse(_ raw: String) throws -> FreeformShapeKind {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "square", "rect", "rectangle", "box": return .rectangle
        case "rounded_rectangle", "rounded_rect", "rounded": return .roundedRectangle
        case "circle", "oval", "ellipse": return .circle
        default:
            guard let kind = FreeformShapeKind(rawValue: normalized) else {
                let choices = allCases.map(\.rawValue).joined(separator: ", ")
                throw AgentError.invalid("Unknown shape '\(raw)'.", hint: "Supported shapes: \(choices).")
            }
            return kind
        }
    }
}

/// Line and connector endpoint styles (`CRLLineEnd`).
public enum FreeformLineEndKind: String, Sendable, CaseIterable, Codable {
    case none
    case arrow
    case filledArrow = "filled_arrow"
    case openArrow = "open_arrow"
    case invertedArrow = "inverted_arrow"
    case circle
    case openCircle = "open_circle"
    case square
    case openSquare = "open_square"
    case diamond
    case line

    var objcSelector: String {
        switch self {
        case .none: return "none"
        case .arrow: return "simpleArrow"
        case .filledArrow: return "filledArrow"
        case .openArrow: return "openArrow"
        case .invertedArrow: return "invertedArrow"
        case .circle: return "filledCircle"
        case .openCircle: return "openCircle"
        case .square: return "filledSquare"
        case .openSquare: return "openSquare"
        case .diamond: return "filledDiamond"
        case .line: return "line"
        }
    }

    public static func parse(_ raw: String) throws -> FreeformLineEndKind {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        guard let kind = FreeformLineEndKind(rawValue: normalized) else {
            let choices = allCases.map(\.rawValue).joined(separator: ", ")
            throw AgentError.invalid("Unknown line end '\(raw)'.", hint: "Supported line ends: \(choices).")
        }
        return kind
    }
}

/// Stroke dash patterns (`CRLStrokePattern`).
public enum FreeformStrokePatternKind: String, Sendable, CaseIterable, Codable {
    case solid
    case shortDash = "short_dash"
    case dashed
    case longDash = "long_dash"
    case dotted

    var objcSelector: String {
        switch self {
        case .solid: return "solidPattern"
        case .shortDash: return "shortDashPattern"
        case .dashed: return "mediumDashPattern"
        case .longDash: return "longDashPattern"
        case .dotted: return "roundDashPattern"
        }
    }

    public static func parse(_ raw: String) throws -> FreeformStrokePatternKind {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        guard let kind = FreeformStrokePatternKind(rawValue: normalized) else {
            let choices = allCases.map(\.rawValue).joined(separator: ", ")
            throw AgentError.invalid("Unknown stroke pattern '\(raw)'.", hint: "Supported patterns: \(choices).")
        }
        return kind
    }
}

/// Connector routing styles (`CRLConnectionLinePathSource`).
public enum FreeformConnectorStyle: String, Sendable, CaseIterable, Codable {
    case curved
    case straight
    case orthogonal

    var nativeType: Int {
        switch self {
        case .curved: return 0
        case .straight: return 1
        case .orthogonal: return 2
        }
    }

    public static func parse(_ raw: String) throws -> FreeformConnectorStyle {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "elbow", "corner", "orthogonal": return .orthogonal
        default:
            guard let style = FreeformConnectorStyle(rawValue: normalized) else {
                throw AgentError.invalid(
                    "Unknown connector style '\(raw)'.", hint: "Use curved, straight or orthogonal.")
            }
            return style
        }
    }
}

/// Alignment and distribution modes for multiple canvas items.
public enum FreeformAlignMode: String, Sendable, CaseIterable {
    case left
    case center
    case right
    case top
    case middle
    case bottom
    case distributeHorizontal = "distribute_h"
    case distributeVertical = "distribute_v"

    public static func parse(_ raw: String) throws -> FreeformAlignMode {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        guard let mode = FreeformAlignMode(rawValue: normalized) else {
            let choices = allCases.map(\.rawValue).joined(separator: ", ")
            throw AgentError.invalid("Unknown align mode '\(raw)'.", hint: "Supported modes: \(choices).")
        }
        return mode
    }
}

public enum FreeformZOrderTarget: Sendable, Equatable {
    case front
    case back
    case index(Int)

    public static func parse(_ raw: String) throws -> FreeformZOrderTarget {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "front" || trimmed == "top" { return .front }
        if trimmed == "back" || trimmed == "bottom" { return .back }
        guard let index = Int(trimmed), index >= 0 else {
            throw AgentError.invalid(
                "Invalid z-order '\(raw)'.", hint: "Use 'front', 'back' or a non-negative integer index.")
        }
        return .index(index)
    }
}

public enum FreeformTextAlignment: String, Sendable, CaseIterable {
    case left
    case center
    case right
    case justified

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .justified: return .justified
        }
    }

    public static func parse(_ raw: String) throws -> FreeformTextAlignment {
        guard
            let value = FreeformTextAlignment(
                rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        else {
            throw AgentError.invalid("Unknown alignment '\(raw)'.", hint: "Use left, center, right or justified.")
        }
        return value
    }
}

/// Rich text styling applied to text boxes and sticky notes via `NSAttributedString`.
public struct FreeformTextStyle: Sendable {
    public var fontSize: Double?
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var strikethrough: Bool
    public var color: FreeformColor?
    public var alignment: FreeformTextAlignment?

    public init(
        fontSize: Double? = nil, bold: Bool = false, italic: Bool = false, underline: Bool = false,
        strikethrough: Bool = false, color: FreeformColor? = nil, alignment: FreeformTextAlignment? = nil
    ) {
        self.fontSize = fontSize
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.color = color
        self.alignment = alignment
    }

    public var hasStyling: Bool {
        fontSize != nil || bold || italic || underline || strikethrough || color != nil || alignment != nil
    }

    func attributedString(for text: String) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [:]
        let size = CGFloat(fontSize ?? 18)
        var font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        if italic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        attributes[.font] = font
        if underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let color {
            attributes[.foregroundColor] = NSColor(
                srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        }
        let para = NSMutableParagraphStyle()
        if let alignment { para.alignment = alignment.nsAlignment }
        if Self.containsRTL(text) { para.baseWritingDirection = .rightToLeft }
        attributes[.paragraphStyle] = para
        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func containsRTL(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0590...0x05FF).contains(scalar.value) || (0x0600...0x06FF).contains(scalar.value)
        }
    }
}

public struct FreeformTextSpec: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double?
    public var height: Double?
    public var angle: Double
    public var style: FreeformTextStyle?

    public init(
        text: String, x: Double = 100, y: Double = 100, width: Double? = nil, height: Double? = nil, angle: Double = 0,
        style: FreeformTextStyle? = nil
    ) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.angle = angle
        self.style = style
    }
}

public struct FreeformShapeSpec: Sendable {
    public var shape: FreeformShapeKind
    public var text: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var angle: Double
    public var fill: FreeformColor?
    public var stroke: FreeformColor?
    public var strokeWidth: Double
    public var strokePattern: FreeformStrokePatternKind

    public init(
        shape: FreeformShapeKind, text: String? = nil, x: Double = 100, y: Double = 100, width: Double = 220,
        height: Double = 120, angle: Double = 0, fill: FreeformColor? = nil, stroke: FreeformColor? = nil,
        strokeWidth: Double = 2, strokePattern: FreeformStrokePatternKind = .solid
    ) {
        self.shape = shape
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.angle = angle
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.strokePattern = strokePattern
    }
}

public struct FreeformStickySpec: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var angle: Double
    public var fill: FreeformColor?
    public var style: FreeformTextStyle?

    public init(
        text: String, x: Double = 100, y: Double = 100, width: Double = 200, height: Double = 200, angle: Double = 0,
        fill: FreeformColor? = nil, style: FreeformTextStyle? = nil
    ) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.angle = angle
        self.fill = fill
        self.style = style
    }
}

public struct FreeformConnectorSpec: Sendable {
    public var fromID: String
    public var toID: String
    public var style: FreeformConnectorStyle
    public var stroke: FreeformColor
    public var strokeWidth: Double
    public var strokePattern: FreeformStrokePatternKind
    public var headEnd: FreeformLineEndKind
    public var tailEnd: FreeformLineEndKind

    public init(
        fromID: String, toID: String, style: FreeformConnectorStyle = .curved,
        stroke: FreeformColor = FreeformColor(red: 0.25, green: 0.25, blue: 0.28),
        strokeWidth: Double = 2, strokePattern: FreeformStrokePatternKind = .solid,
        headEnd: FreeformLineEndKind = .none, tailEnd: FreeformLineEndKind = .arrow
    ) {
        self.fromID = fromID
        self.toID = toID
        self.style = style
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.strokePattern = strokePattern
        self.headEnd = headEnd
        self.tailEnd = tailEnd
    }
}

public struct FreeformItemUpdateSpec: Sendable {
    public var text: String?
    public var shape: FreeformShapeKind?
    public var description: String?
    public var x: Double?
    public var y: Double?
    public var width: Double?
    public var height: Double?
    public var angle: Double?
    public var fill: FreeformColor?
    public var clearFill: Bool
    public var stroke: FreeformColor?
    public var strokeWidth: Double?
    public var strokePattern: FreeformStrokePatternKind?
    public var clearStroke: Bool
    public var headEnd: FreeformLineEndKind?
    public var tailEnd: FreeformLineEndKind?
    public var locked: Bool?
    public var fromID: String?
    public var toID: String?
    public var zOrder: FreeformZOrderTarget?

    public init(
        text: String? = nil, shape: FreeformShapeKind? = nil, description: String? = nil, x: Double? = nil,
        y: Double? = nil, width: Double? = nil, height: Double? = nil, angle: Double? = nil,
        fill: FreeformColor? = nil, clearFill: Bool = false, stroke: FreeformColor? = nil, strokeWidth: Double? = nil,
        strokePattern: FreeformStrokePatternKind? = nil, clearStroke: Bool = false,
        headEnd: FreeformLineEndKind? = nil, tailEnd: FreeformLineEndKind? = nil, locked: Bool? = nil,
        fromID: String? = nil, toID: String? = nil, zOrder: FreeformZOrderTarget? = nil
    ) {
        self.text = text
        self.shape = shape
        self.description = description
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.angle = angle
        self.fill = fill
        self.clearFill = clearFill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.strokePattern = strokePattern
        self.clearStroke = clearStroke
        self.headEnd = headEnd
        self.tailEnd = tailEnd
        self.locked = locked
        self.fromID = fromID
        self.toID = toID
        self.zOrder = zOrder
    }

    public var isEmpty: Bool {
        text == nil && shape == nil && description == nil && x == nil && y == nil && width == nil && height == nil
            && angle == nil && fill == nil && !clearFill && stroke == nil && strokeWidth == nil
            && strokePattern == nil && !clearStroke && headEnd == nil && tailEnd == nil && locked == nil
            && fromID == nil && toID == nil && zOrder == nil
    }
}

public enum FreeformExportFormat: String, Sendable, CaseIterable {
    case pdf
    case png

    public static func parse(_ raw: String) throws -> FreeformExportFormat {
        guard let fmt = FreeformExportFormat(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        else {
            throw AgentError.invalid("Unknown export format '\(raw)'.", hint: "Use pdf or png.")
        }
        return fmt
    }
}

public struct FreeformTableSpec: Sendable {
    public var rows: Int
    public var columns: Int
    public var cells: [[String]]?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rtl: Bool

    public init(
        rows: Int = 3, columns: Int = 3, cells: [[String]]? = nil, x: Double = 100, y: Double = 100,
        width: Double = 420,
        height: Double = 220, rtl: Bool = false
    ) {
        self.rows = rows
        self.columns = columns
        self.cells = cells
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rtl = rtl
    }
}

public struct FreeformTableSnapshot: Sendable, Equatable {
    public let id: String
    public let rows: Int
    public let columns: Int
    public let rtl: Bool
    public let cells: [[String]]
}

public struct FreeformTableResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let table: FreeformTableSnapshot
}

public struct FreeformSceneSnapshot: Sendable, Equatable {
    public let id: String
    public let name: String?
    public let index: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public struct FreeformExportResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let format: FreeformExportFormat
    public let path: String
    public let bytes: Int
}

public struct FreeformScenesResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let scenes: [FreeformSceneSnapshot]
}

public struct FreeformSceneWriteResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let scene: FreeformSceneSnapshot
}

/// Structured diagram specification for batch authoring.
public struct FreeformDiagramSpec: Decodable, Sendable {
    public struct Node: Decodable, Sendable {
        public var key: String
        public var type: String?
        public var shape: String?
        public var text: String?
        public var x: Double?
        public var y: Double?
        public var width: Double?
        public var height: Double?
        public var angle: Double?
        public var fill: String?
        public var stroke: String?
        public var strokeWidth: Double?
        public var strokePattern: String?
    }

    public struct Edge: Decodable, Sendable {
        public var from: String
        public var to: String
        public var style: String?
        public var stroke: String?
        public var strokeWidth: Double?
        public var strokePattern: String?
        public var headEnd: String?
        public var tailEnd: String?
    }

    public var nodes: [Node]
    public var edges: [Edge]?
    public var direction: String?
    public var originX: Double?
    public var originY: Double?
    public var horizontalGap: Double?
    public var verticalGap: Double?
}

public struct FreeformBoardWriteResult: Sendable {
    public let board: FreeformBoardSnapshot
}

public struct FreeformItemWriteResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let item: FreeformItemSnapshot
}

public struct FreeformItemsWriteResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let items: [FreeformItemSnapshot]
}

public struct FreeformDeleteItemsResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let deletedIDs: [String]
    /// Connectors that were bound to a deleted node and are now unbound or updated on the board.
    public let affectedConnectors: [FreeformItemSnapshot]
}

public struct FreeformDiagramResult: Sendable {
    public let board: FreeformBoardSnapshot
    public let nodes: [String: FreeformItemSnapshot]
    public let edges: [FreeformItemSnapshot]
}

/// High-level native Freeform board writer built on `FreeformNativeBridge`.
/// Enforces app-closed safety, read-only shared-board guards, optimistic concurrency (`ifRevision`),
/// locked-item protection, and fresh readback verification for every write.
public final class FreeformWriter: @unchecked Sendable {
    public let store: FreeformStore
    private let isAppRunning: () -> Bool
    private let hasVisibleWindows: () -> Bool
    private let isAppActive: () -> Bool
    private let liveRefreshEnabled: () -> Bool
    private let terminateApp: () -> Bool
    private let reopenApp: (_ boardID: String?, _ activate: Bool) -> Void
    private let bridgeFactory: () throws -> FreeformNativeBridge
    /// Sync status from the most recent native write (live_refreshed or pending_until_app_launch).
    public private(set) var lastWriteSync: String = "pending_until_app_launch"

    public init(
        store: FreeformStore,
        isAppRunning: @escaping () -> Bool = { FreeformImporter.isAppRunning },
        hasVisibleWindows: @escaping () -> Bool = { FreeformImporter.hasVisibleWindows },
        isAppActive: @escaping () -> Bool = { FreeformImporter.isAppActive },
        liveRefreshEnabled: @escaping () -> Bool = { FreeformImporter.liveRefreshEnabled() },
        terminateApp: @escaping () -> Bool = { FreeformImporter.terminateApp() },
        reopenApp: @escaping (_ boardID: String?, _ activate: Bool) -> Void = { boardID, activate in
            try? FreeformImporter.reopenApp(boardID: boardID, activate: activate)
        },
        bridge: @escaping () throws -> FreeformNativeBridge = { try FreeformNativeBridge.load() }
    ) {
        self.store = store
        self.isAppRunning = isAppRunning
        self.hasVisibleWindows = hasVisibleWindows
        self.isAppActive = isAppActive
        self.liveRefreshEnabled = liveRefreshEnabled
        self.terminateApp = terminateApp
        self.reopenApp = reopenApp
        self.bridgeFactory = bridge
    }

    /// Runs a native write session with seamless Quick Refresh when Freeform has an open window.
    private func withWriteSession<T>(
        reopenBoard: Bool = true,
        boardID: @escaping (T?) -> String? = { _ in nil },
        precheck: ((FreeformStoreLocation) throws -> Void)? = nil,
        _ body: (FreeformStoreLocation) throws -> T
    ) throws -> T {
        let location = try store.requireLocation()
        try precheck?(location)
        var shouldReopen = false
        var wasActive = false
        if isAppRunning() {
            if !hasVisibleWindows() {
                guard terminateApp() else {
                    throw AgentError(
                        code: "app_running",
                        message: "Freeform did not exit cleanly before writing.",
                        hint: "Quit Freeform and retry.")
                }
            } else if liveRefreshEnabled() {
                wasActive = isAppActive()
                guard terminateApp() else {
                    throw AgentError(
                        code: "app_running",
                        message: "Freeform did not exit in time for Quick Refresh.",
                        hint: "Quit Freeform and retry.")
                }
                shouldReopen = true
            } else {
                throw AgentError(
                    code: "app_running",
                    message: "Freeform has an open window; native board writes require Freeform to be closed.",
                    hint: "Close or quit Freeform, or enable Quick Refresh in ~/.config/gesher/config.json.")
            }
        }
        var completed: T?
        defer {
            if shouldReopen {
                reopenApp(reopenBoard ? boardID(completed) : nil, wasActive)
            }
        }
        let result = try body(location)
        completed = result
        lastWriteSync = shouldReopen ? "live_refreshed" : "pending_until_app_launch"
        return result
    }

    private func resolveBoardForWrite(
        _ selector: String, at location: FreeformStoreLocation, includeDeleted: Bool = false,
        ifRevision: String? = nil, exactName: Bool = false
    ) throws -> (board: FreeformBoardSnapshot, uuid: UUID) {
        let board = try store.withSnapshot(location) { snapshot -> FreeformBoardSnapshot in
            let boards = try snapshot.boards(includeDeleted: includeDeleted)
            return try EntityResolver.resolve(
                selector, in: boards, type: "board", id: \.id, name: { $0.title ?? "" },
                detail: { $0.lastActivityAt.map { DateOutput.iso($0) } },
                policy: exactName ? .exactName : .fuzzy)
        }
        guard board.sharing != .participant else {
            throw AgentError(
                code: "read_only",
                message: "'\(board.title ?? board.id)' is shared with you; editing participant boards is refused.",
                hint: "Edit a board you own.")
        }
        if let expected = ifRevision, let actual = board.revision, expected != actual {
            throw AgentError(
                code: "revision_mismatch",
                message:
                    "Board '\(board.title ?? board.id)' changed since revision '\(expected)' (current: '\(actual)').",
                hint: "Read the board again with boards get or items list and retry with the new revision.")
        }
        guard let uuid = UUID(uuidString: board.id) else {
            throw AgentError.notFound("board", board.id)
        }
        return (board, uuid)
    }

    private func withBoardWrite<T>(
        _ selector: String, includeDeleted: Bool = false, ifRevision: String? = nil,
        exactName: Bool = false, reopenBoard: Bool = true,
        _ body: (FreeformStoreLocation, FreeformBoardSnapshot, UUID) throws -> T
    ) throws -> T {
        var resolvedID: String?
        return try withWriteSession(
            reopenBoard: reopenBoard,
            boardID: { _ in resolvedID },
            precheck: { location in
                let (_, uuid) = try self.resolveBoardForWrite(
                    selector, at: location, includeDeleted: includeDeleted, ifRevision: ifRevision,
                    exactName: exactName)
                resolvedID = uuid.uuidString
            },
            { location in
                let (board, uuid) = try self.resolveBoardForWrite(
                    selector, at: location, includeDeleted: includeDeleted, ifRevision: ifRevision,
                    exactName: exactName)
                resolvedID = uuid.uuidString
                return try body(location, board, uuid)
            })
    }

    private func readbackBoard(_ id: String, at location: FreeformStoreLocation, includeDeleted: Bool = false) throws
        -> (board: FreeformBoardSnapshot, items: [FreeformItemSnapshot])
    {
        try store.withSnapshot(location) { snapshot in
            guard let board = try snapshot.boards(includeDeleted: includeDeleted).first(where: { $0.id == id }) else {
                throw PlatformError.mutationUnverified(
                    type: "board", id: id,
                    reason: "Board did not appear on readback; check boards list before retrying.")
            }
            return (board, snapshot.items(board: board))
        }
    }

    private func validateFinite(_ value: Double, name: String, positive: Bool = false) throws {
        guard value.isFinite else {
            throw AgentError.invalid("\(name) must be a finite number.")
        }
        if positive && value <= 0 {
            throw AgentError.invalid("\(name) must be greater than 0.")
        }
    }

    private func requireUnlocked(_ item: AnyObject, id: String, bridge: FreeformNativeBridge, unlocking: Bool = false)
        throws
    {
        if !unlocking && bridge.getBool(item, "locked") {
            throw AgentError(
                code: "item_locked",
                message: "Item '\(id)' is locked and cannot be modified or deleted.",
                hint: "Unlock it first with items update <board> \(id) --locked false.")
        }
    }

    // MARK: - Board Lifecycle

    public func createBoard(title: String) throws -> FreeformBoardWriteResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AgentError.invalid("The board title is empty.") }
        return try withWriteSession(boardID: { $0?.board.id }) { location in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let createdID = try bridge.withStore(at: boardsDir) { nativeStore -> UUID in
                let (board, uuid) = try bridge.createBoard(in: nativeStore, title: trimmed)
                try bridge.saveBoard(board)
                return uuid
            }
            let (readback, _) = try readbackBoard(createdID.uuidString, at: location)
            return FreeformBoardWriteResult(board: readback)
        }
    }

    public func renameBoard(selector: String, title: String, ifRevision: String? = nil) throws
        -> FreeformBoardWriteResult
    {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AgentError.invalid("The new board title is empty.") }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let cc = bridge.makeCommandController(for: board)
                bridge.sendVoidId(board, "setTitle:", trimmed as NSString)
                bridge.enqueue(bridge.makeDirtyBoardCommand(), on: cc)
                try bridge.saveBoard(board)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location)
            guard readback.title == trimmed else {
                throw PlatformError.mutationUnverified(
                    type: "board", id: boardUUID.uuidString,
                    reason: "Title read back as '\(readback.title ?? "")' instead of '\(trimmed)'.")
            }
            return FreeformBoardWriteResult(board: readback)
        }
    }

    public func setBoardFavorite(selector: String, favorite: Bool) throws -> FreeformBoardWriteResult {
        return try withBoardWrite(selector) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                try bridge.setFavorite(in: nativeStore, boardID: boardUUID, favorite: favorite)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location)
            guard readback.favorite == favorite else {
                throw PlatformError.mutationUnverified(
                    type: "board", id: boardUUID.uuidString,
                    reason: "Favorite state did not match expected value after save.")
            }
            return FreeformBoardWriteResult(board: readback)
        }
    }

    public func setBoardAppearance(selector: String, dotGrid: Bool?, connectorMode: Bool?) throws
        -> FreeformBoardWriteResult
    {
        guard dotGrid != nil || connectorMode != nil else {
            throw AgentError.invalid("Specify --dot-grid and/or --connector-mode.")
        }
        return try withBoardWrite(selector) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                if let dotGrid {
                    try bridge.setCanvasDotGrid(in: nativeStore, boardID: boardUUID, visible: dotGrid)
                }
                if let connectorMode {
                    try bridge.setConnectorMode(in: nativeStore, boardID: boardUUID, enabled: connectorMode)
                }
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location)
            return FreeformBoardWriteResult(board: readback)
        }
    }

    public func deleteBoard(selector: String, ifRevision: String? = nil) throws -> FreeformBoardWriteResult {
        return try withBoardWrite(selector, ifRevision: ifRevision, exactName: true, reopenBoard: false) {
            location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                try bridge.deleteBoard(in: nativeStore, boardID: boardUUID)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location, includeDeleted: true)
            guard readback.deleted else {
                throw PlatformError.mutationUnverified(
                    type: "board", id: boardUUID.uuidString,
                    reason: "Board did not move to Recently Deleted on readback.")
            }
            return FreeformBoardWriteResult(board: readback)
        }
    }

    public func restoreBoard(selector: String) throws -> FreeformBoardWriteResult {
        return try withBoardWrite(selector, includeDeleted: true) { location, board, boardUUID in
            guard board.deleted else {
                return FreeformBoardWriteResult(board: board)
            }
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                try bridge.undeleteBoard(in: nativeStore, boardID: boardUUID)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location, includeDeleted: false)
            guard !readback.deleted else {
                throw PlatformError.mutationUnverified(
                    type: "board", id: boardUUID.uuidString, reason: "Board is still in Recently Deleted after restore."
                )
            }
            return FreeformBoardWriteResult(board: readback)
        }
    }

    // MARK: - Native Item Creation

    public func addText(board selector: String, spec: FreeformTextSpec, ifRevision: String? = nil) throws
        -> FreeformItemWriteResult
    {
        guard !spec.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalid("Text box content is empty.")
        }
        try validateFinite(spec.x, name: "x")
        try validateFinite(spec.y, name: "y")
        try validateFinite(spec.angle, name: "angle")
        if let w = spec.width { try validateFinite(w, name: "width", positive: true) }
        if let h = spec.height { try validateFinite(h, name: "height", positive: true) }

        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let createdID = try bridge.withStore(at: boardsDir) { nativeStore -> String in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let factory = bridge.makeFactory(for: board)
                let cc = bridge.makeCommandController(for: board)
                let item: AnyObject
                if let style = spec.style, style.hasStyling {
                    item = bridge.makeAttributedTextbox(
                        factory: factory, attributedText: style.attributedString(for: spec.text))
                } else {
                    item = bridge.makeTextbox(
                        factory: factory, position: CGPoint(x: spec.x, y: spec.y), text: spec.text)
                }
                guard let id = bridge.itemUUIDString(item) else {
                    throw PlatformError.saveFailed("New text box did not have an identifier.")
                }
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [item]), on: cc)
                    let current = bridge.itemGeometryRect(item)
                    let width = spec.width ?? current?.width ?? 220
                    let height = spec.height ?? current?.height ?? 60
                    let geom = bridge.makeGeometry(
                        x: spec.x, y: spec.y, width: width, height: height, angle: spec.angle)
                    bridge.enqueue(bridge.makeSetGeometryCommand(item: item, geometry: geom), on: cc)
                }
                try bridge.saveBoard(board)
                return id
            }
            let (readback, items) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let item = items.first(where: { $0.id == createdID }) else {
                throw PlatformError.mutationUnverified(
                    type: "item", id: createdID,
                    reason: "Text box did not appear on readback; check items list before retrying.")
            }
            return FreeformItemWriteResult(board: readback, item: item)
        }
    }

    public func addShape(board selector: String, spec: FreeformShapeSpec, ifRevision: String? = nil) throws
        -> FreeformItemWriteResult
    {
        try validateFinite(spec.x, name: "x")
        try validateFinite(spec.y, name: "y")
        try validateFinite(spec.width, name: "width", positive: true)
        try validateFinite(spec.height, name: "height", positive: true)
        try validateFinite(spec.angle, name: "angle")
        try validateFinite(spec.strokeWidth, name: "strokeWidth", positive: true)

        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let createdID = try bridge.withStore(at: boardsDir) { nativeStore -> String in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let factory = bridge.makeFactory(for: board)
                let cc = bridge.makeCommandController(for: board)
                let item = bridge.makeShape(factory: factory, shapeType: spec.shape.nativeShapeType)
                guard let id = bridge.itemUUIDString(item) else {
                    throw PlatformError.saveFailed("New shape did not have an identifier.")
                }
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [item]), on: cc)
                    let geom = bridge.makeGeometry(
                        x: spec.x, y: spec.y, width: spec.width, height: spec.height, angle: spec.angle)
                    bridge.enqueue(bridge.makeSetGeometryCommand(item: item, geometry: geom), on: cc)
                    if let fill = spec.fill {
                        bridge.enqueue(
                            bridge.makeSetFillCommand(shapeItem: item, fill: bridge.makeColorFill(fill)), on: cc)
                    }
                    if let stroke = spec.stroke {
                        let nativeStroke = bridge.makeStroke(
                            color: stroke, width: spec.strokeWidth, pattern: spec.strokePattern)
                        bridge.enqueue(bridge.makeSetStrokeCommand(styledItem: item, stroke: nativeStroke), on: cc)
                    }
                    if let text = spec.text, !text.isEmpty {
                        bridge.enqueue(bridge.makeReplaceAllTextCommand(shapeItem: item, text: text), on: cc)
                    }
                }
                try bridge.saveBoard(board)
                return id
            }
            let (readback, items) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let item = items.first(where: { $0.id == createdID }) else {
                throw PlatformError.mutationUnverified(
                    type: "item", id: createdID,
                    reason: "Shape did not appear on readback; check items list before retrying.")
            }
            return FreeformItemWriteResult(board: readback, item: item)
        }
    }

    public func addSticky(board selector: String, spec: FreeformStickySpec, ifRevision: String? = nil) throws
        -> FreeformItemWriteResult
    {
        try validateFinite(spec.x, name: "x")
        try validateFinite(spec.y, name: "y")
        try validateFinite(spec.width, name: "width", positive: true)
        try validateFinite(spec.height, name: "height", positive: true)
        try validateFinite(spec.angle, name: "angle")

        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let createdID = try bridge.withStore(at: boardsDir) { nativeStore -> String in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let factory = bridge.makeFactory(for: board)
                let cc = bridge.makeCommandController(for: board)
                let attributed =
                    spec.style?.attributedString(for: spec.text) ?? NSAttributedString(string: spec.text)
                let item = bridge.makeSticky(factory: factory, attributedText: attributed)
                guard let id = bridge.itemUUIDString(item) else {
                    throw PlatformError.saveFailed("New sticky note did not have an identifier.")
                }
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [item]), on: cc)
                    let geom = bridge.makeGeometry(
                        x: spec.x, y: spec.y, width: spec.width, height: spec.height, angle: spec.angle)
                    bridge.enqueue(bridge.makeSetGeometryCommand(item: item, geometry: geom), on: cc)
                    if let fill = spec.fill {
                        bridge.enqueue(
                            bridge.makeSetFillCommand(shapeItem: item, fill: bridge.makeColorFill(fill)), on: cc)
                    }
                }
                try bridge.saveBoard(board)
                return id
            }
            let (readback, items) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let item = items.first(where: { $0.id == createdID }) else {
                throw PlatformError.mutationUnverified(
                    type: "item", id: createdID,
                    reason: "Sticky note did not appear on readback; check items list before retrying.")
            }
            return FreeformItemWriteResult(board: readback, item: item)
        }
    }

    public func connect(board selector: String, spec: FreeformConnectorSpec, ifRevision: String? = nil) throws
        -> FreeformItemWriteResult
    {
        guard spec.fromID.caseInsensitiveCompare(spec.toID) != .orderedSame else {
            throw AgentError.invalid("A connector cannot connect an item to itself.")
        }
        guard let fromUUID = UUID(uuidString: spec.fromID) else {
            throw AgentError.invalid("Invalid 'from' item id '\(spec.fromID)'.")
        }
        guard let toUUID = UUID(uuidString: spec.toID) else {
            throw AgentError.invalid("Invalid 'to' item id '\(spec.toID)'.")
        }
        try validateFinite(spec.strokeWidth, name: "strokeWidth", positive: true)

        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let createdID = try bridge.withStore(at: boardsDir) { nativeStore -> String in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let rootID = bridge.getObject(root, "id")!
                guard let fromItem = bridge.getObjectArg(board, "getBoardItemForUUID:", fromUUID as NSUUID) else {
                    throw AgentError.notFound("item", spec.fromID)
                }
                guard let toItem = bridge.getObjectArg(board, "getBoardItemForUUID:", toUUID as NSUUID) else {
                    throw AgentError.notFound("item", spec.toID)
                }
                let cc = bridge.makeCommandController(for: board)
                let geom = connectorGeometry(from: fromItem, to: toItem, bridge: bridge)
                let stroke = bridge.makeStroke(color: spec.stroke, width: spec.strokeWidth, pattern: spec.strokePattern)
                let headEnd = bridge.makeLineEnd(spec.headEnd)
                let tailEnd = bridge.makeLineEnd(spec.tailEnd)
                let connector = bridge.makeConnectionLine(
                    store: nativeStore, rootContainerID: rootID, geometry: geom, style: spec.style, stroke: stroke,
                    headLineEnd: headEnd, tailLineEnd: tailEnd)
                guard let id = bridge.itemUUIDString(connector) else {
                    throw PlatformError.saveFailed("New connector did not have an identifier.")
                }
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [connector]), on: cc)
                    bridge.enqueue(
                        bridge.makeSetConnectionCommand(connector: connector, targetItem: fromItem, chirality: 0),
                        on: cc)
                    bridge.enqueue(
                        bridge.makeSetConnectionCommand(connector: connector, targetItem: toItem, chirality: 1), on: cc)
                }
                try bridge.saveBoard(board)
                return id
            }
            let (readback, items) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let item = items.first(where: { $0.id == createdID }) else {
                throw PlatformError.mutationUnverified(
                    type: "connector", id: createdID,
                    reason: "Connector did not appear on readback; check items list before retrying.")
            }
            return FreeformItemWriteResult(board: readback, item: item)
        }
    }

    // MARK: - Item Update, Delete, Duplicate, Group, Align

    public func updateItem(
        board selector: String, itemID: String, spec: FreeformItemUpdateSpec, ifRevision: String? = nil
    ) throws -> FreeformItemWriteResult {
        guard !spec.isEmpty else {
            throw AgentError.invalid("No fields specified to update.")
        }
        guard let targetUUID = UUID(uuidString: itemID) else {
            throw AgentError.invalid("Invalid item id '\(itemID)'.")
        }
        if let x = spec.x { try validateFinite(x, name: "x") }
        if let y = spec.y { try validateFinite(y, name: "y") }
        if let w = spec.width { try validateFinite(w, name: "width", positive: true) }
        if let h = spec.height { try validateFinite(h, name: "height", positive: true) }
        if let a = spec.angle { try validateFinite(a, name: "angle") }
        if let sw = spec.strokeWidth { try validateFinite(sw, name: "strokeWidth", positive: true) }

        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                guard let item = bridge.getObjectArg(board, "getBoardItemForUUID:", targetUUID as NSUUID) else {
                    throw AgentError.notFound("item", itemID)
                }
                try requireUnlocked(item, id: itemID, bridge: bridge, unlocking: spec.locked == false)
                let cc = bridge.makeCommandController(for: board)
                try bridge.withCommandGroup(on: cc) {
                    if spec.locked == false {
                        bridge.enqueue(bridge.makeSetLockedCommand(item: item, locked: false), on: cc)
                    }
                    if spec.x != nil || spec.y != nil || spec.width != nil || spec.height != nil || spec.angle != nil {
                        let current = bridge.itemGeometryRect(item) ?? (0, 0, 200, 100, 0)
                        let geom = bridge.makeGeometry(
                            x: spec.x ?? current.x, y: spec.y ?? current.y,
                            width: spec.width ?? current.width, height: spec.height ?? current.height,
                            angle: spec.angle ?? current.angle)
                        bridge.enqueue(bridge.makeSetGeometryCommand(item: item, geometry: geom), on: cc)
                    }
                    if let text = spec.text {
                        guard item.responds(to: NSSelectorFromString("textStorage")) else {
                            throw AgentError.invalid(
                                "Item '\(itemID)' does not support text editing.",
                                hint: "Only text boxes, shapes and sticky notes hold editable text.")
                        }
                        bridge.enqueue(bridge.makeReplaceAllTextCommand(shapeItem: item, text: text), on: cc)
                    }
                    if let newShape = spec.shape {
                        guard item.responds(to: NSSelectorFromString("allowsChangeShape")),
                            bridge.getBool(item, "allowsChangeShape")
                        else {
                            throw AgentError.invalid("Item '\(itemID)' does not support replacing its shape.")
                        }
                        let factory = bridge.makeFactory(for: board)
                        let template = bridge.makeShape(factory: factory, shapeType: newShape.nativeShapeType)
                        guard let pathSource = bridge.getObject(template, "pathSource") else {
                            throw PlatformError.saveFailed(
                                "Could not build path source for shape '\(newShape.rawValue)'.")
                        }
                        bridge.enqueue(bridge.makeSetPathSourceCommand(shapeItem: item, pathSource: pathSource), on: cc)
                    }
                    if let description = spec.description {
                        bridge.enqueue(bridge.makeSetDescriptionCommand(item: item, description: description), on: cc)
                    }
                    if spec.clearFill {
                        guard item.responds(to: NSSelectorFromString("supportsFill")) else {
                            throw AgentError.invalid("Item '\(itemID)' does not support fill.")
                        }
                        bridge.enqueue(bridge.makeSetFillCommand(shapeItem: item, fill: nil), on: cc)
                    } else if let fill = spec.fill {
                        guard item.responds(to: NSSelectorFromString("supportsFill")) else {
                            throw AgentError.invalid("Item '\(itemID)' does not support fill.")
                        }
                        bridge.enqueue(
                            bridge.makeSetFillCommand(shapeItem: item, fill: bridge.makeColorFill(fill)), on: cc)
                    }
                    if spec.clearStroke {
                        guard item.responds(to: NSSelectorFromString("stroke")) else {
                            throw AgentError.invalid("Item '\(itemID)' does not support stroke.")
                        }
                        bridge.enqueue(
                            bridge.makeSetStrokeCommand(styledItem: item, stroke: bridge.makeEmptyStroke()), on: cc)
                    } else if spec.stroke != nil || spec.strokeWidth != nil || spec.strokePattern != nil {
                        guard item.responds(to: NSSelectorFromString("stroke")) else {
                            throw AgentError.invalid("Item '\(itemID)' does not support stroke.")
                        }
                        let color = spec.stroke ?? FreeformColor(red: 0.25, green: 0.25, blue: 0.28)
                        let width = spec.strokeWidth ?? 2
                        let pattern = spec.strokePattern ?? .solid
                        let stroke = bridge.makeStroke(color: color, width: width, pattern: pattern)
                        bridge.enqueue(bridge.makeSetStrokeCommand(styledItem: item, stroke: stroke), on: cc)
                    }
                    if let headEnd = spec.headEnd {
                        guard item.responds(to: NSSelectorFromString("headLineEnd")) else {
                            throw AgentError.invalid("Item '\(itemID)' does not support line ends.")
                        }
                        bridge.enqueue(
                            bridge.makeSetLineEndCommand(
                                shapeItem: item, lineEnd: bridge.makeLineEnd(headEnd), chirality: 0), on: cc)
                    }
                    if let tailEnd = spec.tailEnd {
                        guard item.responds(to: NSSelectorFromString("tailLineEnd")) else {
                            throw AgentError.invalid("Item '\(itemID)' does not support line ends.")
                        }
                        bridge.enqueue(
                            bridge.makeSetLineEndCommand(
                                shapeItem: item, lineEnd: bridge.makeLineEnd(tailEnd), chirality: 1), on: cc)
                    }
                    if let fromID = spec.fromID {
                        guard item.responds(to: NSSelectorFromString("setConnectedFrom:")) else {
                            throw AgentError.invalid("Item '\(itemID)' is not a connector.")
                        }
                        guard let fromUUID = UUID(uuidString: fromID),
                            let target = bridge.getObjectArg(board, "getBoardItemForUUID:", fromUUID as NSUUID)
                        else { throw AgentError.notFound("item", fromID) }
                        bridge.enqueue(
                            bridge.makeSetConnectionCommand(connector: item, targetItem: target, chirality: 0), on: cc)
                    }
                    if let toID = spec.toID {
                        guard item.responds(to: NSSelectorFromString("setConnectedTo:")) else {
                            throw AgentError.invalid("Item '\(itemID)' is not a connector.")
                        }
                        guard let toUUID = UUID(uuidString: toID),
                            let target = bridge.getObjectArg(board, "getBoardItemForUUID:", toUUID as NSUUID)
                        else { throw AgentError.notFound("item", toID) }
                        bridge.enqueue(
                            bridge.makeSetConnectionCommand(connector: item, targetItem: target, chirality: 1), on: cc)
                    }
                    if let zTarget = spec.zOrder {
                        let parent =
                            bridge.getObject(item, "parentContainerItem") ?? bridge.getObject(board, "rootContainer")!
                        let children = (bridge.getObject(parent, "childItems") as? [AnyObject]) ?? []
                        let maxIndex = max(children.count - 1, 0)
                        let targetIndex: Int
                        switch zTarget {
                        case .back: targetIndex = 0
                        case .front: targetIndex = maxIndex
                        case .index(let idx): targetIndex = min(max(idx, 0), maxIndex)
                        }
                        bridge.enqueue(
                            bridge.makeReorderCommand(
                                parentContainer: parent, children: [item], targetIndices: IndexSet(integer: targetIndex)
                            ),
                            on: cc)
                    }
                    if spec.locked == true {
                        bridge.enqueue(bridge.makeSetLockedCommand(item: item, locked: true), on: cc)
                    }
                }
                try bridge.saveBoard(board)
            }
            let (readback, items) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let updated = items.first(where: { $0.id == targetUUID.uuidString }) else {
                throw PlatformError.mutationUnverified(
                    type: "item", id: targetUUID.uuidString, reason: "Updated item was missing on readback.")
            }
            return FreeformItemWriteResult(board: readback, item: updated)
        }
    }

    // MARK: - Native Tables, Export & Scenes

    public func addTable(board selector: String, spec: FreeformTableSpec, ifRevision: String? = nil) throws
        -> FreeformItemWriteResult
    {
        let effectiveRows = max(spec.cells?.count ?? spec.rows, 1)
        let effectiveCols = max(spec.cells?.map(\.count).max() ?? spec.columns, 1)
        guard (1...50).contains(effectiveRows), (1...25).contains(effectiveCols) else {
            throw AgentError.invalid("Table dimensions must be between 1x1 and 50x25.")
        }
        try validateFinite(spec.x, name: "x")
        try validateFinite(spec.y, name: "y")
        try validateFinite(spec.width, name: "width", positive: true)
        try validateFinite(spec.height, name: "height", positive: true)

        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let cellGrid =
                spec.cells ?? Array(repeating: Array(repeating: "", count: effectiveCols), count: effectiveRows)
            let createdID = try bridge.withStore(at: boardsDir) { nativeStore -> String in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let factory = bridge.makeFactory(for: board)
                let cc = bridge.makeCommandController(for: board)
                let geom = bridge.makeGeometry(x: spec.x, y: spec.y, width: spec.width, height: spec.height)
                let table = try bridge.makePopulatedTable(
                    factory: factory, cells: cellGrid, geometry: geom, rtl: spec.rtl)
                guard let id = bridge.itemUUIDString(table) else {
                    throw PlatformError.saveFailed("New table did not have an identifier.")
                }
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [table]), on: cc)
                }
                try bridge.saveBoard(board)
                return id
            }
            let (readback, items) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let item = items.first(where: { $0.id == createdID }) else {
                throw PlatformError.mutationUnverified(
                    type: "table", id: createdID, reason: "Table did not appear on readback.")
            }
            return FreeformItemWriteResult(board: readback, item: item)
        }
    }

    /// Reads the rows, columns and cell contents of a table item on a read-only copy of the store.
    public func getTable(board selector: String, itemID: String) throws -> FreeformTableResult {
        guard let tableUUID = UUID(uuidString: itemID) else {
            throw AgentError.invalid("Invalid table item UUID '\(itemID)'.")
        }
        let location = try store.requireLocation()
        let board = try store.withSnapshot(location) { snapshot in
            try EntityResolver.resolve(
                selector, in: try snapshot.boards(includeDeleted: true), type: "board", id: \.id,
                name: { $0.title ?? "" }, detail: { $0.lastActivityAt.map { DateOutput.iso($0) } })
        }
        guard let boardUUID = UUID(uuidString: board.id) else {
            throw AgentError.notFound("board", board.id)
        }
        let bridge = try bridgeFactory()
        let snapshot = try withReadOnlyStoreCopy(at: location) { copyDir in
            try bridge.withStore(at: copyDir) { nativeStore in
                let nativeBoard = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                guard let item = bridge.getObjectArg(nativeBoard, "getBoardItemForUUID:", tableUUID as NSUUID) else {
                    throw AgentError.notFound("table", itemID)
                }
                guard item.responds(to: NSSelectorFromString("rowCount")) else {
                    throw AgentError.invalid("Item '\(itemID)' is not a table.")
                }
                return bridge.readTable(item)
            }
        }
        return FreeformTableResult(board: board, table: snapshot)
    }

    /// Updates a single cell's text inside an existing Freeform table in place (preserves table UUID).
    public func setTableCell(
        board selector: String, itemID: String, row: Int, column: Int, text: String, ifRevision: String? = nil
    ) throws -> FreeformTableResult {
        guard let tableUUID = UUID(uuidString: itemID) else {
            throw AgentError.invalid("Invalid table item UUID '\(itemID)'.")
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let updatedTable = try bridge.withStore(at: boardsDir) { nativeStore -> FreeformTableSnapshot in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                guard let item = bridge.getObjectArg(board, "getBoardItemForUUID:", tableUUID as NSUUID) else {
                    throw AgentError.notFound("table", itemID)
                }
                guard item.responds(to: NSSelectorFromString("rowCount")) else {
                    throw AgentError.invalid("Item '\(itemID)' is not a table.")
                }
                try requireUnlocked(item, id: itemID, bridge: bridge)
                let cmd = try bridge.makeSetTableCellCommand(tableItem: item, row: row, column: column, text: text)
                let cc = bridge.makeCommandController(for: board)
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(cmd, on: cc)
                }
                try bridge.saveBoard(board)
                return bridge.readTable(item)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location)
            return FreeformTableResult(board: readback, table: updatedTable)
        }
    }

    /// Copies the store to a temporary directory and renders a board via Freeform's own `CRLCanvasImager`
    /// (works read-only even while Freeform.app is running).
    public func exportBoard(board selector: String, format: FreeformExportFormat, outputPath: String) throws
        -> FreeformExportResult
    {
        let dest = URL(fileURLWithPath: (outputPath as NSString).expandingTildeInPath).standardizedFileURL
        let location = try store.requireLocation()
        let board = try store.withSnapshot(location) { snapshot in
            try EntityResolver.resolve(
                selector, in: try snapshot.boards(includeDeleted: true), type: "board", id: \.id,
                name: { $0.title ?? "" }, detail: { $0.lastActivityAt.map { DateOutput.iso($0) } })
        }
        guard let boardUUID = UUID(uuidString: board.id) else {
            throw AgentError.notFound("board", board.id)
        }
        let bridge = try bridgeFactory()
        let data = try withReadOnlyStoreCopy(at: location) { copyDir in
            try bridge.withStore(at: copyDir) { nativeStore in
                let nativeBoard = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                return try bridge.renderBoard(nativeBoard, format: format)
            }
        }
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: dest, options: .atomic)
        return FreeformExportResult(board: board, format: format, path: dest.path, bytes: data.count)
    }

    /// Lists scenes on a board using a read-only copy of the store (works even while Freeform.app is running).
    public func listScenes(board selector: String) throws -> FreeformScenesResult {
        let location = try store.requireLocation()
        let board = try store.withSnapshot(location) { snapshot in
            try EntityResolver.resolve(
                selector, in: try snapshot.boards(includeDeleted: true), type: "board", id: \.id,
                name: { $0.title ?? "" }, detail: { $0.lastActivityAt.map { DateOutput.iso($0) } })
        }
        guard let boardUUID = UUID(uuidString: board.id) else {
            throw AgentError.notFound("board", board.id)
        }
        let bridge = try bridgeFactory()
        let scenes = try withReadOnlyStoreCopy(at: location) { copyDir in
            try bridge.withStore(at: copyDir) { nativeStore in
                let nativeBoard = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                return bridge.listScenes(on: nativeBoard)
            }
        }
        return FreeformScenesResult(board: board, scenes: scenes)
    }

    public func createScene(
        board selector: String, name: String?, x: Double, y: Double, width: Double, height: Double,
        ifRevision: String? = nil
    ) throws -> FreeformSceneWriteResult {
        try validateFinite(x, name: "x")
        try validateFinite(y, name: "y")
        try validateFinite(width, name: "width", positive: true)
        try validateFinite(height, name: "height", positive: true)
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let sceneUUID = UUID()
            let scenes = try bridge.withStore(at: boardsDir) { nativeStore -> [FreeformSceneSnapshot] in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let cc = bridge.makeCommandController(for: board)
                try bridge.createScene(
                    on: board, id: sceneUUID, rect: CGRect(x: x, y: y, width: width, height: height), name: name)
                bridge.enqueue(bridge.makeDirtyBoardCommand(), on: cc)
                try bridge.saveBoard(board)
                return bridge.listScenes(on: board)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let created = scenes.first(where: { $0.id == sceneUUID.uuidString }) else {
                throw PlatformError.mutationUnverified(
                    type: "scene", id: sceneUUID.uuidString, reason: "Scene did not appear after save.")
            }
            return FreeformSceneWriteResult(board: readback, scene: created)
        }
    }

    public func updateScene(
        board selector: String, sceneID: String, name: String?, x: Double?, y: Double?, width: Double?,
        height: Double?, ifRevision: String? = nil
    ) throws -> FreeformSceneWriteResult {
        guard let sceneUUID = UUID(uuidString: sceneID) else {
            throw AgentError.invalid("Invalid scene UUID '\(sceneID)'.")
        }
        guard name != nil || x != nil || y != nil || width != nil || height != nil else {
            throw AgentError.invalid("Specify --name or geometry (--x/--y/--width/--height) to update a scene.")
        }
        if let x { try validateFinite(x, name: "x") }
        if let y { try validateFinite(y, name: "y") }
        if let width { try validateFinite(width, name: "width", positive: true) }
        if let height { try validateFinite(height, name: "height", positive: true) }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let scenes = try bridge.withStore(at: boardsDir) { nativeStore -> [FreeformSceneSnapshot] in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let existing = bridge.listScenes(on: board)
                guard let current = existing.first(where: { $0.id == sceneUUID.uuidString }) else {
                    throw AgentError.notFound("scene", sceneID)
                }
                let cc = bridge.makeCommandController(for: board)
                if let name {
                    _ = bridge.setSceneName(on: board, id: sceneUUID, name: name)
                }
                if x != nil || y != nil || width != nil || height != nil {
                    let rect = CGRect(
                        x: x ?? current.x, y: y ?? current.y, width: width ?? current.width,
                        height: height ?? current.height)
                    _ = bridge.setSceneRect(on: board, id: sceneUUID, rect: rect)
                }
                bridge.enqueue(bridge.makeDirtyBoardCommand(), on: cc)
                try bridge.saveBoard(board)
                return bridge.listScenes(on: board)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let updated = scenes.first(where: { $0.id == sceneUUID.uuidString }) else {
                throw PlatformError.mutationUnverified(
                    type: "scene", id: sceneUUID.uuidString, reason: "Updated scene was missing on readback.")
            }
            return FreeformSceneWriteResult(board: readback, scene: updated)
        }
    }

    public func deleteScene(board selector: String, sceneID: String, ifRevision: String? = nil) throws
        -> FreeformBoardWriteResult
    {
        guard let sceneUUID = UUID(uuidString: sceneID) else {
            throw AgentError.invalid("Invalid scene UUID '\(sceneID)'.")
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let existing = bridge.listScenes(on: board)
                guard existing.contains(where: { $0.id == sceneUUID.uuidString }) else {
                    throw AgentError.notFound("scene", sceneID)
                }
                let cc = bridge.makeCommandController(for: board)
                guard bridge.deleteScene(on: board, id: sceneUUID) else {
                    throw PlatformError.saveFailed("Freeform failed to delete scene \(sceneID).")
                }
                bridge.enqueue(bridge.makeDirtyBoardCommand(), on: cc)
                try bridge.saveBoard(board)
            }
            let (readback, _) = try readbackBoard(boardUUID.uuidString, at: location)
            return FreeformBoardWriteResult(board: readback)
        }
    }

    private func withReadOnlyStoreCopy<T>(at location: FreeformStoreLocation, _ body: (URL) throws -> T) throws -> T {
        let fm = FileManager.default
        let copyDir = fm.temporaryDirectory.appendingPathComponent(
            "gesher-freeform-ro-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: copyDir, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: copyDir) }
        let srcDir = location.database.deletingLastPathComponent()
        for name in ["boards.db", "boards.db-wal", "boards.db-shm", "side.db", "side.db-wal", "side.db-shm"] {
            let src = srcDir.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                try fm.copyItem(at: src, to: copyDir.appendingPathComponent(name))
            }
        }
        return try body(copyDir)
    }

    public func deleteItems(board selector: String, itemIDs: [String], ifRevision: String? = nil) throws
        -> FreeformDeleteItemsResult
    {
        guard !itemIDs.isEmpty else { throw AgentError.invalid("Pass at least one item id to delete.") }
        let uuids = try itemIDs.map { id -> UUID in
            guard let uuid = UUID(uuidString: id) else {
                throw AgentError.invalid("Invalid item id '\(id)'.")
            }
            return uuid
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let beforeItems = try store.withSnapshot(location) { snapshot -> [FreeformItemSnapshot] in
                guard
                    let board = try snapshot.boards(includeDeleted: false).first(where: {
                        $0.id == boardUUID.uuidString
                    })
                else { return [] }
                return snapshot.items(board: board)
            }
            let targetSet = Set(uuids.map(\.uuidString))
            let boundConnectorIDs = Set(
                beforeItems.filter {
                    $0.kind == .connector && !targetSet.contains($0.id)
                        && (targetSet.contains($0.connectedFrom ?? "") || targetSet.contains($0.connectedTo ?? ""))
                }.map(\.id))

            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                var itemsToDelete: [AnyObject] = []
                for uuid in uuids {
                    guard let item = bridge.getObjectArg(board, "getBoardItemForUUID:", uuid as NSUUID) else {
                        throw AgentError.notFound("item", uuid.uuidString)
                    }
                    try requireUnlocked(item, id: uuid.uuidString, bridge: bridge)
                    itemsToDelete.append(item)
                }
                let cc = bridge.makeCommandController(for: board)
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeDeleteCommand(items: itemsToDelete), on: cc)
                }
                try bridge.saveBoard(board)
            }
            let (readback, remaining) = try readbackBoard(boardUUID.uuidString, at: location)
            let remainingSet = Set(remaining.map(\.id))
            if let stillThere = uuids.first(where: { remainingSet.contains($0.uuidString) }) {
                throw PlatformError.mutationUnverified(
                    type: "item", id: stillThere.uuidString, reason: "Item is still present after delete.")
            }
            let affected = remaining.filter { boundConnectorIDs.contains($0.id) }
            return FreeformDeleteItemsResult(
                board: readback, deletedIDs: uuids.map(\.uuidString), affectedConnectors: affected)
        }
    }

    public func duplicateItems(
        board selector: String, itemIDs: [String], dx: Double = 24, dy: Double = 24, ifRevision: String? = nil
    ) throws -> FreeformItemsWriteResult {
        guard !itemIDs.isEmpty else { throw AgentError.invalid("Pass at least one item id to duplicate.") }
        try validateFinite(dx, name: "dx")
        try validateFinite(dy, name: "dy")
        let uuids = try itemIDs.map { id -> UUID in
            guard let uuid = UUID(uuidString: id) else { throw AgentError.invalid("Invalid item id '\(id)'.") }
            return uuid
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let newIDs = try bridge.withStore(at: boardsDir) { nativeStore -> [String] in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let factory = bridge.makeFactory(for: board)
                let cc = bridge.makeCommandController(for: board)
                let originals: [AnyObject] = try uuids.map { uuid in
                    guard let item = bridge.getObjectArg(board, "getBoardItemForUUID:", uuid as NSUUID) else {
                        throw AgentError.notFound("item", uuid.uuidString)
                    }
                    return item
                }
                let duplicates = bridge.duplicateBoardItems(factory: factory, items: originals)
                guard !duplicates.isEmpty else {
                    throw PlatformError.saveFailed("Freeform did not create duplicate items.")
                }
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: duplicates), on: cc)
                    if dx != 0 || dy != 0 {
                        for dup in duplicates {
                            if let rect = bridge.itemGeometryRect(dup) {
                                let moved = bridge.makeGeometry(
                                    x: rect.x + dx, y: rect.y + dy, width: rect.width, height: rect.height,
                                    angle: rect.angle)
                                bridge.enqueue(bridge.makeSetGeometryCommand(item: dup, geometry: moved), on: cc)
                            }
                        }
                    }
                }
                try bridge.saveBoard(board)
                return duplicates.compactMap { bridge.itemUUIDString($0) }
            }
            let (readback, allItems) = try readbackBoard(boardUUID.uuidString, at: location)
            let byID = Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let created = newIDs.compactMap { byID[$0] }
            guard created.count == newIDs.count else {
                throw PlatformError.mutationUnverified(
                    type: "item", id: newIDs.first ?? boardUUID.uuidString,
                    reason: "Not all duplicated items appeared on readback.")
            }
            return FreeformItemsWriteResult(board: readback, items: created)
        }
    }

    public func groupItems(board selector: String, itemIDs: [String], ifRevision: String? = nil) throws
        -> FreeformItemWriteResult
    {
        guard itemIDs.count >= 2 else {
            throw AgentError.invalid("Grouping requires at least two item ids.")
        }
        let uuids = try itemIDs.map { id -> UUID in
            guard let uuid = UUID(uuidString: id) else { throw AgentError.invalid("Invalid item id '\(id)'.") }
            return uuid
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let groupID = try bridge.withStore(at: boardsDir) { nativeStore -> String in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let factory = bridge.makeFactory(for: board)
                let cc = bridge.makeCommandController(for: board)
                let targets: [AnyObject] = try uuids.map { uuid in
                    guard let item = bridge.getObjectArg(board, "getBoardItemForUUID:", uuid as NSUUID) else {
                        throw AgentError.notFound("item", uuid.uuidString)
                    }
                    try requireUnlocked(item, id: uuid.uuidString, bridge: bridge)
                    return item
                }
                let group = try bridge.makeGroup(factory: factory, items: targets)
                guard let id = bridge.itemUUIDString(group) else {
                    throw PlatformError.saveFailed("New group did not have an identifier.")
                }
                bridge.withCommandGroup(on: cc) {
                    bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [group]), on: cc)
                    bridge.enqueue(bridge.makeReparentCommand(destinationContainer: group, items: targets), on: cc)
                }
                try bridge.saveBoard(board)
                return id
            }
            let (readback, allItems) = try readbackBoard(boardUUID.uuidString, at: location)
            guard let groupItem = allItems.first(where: { $0.id == groupID }) else {
                throw PlatformError.mutationUnverified(
                    type: "group", id: groupID, reason: "New group did not appear on readback.")
            }
            return FreeformItemWriteResult(board: readback, item: groupItem)
        }
    }

    public func ungroupItem(board selector: String, groupID: String, ifRevision: String? = nil) throws
        -> FreeformItemsWriteResult
    {
        guard let groupUUID = UUID(uuidString: groupID) else {
            throw AgentError.invalid("Invalid group id '\(groupID)'.")
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            let childIDs = try bridge.withStore(at: boardsDir) { nativeStore -> [String] in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                guard let group = bridge.getObjectArg(board, "getBoardItemForUUID:", groupUUID as NSUUID) else {
                    throw AgentError.notFound("group", groupID)
                }
                guard group.responds(to: NSSelectorFromString("ungroupedGeometryForChildItem:")) else {
                    throw AgentError.invalid("Item '\(groupID)' is not a group.")
                }
                try requireUnlocked(group, id: groupID, bridge: bridge)
                let children = (bridge.getObject(group, "childItems") as? [AnyObject]) ?? []
                let dest = bridge.getObject(group, "parentContainerItem") ?? root
                let cc = bridge.makeCommandController(for: board)
                let ungroupedGeoms: [(AnyObject, AnyObject)] = children.compactMap { child in
                    bridge.ungroupedGeometry(group: group, child: child).map { (child, $0) }
                }
                bridge.withCommandGroup(on: cc) {
                    if !children.isEmpty {
                        bridge.enqueue(bridge.makeReparentCommand(destinationContainer: dest, items: children), on: cc)
                        for (child, geom) in ungroupedGeoms {
                            bridge.enqueue(bridge.makeSetGeometryCommand(item: child, geometry: geom), on: cc)
                        }
                    }
                    bridge.enqueue(bridge.makeDeleteCommand(items: [group]), on: cc)
                }
                try bridge.saveBoard(board)
                return children.compactMap { bridge.itemUUIDString($0) }
            }
            let (readback, allItems) = try readbackBoard(boardUUID.uuidString, at: location)
            guard !allItems.contains(where: { $0.id == groupUUID.uuidString }) else {
                throw PlatformError.mutationUnverified(
                    type: "group", id: groupUUID.uuidString, reason: "Group still exists after ungroup.")
            }
            let idSet = Set(childIDs)
            return FreeformItemsWriteResult(board: readback, items: allItems.filter { idSet.contains($0.id) })
        }
    }

    public func alignItems(
        board selector: String, itemIDs: [String], mode: FreeformAlignMode, ifRevision: String? = nil
    ) throws -> FreeformItemsWriteResult {
        let minCount = (mode == .distributeHorizontal || mode == .distributeVertical) ? 3 : 2
        guard itemIDs.count >= minCount else {
            throw AgentError.invalid("\(mode.rawValue) requires at least \(minCount) item ids.")
        }
        let uuids = try itemIDs.map { id -> UUID in
            guard let uuid = UUID(uuidString: id) else { throw AgentError.invalid("Invalid item id '\(id)'.") }
            return uuid
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let cc = bridge.makeCommandController(for: board)
                struct Entry {
                    let id: String
                    let object: AnyObject
                    let x: Double
                    let y: Double
                    let width: Double
                    let height: Double
                    let angle: Double
                }
                let entries: [Entry] = try uuids.map { uuid in
                    guard let obj = bridge.getObjectArg(board, "getBoardItemForUUID:", uuid as NSUUID) else {
                        throw AgentError.notFound("item", uuid.uuidString)
                    }
                    try requireUnlocked(obj, id: uuid.uuidString, bridge: bridge)
                    guard let r = bridge.itemGeometryRect(obj) else {
                        throw AgentError.invalid("Item '\(uuid.uuidString)' has no canvas geometry.")
                    }
                    return Entry(
                        id: uuid.uuidString, object: obj, x: r.x, y: r.y, width: r.width, height: r.height,
                        angle: r.angle)
                }
                var updates: [(AnyObject, Double, Double, Double, Double, Double)] = []
                switch mode {
                case .left:
                    let target = entries.map(\.x).min()!
                    updates = entries.map { ($0.object, target, $0.y, $0.width, $0.height, $0.angle) }
                case .right:
                    let target = entries.map { $0.x + $0.width }.max()!
                    updates = entries.map { ($0.object, target - $0.width, $0.y, $0.width, $0.height, $0.angle) }
                case .center:
                    let minX = entries.map(\.x).min()!
                    let maxX = entries.map { $0.x + $0.width }.max()!
                    let mid = (minX + maxX) / 2
                    updates = entries.map { ($0.object, mid - $0.width / 2, $0.y, $0.width, $0.height, $0.angle) }
                case .top:
                    let target = entries.map(\.y).min()!
                    updates = entries.map { ($0.object, $0.x, target, $0.width, $0.height, $0.angle) }
                case .bottom:
                    let target = entries.map { $0.y + $0.height }.max()!
                    updates = entries.map { ($0.object, $0.x, target - $0.height, $0.width, $0.height, $0.angle) }
                case .middle:
                    let minY = entries.map(\.y).min()!
                    let maxY = entries.map { $0.y + $0.height }.max()!
                    let mid = (minY + maxY) / 2
                    updates = entries.map { ($0.object, $0.x, mid - $0.height / 2, $0.width, $0.height, $0.angle) }
                case .distributeHorizontal:
                    let sorted = entries.sorted { $0.x < $1.x }
                    let firstX = sorted.first!.x
                    let lastRight = sorted.last!.x + sorted.last!.width
                    let totalWidth = sorted.map(\.width).reduce(0, +)
                    let gap = (lastRight - firstX - totalWidth) / Double(sorted.count - 1)
                    var cursor = firstX
                    for entry in sorted {
                        updates.append((entry.object, cursor, entry.y, entry.width, entry.height, entry.angle))
                        cursor += entry.width + gap
                    }
                case .distributeVertical:
                    let sorted = entries.sorted { $0.y < $1.y }
                    let firstY = sorted.first!.y
                    let lastBottom = sorted.last!.y + sorted.last!.height
                    let totalHeight = sorted.map(\.height).reduce(0, +)
                    let gap = (lastBottom - firstY - totalHeight) / Double(sorted.count - 1)
                    var cursor = firstY
                    for entry in sorted {
                        updates.append((entry.object, entry.x, cursor, entry.width, entry.height, entry.angle))
                        cursor += entry.height + gap
                    }
                }
                bridge.withCommandGroup(on: cc) {
                    for (obj, x, y, w, h, a) in updates {
                        let geom = bridge.makeGeometry(x: x, y: y, width: w, height: h, angle: a)
                        bridge.enqueue(bridge.makeSetGeometryCommand(item: obj, geometry: geom), on: cc)
                    }
                }
                try bridge.saveBoard(board)
            }
            let (readback, allItems) = try readbackBoard(boardUUID.uuidString, at: location)
            let idSet = Set(uuids.map(\.uuidString))
            return FreeformItemsWriteResult(board: readback, items: allItems.filter { idSet.contains($0.id) })
        }
    }

    /// One absolute placement for `moveItems`. `x`/`y` are the item's top-left canvas geometry in points;
    /// `width`/`height` default to the item's current size.
    public struct ItemMove: Decodable, Sendable {
        public var item: String
        public var x: Double
        public var y: Double
        public var width: Double?
        public var height: Double?
        public init(item: String, x: Double, y: Double, width: Double? = nil, height: Double? = nil) {
            self.item = item; self.x = x; self.y = y; self.width = width; self.height = height
        }
    }

    /// Moves (and optionally resizes) many items in ONE native write: one store open, one undo group,
    /// one save, and at most one Freeform close/reopen.
    public func moveItems(board selector: String, moves: [ItemMove], ifRevision: String? = nil) throws
        -> FreeformItemsWriteResult
    {
        guard !moves.isEmpty else { throw AgentError.invalid("moves must contain at least one item.") }
        var seen = Set<String>()
        let parsed = try moves.map { m -> (UUID, ItemMove) in
            guard let uuid = UUID(uuidString: m.item) else { throw AgentError.invalid("Invalid item id '\(m.item)'.") }
            guard seen.insert(uuid.uuidString).inserted else { throw AgentError.invalid("Item '\(m.item)' is listed twice.") }
            try validateFinite(m.x, name: "x"); try validateFinite(m.y, name: "y")
            if let w = m.width { try validateFinite(w, name: "width", positive: true) }
            if let h = m.height { try validateFinite(h, name: "height", positive: true) }
            return (uuid, m)
        }
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()
            try bridge.withStore(at: boardsDir) { nativeStore in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let cc = bridge.makeCommandController(for: board)
                // Resolve and validate everything before enqueuing anything (all-or-nothing).
                let resolved: [(AnyObject, Double, Double, Double, Double, Double)] = try parsed.map { uuid, m in
                    guard let obj = bridge.getObjectArg(board, "getBoardItemForUUID:", uuid as NSUUID) else {
                        throw AgentError.notFound("item", uuid.uuidString)
                    }
                    try requireUnlocked(obj, id: uuid.uuidString, bridge: bridge)
                    guard let r = bridge.itemGeometryRect(obj) else {
                        throw AgentError.invalid("Item '\(uuid.uuidString)' has no canvas geometry.")
                    }
                    return (obj, m.x, m.y, m.width ?? r.width, m.height ?? r.height, r.angle)
                }
                bridge.withCommandGroup(on: cc) {
                    for (obj, x, y, w, h, a) in resolved {
                        let geom = bridge.makeGeometry(x: x, y: y, width: w, height: h, angle: a)
                        bridge.enqueue(bridge.makeSetGeometryCommand(item: obj, geometry: geom), on: cc)
                    }
                }
                try bridge.saveBoard(board)
            }
            let (readback, allItems) = try readbackBoard(boardUUID.uuidString, at: location)
            let idSet = Set(parsed.map { $0.0.uuidString })
            return FreeformItemsWriteResult(board: readback, items: allItems.filter { idSet.contains($0.id) })
        }
    }

    // MARK: - Batch Diagram Authoring

    public func createDiagram(board selector: String, spec: FreeformDiagramSpec, ifRevision: String? = nil) throws
        -> FreeformDiagramResult
    {
        guard !spec.nodes.isEmpty else {
            throw AgentError.invalid("Diagram spec must include at least one node.")
        }
        let validated = try Self.validateAndLayoutDiagram(spec)
        return try withBoardWrite(selector, ifRevision: ifRevision) { location, _, boardUUID in
            let bridge = try bridgeFactory()
            let boardsDir = location.database.deletingLastPathComponent()

            let (nodeIDs, edgeIDs) = try bridge.withStore(at: boardsDir) {
                nativeStore -> ([String: String], [String]) in
                let board = try bridge.loadBoard(in: nativeStore, id: boardUUID)
                let root = bridge.getObject(board, "rootContainer")!
                let rootID = bridge.getObject(root, "id")!
                let factory = bridge.makeFactory(for: board)
                let cc = bridge.makeCommandController(for: board)

                var nativeNodes: [String: AnyObject] = [:]
                var keyToID: [String: String] = [:]
                var createdEdgeIDs: [String] = []

                try bridge.withCommandGroup(on: cc) {
                    // 1. Insert all nodes cleanly with their exact geometry & styles.
                    for node in validated.nodes {
                        let item: AnyObject
                        switch node.kind {
                        case .text:
                            item = bridge.makeTextbox(
                                factory: factory, position: CGPoint(x: node.x, y: node.y), text: node.text ?? "")
                        case .sticky:
                            item = bridge.makeSticky(
                                factory: factory, attributedText: NSAttributedString(string: node.text ?? ""))
                        case .shape(let shapeKind):
                            item = bridge.makeShape(factory: factory, shapeType: shapeKind.nativeShapeType)
                        }
                        guard let id = bridge.itemUUIDString(item) else {
                            throw PlatformError.saveFailed("New diagram node '\(node.key)' did not have an identifier.")
                        }
                        bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [item]), on: cc)
                        let geom = bridge.makeGeometry(
                            x: node.x, y: node.y, width: node.width, height: node.height, angle: node.angle)
                        bridge.enqueue(bridge.makeSetGeometryCommand(item: item, geometry: geom), on: cc)
                        if let fill = node.fill {
                            bridge.enqueue(
                                bridge.makeSetFillCommand(shapeItem: item, fill: bridge.makeColorFill(fill)), on: cc)
                        }
                        if let stroke = node.stroke {
                            let nativeStroke = bridge.makeStroke(
                                color: stroke, width: node.strokeWidth, pattern: node.strokePattern)
                            bridge.enqueue(bridge.makeSetStrokeCommand(styledItem: item, stroke: nativeStroke), on: cc)
                        }
                        if case .shape = node.kind, let text = node.text, !text.isEmpty {
                            bridge.enqueue(bridge.makeReplaceAllTextCommand(shapeItem: item, text: text), on: cc)
                        }
                        nativeNodes[node.key] = item
                        keyToID[node.key] = id
                    }

                    // 2. Insert and bind all edges between nodes (or existing board items).
                    func resolveEndpoint(_ ref: String) throws -> AnyObject {
                        if let created = nativeNodes[ref] { return created }
                        if let uuid = UUID(uuidString: ref),
                            let existing = bridge.getObjectArg(board, "getBoardItemForUUID:", uuid as NSUUID)
                        {
                            return existing
                        }
                        throw AgentError.notFound("node or item", ref)
                    }

                    for edge in validated.edges {
                        let fromItem = try resolveEndpoint(edge.from)
                        let toItem = try resolveEndpoint(edge.to)
                        let geom = connectorGeometry(from: fromItem, to: toItem, bridge: bridge)
                        let stroke = bridge.makeStroke(
                            color: edge.stroke, width: edge.strokeWidth, pattern: edge.strokePattern)
                        let conn = bridge.makeConnectionLine(
                            store: nativeStore, rootContainerID: rootID, geometry: geom, style: edge.style,
                            stroke: stroke, headLineEnd: bridge.makeLineEnd(edge.headEnd),
                            tailLineEnd: bridge.makeLineEnd(edge.tailEnd))
                        guard let edgeID = bridge.itemUUIDString(conn) else {
                            throw PlatformError.saveFailed("New diagram connector did not have an identifier.")
                        }
                        bridge.enqueue(bridge.makeInsertCommand(parentContainer: root, items: [conn]), on: cc)
                        bridge.enqueue(
                            bridge.makeSetConnectionCommand(connector: conn, targetItem: fromItem, chirality: 0), on: cc
                        )
                        bridge.enqueue(
                            bridge.makeSetConnectionCommand(connector: conn, targetItem: toItem, chirality: 1), on: cc)
                        createdEdgeIDs.append(edgeID)
                    }
                }
                try bridge.saveBoard(board)
                return (keyToID, createdEdgeIDs)
            }

            let (readback, allItems) = try readbackBoard(boardUUID.uuidString, at: location)
            let byID = Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var resolvedNodes: [String: FreeformItemSnapshot] = [:]
            for (key, id) in nodeIDs {
                guard let snap = byID[id] else {
                    throw PlatformError.mutationUnverified(
                        type: "item", id: id, reason: "Diagram node '\(key)' did not appear on readback.")
                }
                resolvedNodes[key] = snap
            }
            var resolvedEdges: [FreeformItemSnapshot] = []
            for id in edgeIDs {
                guard let snap = byID[id] else {
                    throw PlatformError.mutationUnverified(
                        type: "connector", id: id, reason: "Diagram connector did not appear on readback.")
                }
                resolvedEdges.append(snap)
            }
            return FreeformDiagramResult(board: readback, nodes: resolvedNodes, edges: resolvedEdges)
        }
    }

    // MARK: - Diagram Validation & Deterministic Auto-Layout

    struct ResolvedDiagramNode {
        enum Kind { case text, sticky, shape(FreeformShapeKind) }
        let key: String
        let kind: Kind
        let text: String?
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let angle: Double
        let fill: FreeformColor?
        let stroke: FreeformColor?
        let strokeWidth: Double
        let strokePattern: FreeformStrokePatternKind
    }

    struct ResolvedDiagramEdge {
        let from: String
        let to: String
        let style: FreeformConnectorStyle
        let stroke: FreeformColor
        let strokeWidth: Double
        let strokePattern: FreeformStrokePatternKind
        let headEnd: FreeformLineEndKind
        let tailEnd: FreeformLineEndKind
    }

    /// Validates a diagram spec (can be called before any native context is created) and computes
    /// deterministic layered coordinates for any nodes without explicit x/y.
    public static func validateDiagram(_ spec: FreeformDiagramSpec) throws {
        _ = try validateAndLayoutDiagram(spec)
    }

    static func validateAndLayoutDiagram(_ spec: FreeformDiagramSpec) throws -> (
        nodes: [ResolvedDiagramNode], edges: [ResolvedDiagramEdge]
    ) {
        guard !spec.nodes.isEmpty else {
            throw AgentError.invalid("Diagram spec must contain at least one node.")
        }
        var seenKeys: Set<String> = []
        for node in spec.nodes {
            guard !node.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AgentError.invalid("Every diagram node must have a non-empty 'key'.")
            }
            guard seenKeys.insert(node.key).inserted else {
                throw AgentError.invalid("Duplicate diagram node key '\(node.key)'.")
            }
        }
        let horizontal = (spec.direction ?? "top-down").lowercased().hasPrefix("left")
        let originX = spec.originX ?? 100
        let originY = spec.originY ?? 100
        let hGap = spec.horizontalGap ?? 80
        let vGap = spec.verticalGap ?? 80
        guard originX.isFinite && originY.isFinite && hGap.isFinite && vGap.isFinite && hGap >= 0 && vGap >= 0 else {
            throw AgentError.invalid("Diagram layout coordinates and gaps must be finite non-negative numbers.")
        }

        // Parse edges first so auto-layout can layer nodes by graph depth.
        var resolvedEdges: [ResolvedDiagramEdge] = []
        var outgoing: [String: [String]] = [:]
        var inDegree: [String: Int] = Dictionary(uniqueKeysWithValues: spec.nodes.map { ($0.key, 0) })
        for edge in spec.edges ?? [] {
            guard edge.from != edge.to else {
                throw AgentError.invalid("Diagram edge cannot connect '\(edge.from)' to itself.")
            }
            if !seenKeys.contains(edge.from), UUID(uuidString: edge.from) == nil {
                throw AgentError.invalid("Diagram edge 'from' references unknown key '\(edge.from)'.")
            }
            if !seenKeys.contains(edge.to), UUID(uuidString: edge.to) == nil {
                throw AgentError.invalid("Diagram edge 'to' references unknown key '\(edge.to)'.")
            }
            let style = try edge.style.map(FreeformConnectorStyle.parse) ?? .curved
            let stroke = try edge.stroke.map(FreeformColor.parse) ?? FreeformColor(red: 0.25, green: 0.25, blue: 0.28)
            let width = edge.strokeWidth ?? 2
            guard width.isFinite && width > 0 else {
                throw AgentError.invalid("Diagram edge strokeWidth must be > 0.")
            }
            let pattern = try edge.strokePattern.map(FreeformStrokePatternKind.parse) ?? .solid
            let head = try edge.headEnd.map(FreeformLineEndKind.parse) ?? .none
            let tail = try edge.tailEnd.map(FreeformLineEndKind.parse) ?? .arrow
            resolvedEdges.append(
                ResolvedDiagramEdge(
                    from: edge.from, to: edge.to, style: style, stroke: stroke, strokeWidth: width,
                    strokePattern: pattern, headEnd: head, tailEnd: tail))
            if seenKeys.contains(edge.from) && seenKeys.contains(edge.to) {
                outgoing[edge.from, default: []].append(edge.to)
                inDegree[edge.to, default: 0] += 1
            }
        }

        // Compute deterministic BFS layers for nodes without explicit coordinates.
        var layerOf: [String: Int] = [:]
        var queue = spec.nodes.map(\.key).filter { (inDegree[$0] ?? 0) == 0 }
        if queue.isEmpty, let first = spec.nodes.first?.key { queue = [first] }
        for key in queue { layerOf[key] = 0 }
        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let depth = layerOf[current] ?? 0
            for next in outgoing[current] ?? [] where layerOf[next] == nil {
                layerOf[next] = depth + 1
                queue.append(next)
            }
        }
        // Any remaining disconnected cycle components get placed in order.
        for node in spec.nodes where layerOf[node.key] == nil {
            layerOf[node.key] = 0
        }

        var byLayer: [Int: [String]] = [:]
        for node in spec.nodes {
            byLayer[layerOf[node.key] ?? 0, default: []].append(node.key)
        }
        var autoPos: [String: (x: Double, y: Double)] = [:]
        let defaultWidth = 220.0
        let defaultHeight = 120.0
        for layer in byLayer.keys.sorted() {
            let keys = byLayer[layer] ?? []
            for (slot, key) in keys.enumerated() {
                if horizontal {
                    autoPos[key] = (
                        originX + Double(layer) * (defaultWidth + hGap),
                        originY + Double(slot) * (defaultHeight + vGap)
                    )
                } else {
                    autoPos[key] = (
                        originX + Double(slot) * (defaultWidth + hGap),
                        originY + Double(layer) * (defaultHeight + vGap)
                    )
                }
            }
        }

        var resolvedNodes: [ResolvedDiagramNode] = []
        for node in spec.nodes {
            let rawType = (node.type ?? "shape").lowercased()
            let kind: ResolvedDiagramNode.Kind
            let fallbackSize: (Double, Double)
            switch rawType {
            case "text", "textbox", "text_box":
                kind = .text
                fallbackSize = (220, 60)
            case "sticky", "sticky_note":
                kind = .sticky
                fallbackSize = (200, 200)
            case "shape":
                let shapeKind = try node.shape.map(FreeformShapeKind.parse) ?? .roundedRectangle
                kind = .shape(shapeKind)
                fallbackSize = (defaultWidth, defaultHeight)
            default:
                // Allow passing a shape name directly as type (e.g. "diamond", "circle").
                let shapeKind = try FreeformShapeKind.parse(rawType)
                kind = .shape(shapeKind)
                fallbackSize = (defaultWidth, defaultHeight)
            }
            let fallback = autoPos[node.key] ?? (originX, originY)
            let x = node.x ?? fallback.x
            let y = node.y ?? fallback.y
            let width = node.width ?? fallbackSize.0
            let height = node.height ?? fallbackSize.1
            let angle = node.angle ?? 0
            guard
                x.isFinite && y.isFinite && width.isFinite && height.isFinite && angle.isFinite && width > 0
                    && height > 0
            else {
                throw AgentError.invalid("Diagram node '\(node.key)' has invalid geometry.")
            }
            let fill = try node.fill.map(FreeformColor.parse)
            let stroke = try node.stroke.map(FreeformColor.parse)
            let strokeWidth = node.strokeWidth ?? 2
            guard strokeWidth.isFinite && strokeWidth > 0 else {
                throw AgentError.invalid("Diagram node '\(node.key)' has invalid strokeWidth.")
            }
            let strokePattern = try node.strokePattern.map(FreeformStrokePatternKind.parse) ?? .solid
            resolvedNodes.append(
                ResolvedDiagramNode(
                    key: node.key, kind: kind, text: node.text, x: x, y: y, width: width, height: height,
                    angle: angle, fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokePattern: strokePattern))
        }
        return (resolvedNodes, resolvedEdges)
    }

    private func connectorGeometry(from: AnyObject, to: AnyObject, bridge: FreeformNativeBridge) -> AnyObject {
        let a = bridge.itemGeometryRect(from) ?? (0, 0, 200, 100, 0)
        let b = bridge.itemGeometryRect(to) ?? (300, 0, 200, 100, 0)
        let ax = a.x + a.width / 2
        let ay = a.y + a.height / 2
        let bx = b.x + b.width / 2
        let by = b.y + b.height / 2
        let minX = min(ax, bx)
        let minY = min(ay, by)
        let width = max(abs(bx - ax), 40)
        let height = max(abs(by - ay), 10)
        return bridge.makeGeometry(x: minX, y: minY, width: width, height: height, angle: 0)
    }
}
