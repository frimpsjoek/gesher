import Foundation
import FreeformCore
import GesherKit
import GesherPlatform

enum AddTextItem: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var text: String
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
        var angle: Double?
        var fontSize: Double?
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var strikethrough: Bool
        var textColor: String?
        var align: String?
        var ifRevision: String?
    }

    static let path = ["items", "add-text"]
    static let summary =
        "Add an editable text box at explicit canvas coordinates (points, rich text styling & RTL/Unicode supported)."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .string("text", "Text content.", required: true),
        .number("x", "Canvas X position in points. Default: 100."),
        .number("y", "Canvas Y position in points. Default: 100."),
        .number("width", "Width in points.", min: 1),
        .number("height", "Height in points.", min: 1),
        .number("angle", "Rotation in degrees clockwise. Default: 0."),
        .number("fontSize", "Font size in points (e.g. 24).", min: 6, max: 400),
        .boolean("bold", "Use bold font weight."),
        .boolean("italic", "Use italic font style."),
        .boolean("underline", "Underline the text."),
        .boolean("strikethrough", "Strikethrough the text."),
        .string("textColor", "Text color (#RRGGBB or name like black, blue, red)."),
        .choice(
            "align", FreeformTextAlignment.allCases.map(\.rawValue),
            "Paragraph alignment (left, center, right, justified)."),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items add-text 'Trip ideas' --text 'Day 1: Arrival' --x 120 --y 80 --width 260"
    ]

    static func validate(_ input: Input) throws {
        guard !input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalid("Text content is empty.")
        }
        if let textColor = input.textColor { _ = try FreeformColor.parse(textColor) }
        if let align = input.align { _ = try FreeformTextAlignment.parse(align) }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemMutationOutput {
        let style = FreeformTextStyle(
            fontSize: input.fontSize, bold: input.bold, italic: input.italic, underline: input.underline,
            strikethrough: input.strikethrough, color: try input.textColor.map(FreeformColor.parse),
            alignment: try input.align.map(FreeformTextAlignment.parse))
        let spec = FreeformTextSpec(
            text: input.text, x: input.x ?? 100, y: input.y ?? 100, width: input.width, height: input.height,
            angle: input.angle ?? 0, style: style.hasStyling ? style : nil)
        let result = try context.writer.addText(board: input.board, spec: spec, ifRevision: input.ifRevision)
        return ItemMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            item: Item(result.item), sync: context.writer.lastWriteSync)
    }
}

enum AddShapeItem: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var shape: String
        var text: String?
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
        var angle: Double?
        var fill: String?
        var stroke: String?
        var strokeWidth: Double?
        var strokePattern: String
        var ifRevision: String?
    }

    static let path = ["items", "add-shape"]
    static let summary = "Add a native editable shape with position, size, rotation, text, fill and stroke."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .choice(
            "shape", FreeformShapeKind.allCases.map(\.rawValue),
            "Shape kind. Default: rounded_rectangle.", default: "rounded_rectangle"),
        .string("text", "Optional text inside the shape."),
        .number("x", "Canvas X position in points. Default: 100."),
        .number("y", "Canvas Y position in points. Default: 100."),
        .number("width", "Width in points. Default: 220.", min: 1),
        .number("height", "Height in points. Default: 120.", min: 1),
        .number("angle", "Rotation in degrees clockwise. Default: 0."),
        .string("fill", "Fill color (#RRGGBB, #RRGGBBAA or name like blue, green, yellow)."),
        .string("stroke", "Stroke color (#RRGGBB, #RRGGBBAA or name)."),
        .number("strokeWidth", "Stroke width in points. Default: 2.", min: 0.5),
        .choice(
            "strokePattern", FreeformStrokePatternKind.allCases.map(\.rawValue),
            "Stroke pattern. Default: solid.", default: "solid"),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items add-shape 'Architecture' --shape rounded_rectangle --text 'API Gateway' --x 100 --y 100 --fill '#3B82F6'",
        "items add-shape 'Architecture' --shape diamond --text 'Valid?' --x 400 --y 100 --fill orange",
    ]

    static func validate(_ input: Input) throws {
        _ = try FreeformShapeKind.parse(input.shape)
        if let fill = input.fill { _ = try FreeformColor.parse(fill) }
        if let stroke = input.stroke { _ = try FreeformColor.parse(stroke) }
        _ = try FreeformStrokePatternKind.parse(input.strokePattern)
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemMutationOutput {
        let spec = FreeformShapeSpec(
            shape: try FreeformShapeKind.parse(input.shape), text: input.text, x: input.x ?? 100, y: input.y ?? 100,
            width: input.width ?? 220, height: input.height ?? 120, angle: input.angle ?? 0,
            fill: try input.fill.map(FreeformColor.parse), stroke: try input.stroke.map(FreeformColor.parse),
            strokeWidth: input.strokeWidth ?? 2,
            strokePattern: try FreeformStrokePatternKind.parse(input.strokePattern))
        let result = try context.writer.addShape(board: input.board, spec: spec, ifRevision: input.ifRevision)
        return ItemMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            item: Item(result.item), sync: context.writer.lastWriteSync)
    }
}

enum AddStickyItem: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var text: String
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
        var angle: Double?
        var fill: String?
        var fontSize: Double?
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var strikethrough: Bool
        var textColor: String?
        var align: String?
        var ifRevision: String?
    }

    static let path = ["items", "add-sticky"]
    static let summary =
        "Add a native sticky note with text, optional color, rich text styling, position, size and rotation."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .string("text", "Sticky note text.", required: true),
        .number("x", "Canvas X position in points. Default: 100."),
        .number("y", "Canvas Y position in points. Default: 100."),
        .number("width", "Width in points. Default: 200.", min: 1),
        .number("height", "Height in points. Default: 200.", min: 1),
        .number("angle", "Rotation in degrees clockwise. Default: 0."),
        .string("fill", "Sticky note color (#RRGGBB or name like yellow, blue, green, pink, orange, purple)."),
        .number("fontSize", "Font size in points (e.g. 20).", min: 6, max: 400),
        .boolean("bold", "Use bold font weight."),
        .boolean("italic", "Use italic font style."),
        .boolean("underline", "Underline the text."),
        .boolean("strikethrough", "Strikethrough the text."),
        .string("textColor", "Text color (#RRGGBB or name like black, blue, red)."),
        .choice(
            "align", FreeformTextAlignment.allCases.map(\.rawValue),
            "Paragraph alignment (left, center, right, justified)."),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items add-sticky 'Retro' --text 'Ship v1.2' --x 360 --y 120 --fill yellow"
    ]

    static func validate(_ input: Input) throws {
        if let fill = input.fill { _ = try FreeformColor.parse(fill) }
        if let textColor = input.textColor { _ = try FreeformColor.parse(textColor) }
        if let align = input.align { _ = try FreeformTextAlignment.parse(align) }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemMutationOutput {
        let style = FreeformTextStyle(
            fontSize: input.fontSize, bold: input.bold, italic: input.italic, underline: input.underline,
            strikethrough: input.strikethrough, color: try input.textColor.map(FreeformColor.parse),
            alignment: try input.align.map(FreeformTextAlignment.parse))
        let spec = FreeformStickySpec(
            text: input.text, x: input.x ?? 100, y: input.y ?? 100, width: input.width ?? 200,
            height: input.height ?? 200, angle: input.angle ?? 0, fill: try input.fill.map(FreeformColor.parse),
            style: style.hasStyling ? style : nil)
        let result = try context.writer.addSticky(board: input.board, spec: spec, ifRevision: input.ifRevision)
        return ItemMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            item: Item(result.item), sync: context.writer.lastWriteSync)
    }
}

enum ConnectItems: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var from: String
        var to: String
        var style: String
        var stroke: String?
        var strokeWidth: Double?
        var strokePattern: String
        var headEnd: String
        var tailEnd: String
        var ifRevision: String?
    }

    static let path = ["items", "connect"]
    static let summary = "Create a native connector line bound to two item ids (stays attached when items move)."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .string("from", "Source item UUID.", required: true),
        .string("to", "Target item UUID.", required: true),
        .choice(
            "style", FreeformConnectorStyle.allCases.map(\.rawValue), "Routing style. Default: curved.",
            default: "curved"),
        .string("stroke", "Line color (#RRGGBB or name). Default: dark gray."),
        .number("strokeWidth", "Line width in points. Default: 2.", min: 0.5),
        .choice(
            "strokePattern", FreeformStrokePatternKind.allCases.map(\.rawValue),
            "Line pattern. Default: solid.", default: "solid"),
        .choice(
            "headEnd", FreeformLineEndKind.allCases.map(\.rawValue), "Start endpoint. Default: none.", default: "none"),
        .choice(
            "tailEnd", FreeformLineEndKind.allCases.map(\.rawValue), "End endpoint. Default: arrow.", default: "arrow"),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items connect 'Architecture' --from 00000000-0000-0000-0000-000000000001 --to 00000000-0000-0000-0000-000000000002 --style orthogonal"
    ]

    static func validate(_ input: Input) throws {
        guard UUID(uuidString: input.from) != nil else { throw AgentError.invalid("Invalid 'from' item UUID.") }
        guard UUID(uuidString: input.to) != nil else { throw AgentError.invalid("Invalid 'to' item UUID.") }
        guard input.from.caseInsensitiveCompare(input.to) != .orderedSame else {
            throw AgentError.invalid("'from' and 'to' must be different items.")
        }
        _ = try FreeformConnectorStyle.parse(input.style)
        if let stroke = input.stroke { _ = try FreeformColor.parse(stroke) }
        _ = try FreeformStrokePatternKind.parse(input.strokePattern)
        _ = try FreeformLineEndKind.parse(input.headEnd)
        _ = try FreeformLineEndKind.parse(input.tailEnd)
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemMutationOutput {
        let spec = FreeformConnectorSpec(
            fromID: input.from, toID: input.to, style: try FreeformConnectorStyle.parse(input.style),
            stroke: try input.stroke.map(FreeformColor.parse) ?? FreeformColor(red: 0.25, green: 0.25, blue: 0.28),
            strokeWidth: input.strokeWidth ?? 2,
            strokePattern: try FreeformStrokePatternKind.parse(input.strokePattern),
            headEnd: try FreeformLineEndKind.parse(input.headEnd),
            tailEnd: try FreeformLineEndKind.parse(input.tailEnd))
        let result = try context.writer.connect(board: input.board, spec: spec, ifRevision: input.ifRevision)
        return ItemMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            item: Item(result.item), sync: context.writer.lastWriteSync)
    }
}

enum UpdateItem: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var item: String
        var text: String?
        var shape: String?
        var description: String?
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
        var angle: Double?
        var fill: String?
        var clearFill: Bool
        var stroke: String?
        var strokeWidth: Double?
        var strokePattern: String?
        var clearStroke: Bool
        var headEnd: String?
        var tailEnd: String?
        var locked: Bool?
        var from: String?
        var to: String?
        var z: String?
        var ifRevision: String?
    }

    static let path = ["items", "update"]
    static let summary =
        "Edit an item's text, position, size, rotation, fill, stroke, line ends, lock, z-order or connector endpoints."
    static let effect = OperationEffect.write
    static let idempotent = true
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .string("item", "Item UUID to update.", required: true),
        .string("text", "Replace the item's text."),
        .choice("shape", FreeformShapeKind.allCases.map(\.rawValue), "Replace a shape's geometry kind."),
        .string("description", "Set accessibility description / alt text."),
        .number("x", "New X position in points."),
        .number("y", "New Y position in points."),
        .number("width", "New width in points.", min: 1),
        .number("height", "New height in points.", min: 1),
        .number("angle", "New rotation in degrees clockwise."),
        .string("fill", "New fill color (#RRGGBB, #RRGGBBAA or name)."),
        .boolean("clearFill", "Remove fill color."),
        .string("stroke", "New stroke color (#RRGGBB, #RRGGBBAA or name)."),
        .number("strokeWidth", "New stroke width in points.", min: 0.5),
        .choice("strokePattern", FreeformStrokePatternKind.allCases.map(\.rawValue), "New stroke pattern."),
        .boolean("clearStroke", "Remove stroke."),
        .choice("headEnd", FreeformLineEndKind.allCases.map(\.rawValue), "New start endpoint for lines/connectors."),
        .choice("tailEnd", FreeformLineEndKind.allCases.map(\.rawValue), "New end endpoint for lines/connectors."),
        Param("locked", .boolean, "Lock (true) or unlock (false) the item."),
        .string("from", "Rebind connector start to this item UUID."),
        .string("to", "Rebind connector end to this item UUID."),
        .string("z", "Move stacking order to 'front', 'back' or a 0-based index."),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items update 'Architecture' --item 00000000-0000-0000-0000-000000000001 --x 200 --y 150 --fill green --text 'Updated'"
    ]

    static func validate(_ input: Input) throws {
        guard UUID(uuidString: input.item) != nil else {
            throw AgentError.invalid("Invalid item UUID '\(input.item)'.")
        }
        let spec = try buildSpec(input)
        guard !spec.isEmpty else {
            throw AgentError.invalid("Specify at least one property to update.")
        }
    }

    private static func buildSpec(_ input: Input) throws -> FreeformItemUpdateSpec {
        if let from = input.from, UUID(uuidString: from) == nil {
            throw AgentError.invalid("Invalid 'from' item UUID '\(from)'.")
        }
        if let to = input.to, UUID(uuidString: to) == nil {
            throw AgentError.invalid("Invalid 'to' item UUID '\(to)'.")
        }
        return FreeformItemUpdateSpec(
            text: input.text, shape: try input.shape.map(FreeformShapeKind.parse), description: input.description,
            x: input.x, y: input.y, width: input.width, height: input.height, angle: input.angle,
            fill: try input.fill.map(FreeformColor.parse), clearFill: input.clearFill,
            stroke: try input.stroke.map(FreeformColor.parse), strokeWidth: input.strokeWidth,
            strokePattern: try input.strokePattern.map(FreeformStrokePatternKind.parse),
            clearStroke: input.clearStroke, headEnd: try input.headEnd.map(FreeformLineEndKind.parse),
            tailEnd: try input.tailEnd.map(FreeformLineEndKind.parse), locked: input.locked,
            fromID: input.from, toID: input.to, zOrder: try input.z.map(FreeformZOrderTarget.parse))
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemMutationOutput {
        let spec = try buildSpec(input)
        let result = try context.writer.updateItem(
            board: input.board, itemID: input.item, spec: spec, ifRevision: input.ifRevision)
        return ItemMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            item: Item(result.item), sync: context.writer.lastWriteSync)
    }
}

enum DeleteItems: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var item: [String]
        var ifRevision: String?
    }

    static let path = ["items", "delete"]
    static let summary = "Delete one or more items from a board without modifying unrelated objects."
    static let effect = OperationEffect.destructive
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .list("item", "Item UUID(s) to delete.", required: true),
        .string("ifRevision", "Only delete if the board still matches this revision."),
    ]
    static let examples = [
        "items delete 'Architecture' --item 00000000-0000-0000-0000-000000000001"
    ]

    static func validate(_ input: Input) throws {
        guard !input.item.isEmpty else { throw AgentError.invalid("Pass at least one --item UUID.") }
        for id in input.item where UUID(uuidString: id) == nil {
            throw AgentError.invalid("Invalid item UUID '\(id)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> DeleteItemsOutput {
        let result = try context.writer.deleteItems(
            board: input.board, itemIDs: input.item, ifRevision: input.ifRevision)
        return DeleteItemsOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            deleted: result.deletedIDs,
            affectedConnectors: result.affectedConnectors.isEmpty ? nil : result.affectedConnectors.map(Item.init),
            sync: context.writer.lastWriteSync)
    }
}

enum DuplicateItems: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var item: [String]
        var dx: Double?
        var dy: Double?
        var ifRevision: String?
    }

    static let path = ["items", "duplicate"]
    static let summary = "Duplicate one or more items on a board with an optional coordinate offset."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .list("item", "Item UUID(s) to duplicate.", required: true),
        .number("dx", "Horizontal offset in points. Default: 24."),
        .number("dy", "Vertical offset in points. Default: 24."),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items duplicate 'Architecture' --item 00000000-0000-0000-0000-000000000001 --dx 260 --dy 0"
    ]

    static func validate(_ input: Input) throws {
        guard !input.item.isEmpty else { throw AgentError.invalid("Pass at least one --item UUID.") }
        for id in input.item where UUID(uuidString: id) == nil {
            throw AgentError.invalid("Invalid item UUID '\(id)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemsMutationOutput {
        let result = try context.writer.duplicateItems(
            board: input.board, itemIDs: input.item, dx: input.dx ?? 24, dy: input.dy ?? 24,
            ifRevision: input.ifRevision)
        return ItemsMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            items: result.items.map(Item.init), sync: context.writer.lastWriteSync)
    }
}

enum AddTableItem: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var rows: Int
        var columns: Int
        var cells: [[String]]?
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
        var rtl: Bool
        var ifRevision: String?
    }

    static let path = ["items", "add-table"]
    static let summary =
        "Add a native Freeform table at explicit canvas coordinates with optional initial 2D cell contents."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .integer("rows", "Number of rows (1-50). Default: 3.", default: 3, min: 1, max: 50),
        .integer("columns", "Number of columns (1-25). Default: 3.", default: 3, min: 1, max: 25),
        Param(
            "cells", .array(.array(.string)),
            "Optional 2D array of cell strings (rows x columns); infers dimensions when passed."),
        .number("x", "Canvas X position in points. Default: 100."),
        .number("y", "Canvas Y position in points. Default: 100."),
        .number("width", "Table width in points. Default: 420.", min: 1),
        .number("height", "Table height in points. Default: 220.", min: 1),
        .boolean("rtl", "Force right-to-left text direction on all table cells (Hebrew/Arabic text is auto-detected)."),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items add-table 'Roadmap' --rows 4 --columns 3 --x 100 --y 200",
        #"items add-table 'Roadmap' --cells '[["Task","Owner"],["Auth","Alex"]]' --x 100 --y 200"#,
    ]

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemMutationOutput {
        let spec = FreeformTableSpec(
            rows: input.rows, columns: input.columns, cells: input.cells, x: input.x ?? 100, y: input.y ?? 100,
            width: input.width ?? 420, height: input.height ?? 220, rtl: input.rtl)
        let result = try context.writer.addTable(board: input.board, spec: spec, ifRevision: input.ifRevision)
        return ItemMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            item: Item(result.item), sync: context.writer.lastWriteSync)
    }
}

enum GetTable: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var item: String
    }

    static let path = ["items", "table-get"]
    static let summary =
        "Read a Freeform table's dimensions, RTL flag and 2D cell text matrix (works while Freeform is open)."
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .string("item", "Table item UUID.", required: true),
    ]
    static let examples = [
        "items table-get 'Roadmap' --item 00000000-0000-0000-0000-000000000001"
    ]

    static func validate(_ input: Input) throws {
        guard UUID(uuidString: input.item) != nil else {
            throw AgentError.invalid("Invalid table item UUID '\(input.item)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> TableOutput {
        let result = try context.writer.getTable(board: input.board, itemID: input.item)
        return TableOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            table: TableData(result.table), sync: nil)
    }
}

enum SetTableCell: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var item: String
        var row: Int
        var column: Int
        var text: String
        var ifRevision: String?
    }

    static let path = ["items", "table-set-cell"]
    static let summary =
        "Update a single cell's text inside an existing Freeform table in place (0-based row and column)."
    static let effect = OperationEffect.write
    static let idempotent = true
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .string("item", "Table item UUID.", required: true),
        .integer("row", "0-based row index.", required: true, min: 0),
        .integer("column", "0-based column index.", required: true, min: 0),
        .string("text", "New text for the cell.", required: true),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items table-set-cell 'Roadmap' --item 00000000-0000-0000-0000-000000000001 --row 1 --column 0 --text 'Done'"
    ]

    static func validate(_ input: Input) throws {
        guard UUID(uuidString: input.item) != nil else {
            throw AgentError.invalid("Invalid table item UUID '\(input.item)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> TableOutput {
        let result = try context.writer.setTableCell(
            board: input.board, itemID: input.item, row: input.row, column: input.column, text: input.text,
            ifRevision: input.ifRevision)
        return TableOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            table: TableData(result.table), sync: context.writer.lastWriteSync)
    }
}

enum GroupItems: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var item: [String]
        var ifRevision: String?
    }

    static let path = ["items", "group"]
    static let summary = "Group two or more canvas items together."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .list("item", "Two or more item UUIDs to group.", required: true),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items group 'Architecture' --item 00000000-0000-0000-0000-000000000001 --item 00000000-0000-0000-0000-000000000002"
    ]

    static func validate(_ input: Input) throws {
        guard input.item.count >= 2 else { throw AgentError.invalid("Grouping requires at least two --item UUIDs.") }
        for id in input.item where UUID(uuidString: id) == nil {
            throw AgentError.invalid("Invalid item UUID '\(id)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemMutationOutput {
        let result = try context.writer.groupItems(
            board: input.board, itemIDs: input.item, ifRevision: input.ifRevision)
        return ItemMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            item: Item(result.item), sync: context.writer.lastWriteSync)
    }
}

enum UngroupItems: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var group: String
        var ifRevision: String?
    }

    static let path = ["items", "ungroup"]
    static let summary = "Ungroup a group item, returning its children to the canvas."
    static let effect = OperationEffect.write
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .string("group", "Group item UUID to ungroup.", required: true),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items ungroup 'Architecture' --group 00000000-0000-0000-0000-000000000001"
    ]

    static func validate(_ input: Input) throws {
        guard UUID(uuidString: input.group) != nil else {
            throw AgentError.invalid("Invalid group UUID '\(input.group)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemsMutationOutput {
        let result = try context.writer.ungroupItem(
            board: input.board, groupID: input.group, ifRevision: input.ifRevision)
        return ItemsMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            items: result.items.map(Item.init), sync: context.writer.lastWriteSync)
    }
}

enum AlignItems: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var item: [String]
        var mode: String
        var ifRevision: String?
    }

    static let path = ["items", "align"]
    static let summary = "Align or evenly distribute multiple items on a board."
    static let effect = OperationEffect.write
    static let idempotent = true
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        .list("item", "Item UUIDs to align or distribute.", required: true),
        .choice("mode", FreeformAlignMode.allCases.map(\.rawValue), "Alignment or distribution mode.", required: true),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        "items align 'Architecture' --item 00000000-0000-0000-0000-000000000001 --item 00000000-0000-0000-0000-000000000002 --mode top"
    ]

    static func validate(_ input: Input) throws {
        let mode = try FreeformAlignMode.parse(input.mode)
        let minCount = (mode == .distributeHorizontal || mode == .distributeVertical) ? 3 : 2
        guard input.item.count >= minCount else {
            throw AgentError.invalid("\(mode.rawValue) requires at least \(minCount) items.")
        }
        for id in input.item where UUID(uuidString: id) == nil {
            throw AgentError.invalid("Invalid item UUID '\(id)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemsMutationOutput {
        let mode = try FreeformAlignMode.parse(input.mode)
        let result = try context.writer.alignItems(
            board: input.board, itemIDs: input.item, mode: mode, ifRevision: input.ifRevision)
        return ItemsMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            items: result.items.map(Item.init), sync: context.writer.lastWriteSync)
    }
}

enum MoveItems: AgentOperation {
    struct Input: Decodable, Sendable {
        var board: String
        var moves: [FreeformWriter.ItemMove]
        var ifRevision: String?
    }

    static let path = ["items", "move"]
    static let summary = "Move/resize many items in one native write (one save, one undo group): exact layouts without GUI."
    static let effect = OperationEffect.write
    static let idempotent = true
    static let params: [Param] = [
        .string("board", "Board title or id.", required: true, positional: true),
        Param(
            "moves", .array(.object),
            "JSON array of {item, x, y, width?, height?}; x/y are the item's top-left canvas point.",
            required: true),
        .string("ifRevision", "Only save if the board still matches this revision."),
    ]
    static let examples = [
        #"items move 'Moodboard' --moves '[{"item":"00000000-0000-0000-0000-000000000001","x":0,"y":0},{"item":"00000000-0000-0000-0000-000000000002","x":270,"y":0}]'"#
    ]

    static func validate(_ input: Input) throws {
        guard !input.moves.isEmpty else { throw AgentError.invalid("moves must not be empty.") }
        for m in input.moves where UUID(uuidString: m.item) == nil {
            throw AgentError.invalid("Invalid item UUID '\(m.item)'.")
        }
    }

    static func run(_ input: Input, _ context: FreeformContext) throws -> ItemsMutationOutput {
        let result = try context.writer.moveItems(board: input.board, moves: input.moves, ifRevision: input.ifRevision)
        return ItemsMutationOutput(
            board: result.board.id, title: result.board.title, revision: result.board.revision,
            items: result.items.map(Item.init), sync: context.writer.lastWriteSync)
    }
}
