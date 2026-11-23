import GesherKit
import GesherPlatform
import Foundation
import FreeformCore

@main
enum FreeformCli {
    static func main() { FreeformApp.make().main() }
}

/// The Freeform app. Reads decode a temporary copy of the store with Freeform's own model types;
/// native board authoring and lifecycle mutations run through Freeform's own in-process store and
/// command engine (gated on verified Mach-O build UUID, with Freeform closed); media/file imports
/// use Freeform's import inbox (see FreeformNativeBridge, FreeformImporter and RESEARCH.md).
enum FreeformApp {
    static func make(context: @escaping () throws -> FreeformContext = { FreeformContext() })
        -> AgentApp<FreeformContext>
    {
        AgentApp(
            name: "freeform",
            summary:
                "Read, author and edit Apple Freeform boards: native text boxes, shapes, sticky notes, bound connectors, diagrams and board lifecycle.",
            instructions: """
                Boards accept a title or an id; on 'ambiguous' retry with a candidate id. boards_list and \
                items_list read a temporary copy of the store (titles, folders, favorites, item text, \
                positions, sizes, colors, stacking order, connector endpoints, revisions); search finds text, \
                links and file names across boards. Native authoring (items_add_text, items_add_shape, \
                items_add_sticky, items_add_table, items_table_set_cell, items_connect, items_update, \
                items_delete, items_duplicate, items_group, items_ungroup, items_align, diagram_create, \
                boards_rename, boards_favorite, boards_appearance, boards_delete, boards_restore) writes \
                through Freeform's own command engine and verifies every change on readback. If Freeform is \
                open with a visible window, Quick Refresh (on by default) closes it cleanly, applies the \
                write and immediately reopens the edited board without stealing focus (sync: live_refreshed). \
                When Freeform is closed or idle with no visible windows, writes run silently without opening \
                a window; call boards_sync afterward if you want hidden iCloud sync. Read-only \
                native tools (items_table_get, scenes_list, boards_export) work even while Freeform is open. \
                Pass ifRevision from boards_get or items_list to guard against concurrent edits. items_add \
                and boards_create with files/urls use Freeform's import inbox.
                """,
            permission: .fullDiskAccess,
            operations: [
                AnyOperation(FreeformDoctor.self),
                AnyOperation(ListBoards.self),
                AnyOperation(GetBoard.self),
                AnyOperation(ListItems.self),
                AnyOperation(SearchBoards.self),
                AnyOperation(CreateBoard.self),
                AnyOperation(RenameBoard.self),
                AnyOperation(FavoriteBoard.self),
                AnyOperation(SetBoardAppearance.self),
                AnyOperation(DeleteBoard.self),
                AnyOperation(RestoreBoard.self),
                AnyOperation(ExportBoard.self),
                AnyOperation(SyncBoards.self),
                AnyOperation(ListFolders.self),
                AnyOperation(ListScenes.self),
                AnyOperation(CreateScene.self),
                AnyOperation(UpdateScene.self),
                AnyOperation(DeleteScene.self),
                AnyOperation(AddItems.self),
                AnyOperation(AddTextItem.self),
                AnyOperation(AddShapeItem.self),
                AnyOperation(AddStickyItem.self),
                AnyOperation(AddTableItem.self),
                AnyOperation(GetTable.self),
                AnyOperation(SetTableCell.self),
                AnyOperation(ConnectItems.self),
                AnyOperation(UpdateItem.self),
                AnyOperation(DeleteItems.self),
                AnyOperation(DuplicateItems.self),
                AnyOperation(GroupItems.self),
                AnyOperation(UngroupItems.self),
                AnyOperation(AlignItems.self),
                AnyOperation(MoveItems.self),
                AnyOperation(CreateDiagram.self),
            ],
            context: context)
    }
}

/// Dependencies shared by every Freeform operation for the life of the process (or MCP session).
final class FreeformContext {
    let store: FreeformStore
    let importer: FreeformImporter
    let writer: FreeformWriter
    private let authoringAvailable: () -> Bool
    /// Opens Freeform when it is not running, so it imports queued content.
    let launchApp: () throws -> Void
    /// How long a write waits for Freeform to import and save the content.
    let importTimeout: TimeInterval

    init(
        store: FreeformStore = FreeformStore(), importer: FreeformImporter? = nil,
        writer: FreeformWriter? = nil,
        authoringAvailable: @escaping () -> Bool = {
            (!FreeformImporter.isAppRunning || !FreeformImporter.hasVisibleWindows
                || FreeformImporter.liveRefreshEnabled())
                && FreeformNativeBridge.status().isAvailable
        },
        launchApp: @escaping () throws -> Void = { try FreeformImporter.launchAppIfNeeded() },
        importTimeout: TimeInterval = 45
    ) {
        self.store = store
        self.importer = importer ?? FreeformImporter(groupContainer: store.groupContainer)
        self.writer = writer ?? FreeformWriter(store: store)
        self.authoringAvailable = authoringAvailable
        self.launchApp = launchApp
        self.importTimeout = importTimeout
    }

    func canAuthorNatively() -> Bool { authoringAvailable() }

    func snapshot<T>(_ body: (FreeformSnapshot) throws -> T) throws -> T {
        try store.withSnapshot(try store.requireLocation(), body)
    }

    func board(_ selector: String, in snapshot: FreeformSnapshot, includeDeleted: Bool = false) throws
        -> FreeformBoardSnapshot
    {
        try EntityResolver.resolve(
            selector, in: try snapshot.boards(includeDeleted: includeDeleted), type: "board", id: \.id,
            name: { $0.title ?? "" }, detail: { $0.lastActivityAt.map { DateOutput.iso($0) } })
    }
}

enum FreeformDoctor: AgentOperation {
    static let path = ["doctor"]
    static let summary = "Check Freeform, Full Disk Access, the board store and Freeform's model types."
    static let params: [Param] = []
    static let examples = ["doctor"]

    static func run(_ input: NoInput, _ context: FreeformContext) throws -> DoctorOutput {
        let store = context.store
        let app = Bundle(path: FreeformModelRuntime.appPath)
        let readable = store.groupContainerReadable()
        let location = try? store.locate()
        var model = "ok"
        do {
            let missing = try FreeformModelRuntime.load().missingTypes()
            if !missing.isEmpty { model = "missing: " + missing.joined(separator: ", ") }
        } catch {
            model = AgentError.from(error).message
        }
        let authoringStatus = FreeformNativeBridge.status()
        let buildUUID: String?
        switch authoringStatus {
        case .native(let uuid, _): buildUUID = uuid
        case .unsupportedBuild(let uuid, _): buildUUID = uuid
        case .unavailable: buildUUID = nil
        }
        let running = FreeformImporter.isAppRunning
        let visibleWindows = running && FreeformImporter.hasVisibleWindows
        let liveRefresh = FreeformImporter.liveRefreshEnabled()
        let abiResolution = (try? FreeformNativeBridge.load())?.resolutionMode.rawValue
        let authoringLabel =
            authoringStatus.isAvailable
            ? (visibleWindows ? (liveRefresh ? "native_live_refresh" : "native_paused_app_running") : "native")
            : authoringStatus.label
        let hint: String? =
            !readable
            ? "Give the app that runs freeform-cli Full Disk Access (System Settings > Privacy & Security), then restart it."
            : location == nil
                ? "No Freeform board store was found; open Freeform once to create it."
                : model != "ok"
                    ? "This Freeform version's model is not supported; reads may omit fields."
                    : !authoringStatus.isAvailable
                        ? "Native authoring is gated on verified Freeform builds; reads and import-inbox writes still work."
                        : (visibleWindows && !liveRefresh)
                            ? "Close or quit Freeform windows before running native authoring commands." : nil
        return DoctorOutput(
            app: "freeform", version: AgentApp<FreeformContext>.version,
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            osGeneration: OSGeneration.current.description,
            freeform: app?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            freeformBuild: app?.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            buildUUID: buildUUID,
            abiResolution: abiResolution,
            freeformRunning: running,
            freeformHasVisibleWindows: visibleWindows,
            liveRefresh: liveRefresh,
            permission: PermissionCoordinator().inspect(service: .fullDiskAccess).permission,
            groupContainerReadable: readable, store: location?.kind.rawValue,
            storeModifiedAt: location.flatMap { lastModified($0.database) }.map { DateOutput.iso($0) }, model: model,
            authoring: authoringLabel,
            authoringDetail: { if case .unavailable(let r) = authoringStatus { return r }; return nil }(),
            capabilities: DoctorCapabilities(
                supported: authoringStatus.isAvailable
                    ? [
                        "boards_read", "items_read_paginated", "search", "import_inbox_media_links",
                        "folders_read", "native_pdf_png_export", "native_scenes_crud",
                        "native_table_cells_read_write", "rich_text_styling", "board_appearance",
                        "live_quick_refresh", "idle_background_auto_close", "quiet_background_sync",
                        "native_text_shape_sticky", "native_bound_connectors", "native_update_move_style_delete",
                        "item_descriptions_and_replace_shape",
                        "native_group_duplicate_align", "native_diagram_batch",
                        "boards_rename_favorite_delete_restore",
                    ]
                    : ["boards_read", "folders_read", "items_read_paginated", "search", "import_inbox_media_links"],
                blocked: [
                    "shared_board_participant_writes", "collaboration_invites_and_presence",
                    "freehand_drawing_authoring", "folders_write", "live_icloud_push_while_closed",
                ]),
            hint: hint)
    }

    private static func lastModified(_ database: URL) -> Date? {
        ["", "-wal"].compactMap { suffix in
            try? FileManager.default.attributesOfItem(atPath: database.path + suffix)[.modificationDate] as? Date
        }.max()
    }
}

struct DoctorOutput: Encodable, Sendable {
    let app: String
    let version: String
    let os: String
    let osGeneration: String
    /// Installed Freeform version; nil when Freeform is not installed.
    let freeform: String?
    let freeformBuild: String?
    let buildUUID: String?
    let abiResolution: String?
    let freeformRunning: Bool
    let freeformHasVisibleWindows: Bool
    let liveRefresh: Bool
    /// Full Disk Access, named `permission` like every other app's doctor.
    let permission: String
    let groupContainerReadable: Bool
    /// `group_container` (current), `legacy_container` (pre-migration) or absent.
    let store: String?
    let storeModifiedAt: String?
    /// `ok` when every Freeform model type used for decoding resolves.
    let model: String
    /// `native`, `native_paused_app_running`, `unsupported_build` or `unavailable`.
    let authoring: String
    let authoringDetail: String?
    let capabilities: DoctorCapabilities
    let hint: String?
}

struct DoctorCapabilities: Encodable, Sendable {
    let supported: [String]
    let blocked: [String]
}
