import AppKit
import Foundation
import GesherPlatform
import ObjCRuntimeSupport
import ObjectiveC

/// Availability of the native in-process Freeform authoring engine on this Mac.
public enum FreeformAuthoringStatus: Sendable, Equatable {
    case native(buildUUID: String, version: String)
    case unsupportedBuild(buildUUID: String?, version: String?)
    case unavailable(reason: String)

    public var label: String {
        switch self {
        case .native: return "native"
        case .unsupportedBuild: return "unsupported_build"
        case .unavailable: return "unavailable"
        }
    }

    public var isAvailable: Bool {
        if case .native = self { return true }
        return false
    }
}

/// Verified, build-UUID-gated bridge into Freeform's own in-process persistence and command engine
/// (`CRLBoardDataStore`, `CRLBoard`, `CRLBoardItemFactory`, `CRLCommandController`).
///
/// Every item mutation goes through Freeform's own ObjC command classes and saves through
/// `CRLBoard -asyncSavePendingChangesWithCompletionHandler:`. No raw SQLite writes are performed.
/// The small set of unexported Swift bootstrap entry points (store open, board create/fetch/hydrate,
/// board lifecycle) is strictly gated on the loaded Freeform executable's Mach-O `LC_UUID`, class
/// presence, selector presence and ivar layout; any unrecognized Freeform build fails cleanly with
/// `unsupportedPrivateAPI` rather than calling unvalidated addresses.
public final class FreeformNativeBridge: @unchecked Sendable {
    struct Offsets: Sendable {
        let version: String
        let storeInit: UInt
        let fetchBoards: UInt
        let makeNewBoard: UInt
        let allocInitBoard: UInt
        let makeTransaction: UInt
        let markNewBoard: UInt
        let mergeDatabaseChanges: UInt
        let appendPendingChanges: UInt
        let transactionCommitVtableOffset: Int
        let setFavorite: UInt
        let setCanvasDotGrid: UInt
        let setConnectorMode: UInt
        let deleteBoard: UInt
        let undeleteBoard: UInt
        let boardCRDTDataMetadataAccessor: UInt
        let insertStyleCopyHelper: UInt
        let insertStyleTypeAccessor: UInt
    }

    /// Structural anchors resolvable across macOS/Freeform generations without hardcoded offsets.
    public struct DiscoveredAnchors: Sendable, Equatable {
        public let fetchBoards: UInt
        public let setFavorite: UInt
        public let setCanvasDotGrid: UInt
        public let setConnectorMode: UInt
        public let deleteBoard: UInt
        public let undeleteBoard: UInt
        public let appendPendingChanges: UInt
    }

    /// Dynamically locates the string-anchored CRLBoardDataStore/CRLBoardChangeSet functions in any
    /// loaded Freeform Mach-O image. Returns nil unless every single anchor resolves uniquely.
    public static func discoverAnchors(imageBase: UInt) -> DiscoveredAnchors? {
        guard let header = UnsafeRawPointer(bitPattern: imageBase),
            let scanner = MachOAnchorScanner(imageHeader: header)
        else { return nil }
        guard
            let fetchBoards = scanner.findFunctionByUniqueString(
                "Failed to fetch boardAndContainerData for board %{public}@"),
            let setFavorite = scanner.findFunctionByUniqueString(
                "Set favorite status to [%{public}@] for board identifier: %{public}@"),
            let setCanvasDotGrid = scanner.findFunctionByUniqueString(
                "Set canvas dot grid visible to [%{public}@] for board identifier: %{public}@"),
            let setConnectorMode = scanner.findFunctionByUniqueString(
                "Set connector mode enabled to [%{public}@] for board identifier: %{public}@"),
            let deleteBoard = scanner.findFunctionByUniqueString("Failed to mark board as deleted"),
            let undeleteBoard = scanner.findFunctionByUniqueString("Failed to reset board deletion"),
            let appendPendingChanges = scanner.findFunctionByUniqueString(
                "Pending changes should only come from closed transactions.")
        else { return nil }
        return DiscoveredAnchors(
            fetchBoards: fetchBoards, setFavorite: setFavorite, setCanvasDotGrid: setCanvasDotGrid,
            setConnectorMode: setConnectorMode, deleteBoard: deleteBoard, undeleteBoard: undeleteBoard,
            appendPendingChanges: appendPendingChanges)
    }

    /// Only builds whose exact Mach-O LC_UUID has been verified are allowed to execute Swift bootstrap calls.
    static let verifiedBuilds: [String: Offsets] = [
        // macOS 27.0 (26A428), Freeform 5.0 (656.1.2)
        "F65BAD7D-30CD-3E6A-BA48-0C8C23C9C446": Offsets(
            version: "5.0 (656.1.2)",
            storeInit: 0x877cc0,
            fetchBoards: 0x808a44,
            makeNewBoard: 0x131c270,
            allocInitBoard: 0x13131b4,
            makeTransaction: 0x135b8d0,
            markNewBoard: 0x695e64,
            mergeDatabaseChanges: 0x12fd5fc,
            appendPendingChanges: 0x6deb78,
            transactionCommitVtableOffset: 0x2f8,
            setFavorite: 0x80c390,
            setCanvasDotGrid: 0x80f1c4,
            setConnectorMode: 0x80f878,
            deleteBoard: 0x7fe608,
            undeleteBoard: 0x800dbc,
            boardCRDTDataMetadataAccessor: 0xde3594,
            insertStyleCopyHelper: 0x66f874,
            insertStyleTypeAccessor: 0xde3ee0
        ),
        // macOS 27.3 (26C5047e), Freeform 5.2 (656.60.8). Derived statically against the 5.0 build
        // (masked-instruction fingerprints, log-string anchors, Swift vtables and type descriptors).
        // makeNewBoard is not yet verified (0 = native board creation disabled for this build).
        "C5ED2770-4076-377E-97F6-C49FD8EFB724": Offsets(
            version: "5.2 (656.60.8)",
            storeInit: 0x88c2e4,
            fetchBoards: 0x81b234,
            makeNewBoard: 0,
            allocInitBoard: 0x13b2ccc,
            makeTransaction: 0x13ed02c,
            markNewBoard: 0x69ccd8,
            mergeDatabaseChanges: 0x139d158,
            appendPendingChanges: 0x6edbc8,
            transactionCommitVtableOffset: 0x2f8,
            setFavorite: 0x81fc00,
            setCanvasDotGrid: 0x822a34,
            setConnectorMode: 0x8230e8,
            deleteBoard: 0x810bcc,
            undeleteBoard: 0x813398,
            boardCRDTDataMetadataAccessor: 0xf87658,
            insertStyleCopyHelper: 0x673878,
            insertStyleTypeAccessor: 0xf87f60
        ),
    ]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: FreeformNativeBridge?

    let base: UInt
    let buildUUID: String
    let offsets: Offsets
    public let resolutionMode: ABIResolutionMode
    private let msgSend: UnsafeMutableRawPointer
    private let msgSendSuper2: UnsafeMutableRawPointer

    // Validated ObjC classes
    let storeClass: AnyClass
    let boardClass: AnyClass
    let boardDataClass: AnyClass
    let factoryClass: AnyClass
    let changeNotifierClass: AnyClass
    let selectionDispatcherClass: AnyClass
    let commandControllerClass: AnyClass
    let insertCommandClass: AnyClass
    let deleteCommandClass: AnyClass
    let setGeometryCommandClass: AnyClass
    let setFillCommandClass: AnyClass
    let setStrokeCommandClass: AnyClass
    let setLineEndCommandClass: AnyClass
    let setLockedCommandClass: AnyClass
    let setConnectionCommandClass: AnyClass
    let reorderCommandClass: AnyClass
    let reparentCommandClass: AnyClass
    let replaceTextCommandClass: AnyClass
    let dirtyBoardCommandClass: AnyClass
    let setPathSourceCommandClass: AnyClass
    let setDescriptionCommandClass: AnyClass
    let canvasImagerClass: AnyClass
    let tableProviderClass: AnyClass
    let geometryClass: AnyClass
    let colorFillClass: AnyClass
    let strokeClass: AnyClass
    let strokePatternClass: AnyClass
    let lineEndClass: AnyClass
    let connectionLineClass: AnyClass
    let connectionPathSourceClass: AnyClass
    let groupItemClass: AnyClass

    // Validated ivars
    let factoryBoardIvar: Ivar
    let factoryStyleIvar: Ivar
    let boardDataIvar: Ivar
    let boardDataCRDTIvar: Ivar

    /// Inspects whether the installed Freeform build supports native authoring without throwing.
    public static func status() -> FreeformAuthoringStatus {
        let appBundle = Bundle(path: FreeformModelRuntime.appPath)
        let shortVersion = appBundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let bundleVersion = appBundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let displayVersion = [shortVersion, bundleVersion.map { "(\($0))" }].compactMap { $0 }.joined(separator: " ")
        do {
            let runtime = try FreeformModelRuntime.load()
            guard let uuid = runtime.imageUUID else {
                return .unsupportedBuild(buildUUID: nil, version: displayVersion.isEmpty ? nil : displayVersion)
            }
            guard verifiedBuilds[uuid] != nil else {
                return .unsupportedBuild(buildUUID: uuid, version: displayVersion.isEmpty ? nil : displayVersion)
            }
            _ = try load()
            return .native(buildUUID: uuid, version: displayVersion.isEmpty ? "unknown" : displayVersion)
        } catch {
            if let runtime = try? FreeformModelRuntime.load(), let uuid = runtime.imageUUID, verifiedBuilds[uuid] == nil
            {
                return .unsupportedBuild(buildUUID: uuid, version: displayVersion.isEmpty ? nil : displayVersion)
            }
            return .unavailable(reason: error.localizedDescription)
        }
    }

    public static func load() throws -> FreeformNativeBridge {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let bridge = try FreeformNativeBridge()
        cached = bridge
        return bridge
    }

    private init() throws {
        let runtime = try FreeformModelRuntime.load()
        guard runtime.imageBase != 0, let uuid = runtime.imageUUID else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "Freeform.LC_UUID",
                reason: "Could not read the loaded Freeform executable's Mach-O UUID.")
        }
        guard let offsets = Self.verifiedBuilds[uuid] else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "Freeform.build(\(uuid))",
                reason:
                    "Native Freeform authoring is not verified for this Freeform build (\(uuid)). Read commands and import-inbox writes remain available."
            )
        }
        guard let msgSend = dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend"),
            let msgSendSuper2 = dlsym(dlopen(nil, RTLD_NOW), "objc_msgSendSuper2")
        else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "objc_msgSend", reason: "Objective-C runtime dispatch symbols are unavailable.")
        }

        func requireClass(_ name: String) throws -> AnyClass {
            guard let cls = NSClassFromString(name) else {
                throw PlatformError.missingClass(name)
            }
            return cls
        }

        func requireSelector(_ cls: AnyClass, _ selector: String, classMethod: Bool = false) throws {
            let sel = NSSelectorFromString(selector)
            let method = classMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel)
            guard method != nil else {
                throw PlatformError.missingSelector(className: NSStringFromClass(cls), selector: selector)
            }
        }

        func requireIvar(_ cls: AnyClass, _ name: String) throws -> Ivar {
            guard let ivar = class_getInstanceVariable(cls, name) else {
                throw PlatformError.unsupportedPrivateAPI(
                    selector: "\(NSStringFromClass(cls)).\(name)",
                    reason: "Expected ivar '\(name)' is missing on this Freeform build.")
            }
            return ivar
        }

        base = runtime.imageBase
        buildUUID = uuid
        self.offsets = offsets
        resolutionMode = .verifiedBuild
        self.msgSend = msgSend
        self.msgSendSuper2 = msgSendSuper2

        storeClass = try requireClass("Freeform.CRLBoardDataStore")
        boardClass = try requireClass("Freeform.CRLBoard")
        boardDataClass = try requireClass("Freeform.CRLBoardData")
        factoryClass = try requireClass("Freeform.CRLBoardItemFactory")
        changeNotifierClass = try requireClass("CRLChangeNotifier")
        selectionDispatcherClass = try requireClass("Freeform.CRLSelectionDispatcher")
        commandControllerClass = try requireClass("CRLCommandController")
        insertCommandClass = try requireClass("Freeform.CRLCommandInsertBoardItems")
        deleteCommandClass = try requireClass("Freeform.CRLCommandDeleteBoardItems")
        setGeometryCommandClass = try requireClass("Freeform.CRLCommandSetInfoGeometry")
        setFillCommandClass = try requireClass("Freeform.CRLCommandSetFill")
        setStrokeCommandClass = try requireClass("Freeform.CRLCommandSetStroke")
        setLineEndCommandClass = try requireClass("Freeform.CRLCommandSetLineEnd")
        setLockedCommandClass = try requireClass("Freeform.CRLCommandSetLocked")
        setConnectionCommandClass = try requireClass("Freeform.CRLCommandSetConnectionLineConnection")
        reorderCommandClass = try requireClass("Freeform.CRLCommandReorderContainerChildren")
        reparentCommandClass = try requireClass("Freeform.CRLCommandReparentBoardItems")
        replaceTextCommandClass = try requireClass("Freeform.CRLWPReplaceTextCommand")
        dirtyBoardCommandClass = try requireClass("Freeform.CRLCommandDirtyBoard")
        setPathSourceCommandClass = try requireClass("Freeform.CRLCommandSetPathSource")
        setDescriptionCommandClass = try requireClass("Freeform.CRLCommandSetAccessibilityDescription")
        canvasImagerClass = try requireClass("CRLCanvasImager")
        tableProviderClass = try requireClass("Freeform.CRLTableItemProvider")
        geometryClass = try requireClass("CRLCanvasInfoGeometry")
        colorFillClass = try requireClass("CRLColorFill")
        strokeClass = try requireClass("CRLStroke")
        strokePatternClass = try requireClass("CRLStrokePattern")
        lineEndClass = try requireClass("CRLLineEnd")
        connectionLineClass = try requireClass("Freeform.CRLConnectionLineItem")
        connectionPathSourceClass = try requireClass("CRLConnectionLinePathSource")
        groupItemClass = try requireClass("Freeform.CRLGroupItem")

        try requireSelector(storeClass, "openDatabaseWithCompletionHandler:")
        try requireSelector(storeClass, "closeDatabaseWithCompletionHandler:")
        try requireSelector(storeClass, "readQueue")
        try requireSelector(storeClass, "writeQueue")
        try requireSelector(boardClass, "rootContainer")
        try requireSelector(boardClass, "getBoardItemForUUID:")
        try requireSelector(boardClass, "asyncSavePendingChangesWithCompletionHandler:")
        try requireSelector(boardClass, "setTitle:")
        try requireSelector(factoryClass, "makeTextboxItemWithPosition:string:")
        try requireSelector(factoryClass, "makeTextboxItemWithAttributedString:")
        try requireSelector(factoryClass, "makeShapeItemWithShapeType:")
        try requireSelector(factoryClass, "makeStickyNoteItemWithAttributedString:")
        // Freeform 5.2 renamed this to makeTableItemWithRowCount:columnCount:geometry:textProvenance:;
        // table creation checks lazily (makeTable) so the rest of native authoring stays available.
        try requireSelector(tableProviderClass, "initWithAttributedString:geometry:")
        try requireSelector(tableProviderClass, "provideBoardItemWithFactory:completionHandler:")
        try requireSelector(factoryClass, "makeDuplicateOfBoardItems:")
        try requireSelector(factoryClass, "makeGroupItemWithGeometry:")
        try requireSelector(commandControllerClass, "initWithBoard:changeNotifier:selectionDispatcher:")
        try requireSelector(commandControllerClass, "enqueueNonUndoableCommand:")
        try requireSelector(commandControllerClass, "openGroup")
        try requireSelector(commandControllerClass, "closeGroup")
        try requireSelector(insertCommandClass, "initWithParentContainer:boardItems:")
        try requireSelector(deleteCommandClass, "initWithBoardItemsToDelete:")
        try requireSelector(setGeometryCommandClass, "initWithBoardItem:geometry:")
        try requireSelector(setFillCommandClass, "initWithShapeItem:fill:")
        try requireSelector(setStrokeCommandClass, "initWithStyledItem:stroke:")
        try requireSelector(setLineEndCommandClass, "initWithShapeItem:lineEnd:chirality:")
        try requireSelector(setLockedCommandClass, "initWithBoardItem:locked:")
        try requireSelector(setConnectionCommandClass, "initWithConnectionLine:connectedItem:chirality:")
        try requireSelector(reorderCommandClass, "initWithParentContainer:childrenToMove:targetIndices:")
        try requireSelector(reparentCommandClass, "initWithDestinationContainer:boardItems:")
        try requireSelector(replaceTextCommandClass, "initWithShapeItem:range:text:")
        try requireSelector(replaceTextCommandClass, "initWithParentItem:storage:range:text:")
        try requireSelector(setPathSourceCommandClass, "initWithShapeItem:pathSource:")
        try requireSelector(setDescriptionCommandClass, "initWithBoardItem:accessibilityDescription:")
        try requireSelector(canvasImagerClass, "initWithBoard:")
        try requireSelector(canvasImagerClass, "setInfos:")
        try requireSelector(canvasImagerClass, "pdfData")
        try requireSelector(canvasImagerClass, "pngData")
        try requireSelector(geometryClass, "initWithPosition:size:angle:")
        try requireSelector(colorFillClass, "colorWithRed:green:blue:alpha:", classMethod: true)
        try requireSelector(strokeClass, "strokeWithColor:width:pattern:", classMethod: true)
        try requireSelector(
            connectionLineClass,
            "initWithStore:parentContainerUUID:geometry:pathSource:stroke:headLineEnd:tailLineEnd:")
        try requireSelector(connectionPathSourceClass, "pathSourceAtAngleOfSize:forType:", classMethod: true)
        try requireSelector(groupItemClass, "groupGeometryFromChildrenInfos:", classMethod: true)
        try requireSelector(groupItemClass, "ungroupedGeometryForChildItem:")

        factoryBoardIvar = try requireIvar(factoryClass, "board")
        factoryStyleIvar = try requireIvar(factoryClass, "insertStyleSettings")
        boardDataIvar = try requireIvar(boardClass, "data")
        boardDataCRDTIvar = try requireIvar(boardDataClass, "crdtData")
    }

    // MARK: - Low-level ObjC dispatch helpers

    private func allocRaw(_ cls: AnyClass) -> UnsafeMutableRawPointer {
        typealias Fn = @convention(c) (AnyClass, Selector) -> UnsafeMutableRawPointer
        return unsafeBitCast(msgSend, to: Fn.self)(cls, NSSelectorFromString("alloc"))
    }

    private func initNoArg(_ cls: AnyClass) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(allocRaw(cls), NSSelectorFromString("init"))
    }

    func getObject(_ receiver: AnyObject, _ selector: String) -> AnyObject? {
        typealias Fn = @convention(c) (AnyObject, Selector) -> AnyObject?
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func getObjectArg(_ receiver: AnyObject, _ selector: String, _ arg: AnyObject) -> AnyObject? {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject?
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector), arg)
    }

    func sendVoid(_ receiver: AnyObject, _ selector: String) {
        typealias Fn = @convention(c) (AnyObject, Selector) -> Void
        unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func sendVoidId(_ receiver: AnyObject, _ selector: String, _ arg: AnyObject) {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector), arg)
    }

    func getInt(_ receiver: AnyObject, _ selector: String) -> Int {
        typealias Fn = @convention(c) (AnyObject, Selector) -> Int
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func getBool(_ receiver: AnyObject, _ selector: String) -> Bool {
        typealias Fn = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func getCGPoint(_ receiver: AnyObject, _ selector: String) -> CGPoint {
        typealias Fn = @convention(c) (AnyObject, Selector) -> CGPoint
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func getCGSize(_ receiver: AnyObject, _ selector: String) -> CGSize {
        typealias Fn = @convention(c) (AnyObject, Selector) -> CGSize
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func getDouble(_ receiver: AnyObject, _ selector: String) -> Double {
        typealias Fn = @convention(c) (AnyObject, Selector) -> Double
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func getCGRect(_ receiver: AnyObject, _ selector: String) -> CGRect {
        typealias Fn = @convention(c) (AnyObject, Selector) -> CGRect
        return unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector))
    }

    func sendVoidBool(_ receiver: AnyObject, _ selector: String, _ value: Bool) {
        typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> Void
        unsafeBitCast(msgSend, to: Fn.self)(receiver, NSSelectorFromString(selector), value)
    }

    private func fnPtr(_ offset: UInt) -> UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(bitPattern: base + offset)!
    }

    // MARK: - Store & Board Session

    /// Opens a `CRLBoardDataStore` rooted at `directory`, runs `body`, and closes it cleanly.
    func withStore<T>(at directory: URL, _ body: (AnyObject) throws -> T) throws -> T {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        let queue = DispatchQueue(label: "io.github.ephraimelgrabli.gesher.freeform.store")
        let rawAlloc = allocRaw(storeClass)
        let urlBuffer = UnsafeMutablePointer<URL>.allocate(capacity: 1)
        urlBuffer.initialize(to: directory)
        // Native Swift initializer consumes the URL copy; deallocate only.
        defer { urlBuffer.deallocate() }
        typealias InitStoreFn =
            @convention(c) (
                UnsafeRawPointer, UnsafeMutableRawPointer?, UnsafeMutableRawPointer, UnsafeMutableRawPointer
            ) -> UnsafeMutableRawPointer
        let rawStore = withExtendedLifetime(queue) {
            unsafeBitCast(fnPtr(offsets.storeInit), to: InitStoreFn.self)(
                urlBuffer, nil, Unmanaged.passUnretained(queue).toOpaque(), rawAlloc)
        }
        let store = Unmanaged<AnyObject>.fromOpaque(rawStore).takeRetainedValue()
        try openDatabase(store)
        defer { closeDatabase(store) }
        return try body(store)
    }

    private func openDatabase(_ store: AnyObject) throws {
        typealias OpenFn = @convention(c) (AnyObject, Selector, @escaping @convention(block) (NSError?) -> Void) -> Void
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var openError: NSError?
        unsafeBitCast(msgSend, to: OpenFn.self)(
            store, NSSelectorFromString("openDatabaseWithCompletionHandler:")
        ) { error in
            openError = error
            sem.signal()
        }
        guard sem.wait(timeout: .now() + 30) == .success else {
            throw PlatformError.storeInitializationFailed("Timed out opening Freeform's board store.")
        }
        if let openError {
            throw PlatformError.storeInitializationFailed(
                "Could not open Freeform's board store: \(openError.localizedDescription)")
        }
    }

    private func closeDatabase(_ store: AnyObject) {
        typealias CloseFn = @convention(c) (AnyObject, Selector, @escaping @convention(block) () -> Void) -> Void
        let sem = DispatchSemaphore(value: 0)
        unsafeBitCast(msgSend, to: CloseFn.self)(
            store, NSSelectorFromString("closeDatabaseWithCompletionHandler:")
        ) {
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 15)
    }

    func saveBoard(_ board: AnyObject) throws {
        typealias SaveFn =
            @convention(c) (
                AnyObject, Selector, @escaping @convention(block) (Bool, NSError?) -> Void
            ) -> Void
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var saved = false
        nonisolated(unsafe) var saveError: NSError?
        unsafeBitCast(msgSend, to: SaveFn.self)(
            board, NSSelectorFromString("asyncSavePendingChangesWithCompletionHandler:")
        ) { ok, error in
            saved = ok
            saveError = error
            sem.signal()
        }
        guard sem.wait(timeout: .now() + 30) == .success else {
            throw PlatformError.saveFailed("Timed out saving changes to Freeform's board store.")
        }
        if let saveError {
            throw PlatformError.saveFailed("Freeform failed to save board changes: \(saveError.localizedDescription)")
        }
        guard saved else {
            throw PlatformError.saveFailed("Freeform reported no pending changes were saved.")
        }
    }

    private struct RawBoardID {
        var uuid: UUID
        var ownerWord0: UInt
        var ownerWord1: UInt
    }

    /// Creates a new board inside `store` with both root containers initialized for persistence.
    func createBoard(in store: AnyObject, title: String) throws -> (board: AnyObject, id: UUID) {
        guard offsets.makeNewBoard != 0 else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "CRLBoardDataStore.makeNewBoard",
                reason: "Native board creation is not verified for Freeform \(offsets.version); use import-inbox creation.")
        }
        let boardUUID = UUID()
        let emptyOwner = ""
        let ownerWords = withUnsafeBytes(of: emptyOwner) { $0.load(as: (UInt, UInt).self) }
        let idBuffer = UnsafeMutablePointer<RawBoardID>.allocate(capacity: 1)
        idBuffer.initialize(to: RawBoardID(uuid: boardUUID, ownerWord0: ownerWords.0, ownerWord1: ownerWords.1))
        defer { idBuffer.deallocate() }

        let titleWords = withUnsafeBytes(of: title) { $0.load(as: (UInt, UInt).self) }
        typealias MakeBoardFn =
            @convention(c) (
                UnsafeMutableRawPointer, UnsafeRawPointer, UInt, UInt, UInt, UInt, UInt, UInt
            ) -> UnsafeMutableRawPointer
        let rawBoard = withExtendedLifetime((store, title)) {
            unsafeBitCast(fnPtr(offsets.makeNewBoard), to: MakeBoardFn.self)(
                Unmanaged.passUnretained(store).toOpaque(), idBuffer, titleWords.0, titleWords.1, 0, 0, 0, 0)
        }
        let board = Unmanaged<AnyObject>.fromOpaque(rawBoard).takeRetainedValue()

        // Mark board and both root containers in a closed transaction and enqueue into pendingChanges.
        let tx = makeTransaction(for: board, mode: 1)
        typealias MarkNewFn = @convention(c) (UnsafeMutableRawPointer, UInt, UnsafeMutableRawPointer) -> Void
        unsafeBitCast(fnPtr(offsets.markNewBoard), to: MarkNewFn.self)(
            Unmanaged.passUnretained(board).toOpaque(), 2, Unmanaged.passUnretained(tx).toOpaque())
        try commitTransaction(tx)
        try appendTransaction(tx, to: board, isNewBoard: true)
        return (board, boardUUID)
    }

    /// Fetches all boards (and optionally deleted boards) from `store`.
    func fetchAllBoards(in store: AnyObject, includeDeleted: Bool = false) throws -> AnyObject {
        guard let readQueue = getObject(store, "readQueue") as? DispatchQueue else {
            throw PlatformError.fetchFailed("Freeform store readQueue is unavailable.")
        }
        var rawResult: UnsafeMutableRawPointer?
        var rawError: UnsafeMutableRawPointer?
        let flags: UInt = includeDeleted ? 0x101 : 0
        readQueue.sync {
            rawResult = ObjCCallSwiftSelf3Throwing(
                fnPtr(offsets.fetchBoards), Unmanaged.passUnretained(store).toOpaque(), 0, 1, flags, &rawError)
        }
        if rawError != nil {
            throw PlatformError.fetchFailed("Freeform failed to fetch boards from the store.")
        }
        guard let rawResult else {
            throw PlatformError.fetchFailed("Freeform returned an empty board fetch result.")
        }
        return Unmanaged<AnyObject>.fromOpaque(rawResult).takeRetainedValue()
    }

    /// Loads an existing board by UUID into a live `CRLBoard` hydrated with all its items.
    func loadBoard(in store: AnyObject, id targetUUID: UUID) throws -> AnyObject {
        let fetchResult = try fetchAllBoards(in: store, includeDeleted: false)
        guard let (_, tupleValue) = findBoardEntry(in: fetchResult, uuid: targetUUID) else {
            throw AgentError.notFound("board", targetUUID.uuidString)
        }
        let fields = Array(Mirror(reflecting: tupleValue).children)
        guard fields.count >= 5 else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "CRLBoardDatabaseFetchResult",
                reason: "Unexpected tuple layout in Freeform's board fetch result.")
        }
        let boardData = fields[0].value as AnyObject
        let rootData = fields[1].value as AnyObject
        let altData = fields[2].value as AnyObject
        let ckShare = Mirror(reflecting: fields[3].value).children.first.map { $0.value as AnyObject }
        let makeUnsupported = (fields[4].value as? Bool) ?? false

        guard
            let rawBoard = ObjCCallSwiftSelf6(
                fnPtr(offsets.allocInitBoard),
                unsafeBitCast(boardClass, to: UnsafeMutableRawPointer.self),
                UInt(bitPattern: Unmanaged.passRetained(store).toOpaque()),
                UInt(bitPattern: Unmanaged.passRetained(boardData).toOpaque()),
                UInt(bitPattern: Unmanaged.passRetained(rootData).toOpaque()),
                UInt(bitPattern: Unmanaged.passRetained(altData).toOpaque()),
                ckShare.map { UInt(bitPattern: Unmanaged.passRetained($0).toOpaque()) } ?? 0,
                makeUnsupported ? 1 : 0)
        else {
            throw PlatformError.fetchFailed("Failed to initialize Freeform board \(targetUUID.uuidString).")
        }
        let board = Unmanaged<AnyObject>.fromOpaque(rawBoard).takeRetainedValue()

        // Hydrate every item from the fetch result into the live board.
        let tx = makeTransaction(for: board, mode: 1)
        var mergeError: UnsafeMutableRawPointer?
        _ = ObjCCallSwiftSelf4Throwing(
            fnPtr(offsets.mergeDatabaseChanges),
            Unmanaged.passUnretained(board).toOpaque(),
            UInt(bitPattern: Unmanaged.passUnretained(fetchResult).toOpaque()),
            UInt(bitPattern: Unmanaged.passUnretained(tx).toOpaque()),
            0, 2, &mergeError)
        if mergeError != nil {
            throw PlatformError.fetchFailed("Failed to hydrate items for Freeform board \(targetUUID.uuidString).")
        }
        try commitTransaction(tx)
        return board
    }

    func setFavorite(in store: AnyObject, boardID: UUID, favorite: Bool) throws {
        try setBoardBooleanMetadata(
            in: store, boardID: boardID, value: favorite, offset: offsets.setFavorite, label: "favorite status")
    }

    func setCanvasDotGrid(in store: AnyObject, boardID: UUID, visible: Bool) throws {
        try setBoardBooleanMetadata(
            in: store, boardID: boardID, value: visible, offset: offsets.setCanvasDotGrid, label: "canvas dot grid")
    }

    func setConnectorMode(in store: AnyObject, boardID: UUID, enabled: Bool) throws {
        try setBoardBooleanMetadata(
            in: store, boardID: boardID, value: enabled, offset: offsets.setConnectorMode, label: "connector mode")
    }

    private func setBoardBooleanMetadata(
        in store: AnyObject, boardID: UUID, value: Bool, offset: UInt, label: String
    ) throws {
        try withBoardIdentifierPointer(in: store, boardID: boardID, includeDeleted: false) { keyPtr in
            guard let writeQueue = getObject(store, "writeQueue") as? DispatchQueue else {
                throw PlatformError.saveFailed("Freeform store writeQueue is unavailable.")
            }
            var rawError: UnsafeMutableRawPointer?
            writeQueue.sync {
                _ = ObjCCallSwiftSelf3Throwing(
                    fnPtr(offset),
                    Unmanaged.passUnretained(store).toOpaque(),
                    value ? 1 : 0,
                    UInt(bitPattern: keyPtr),
                    0,
                    &rawError)
            }
            if rawError != nil {
                throw PlatformError.saveFailed("Freeform failed to update \(label) for \(boardID.uuidString).")
            }
        }
    }

    func deleteBoard(in store: AnyObject, boardID: UUID) throws {
        try withBoardIdentifierPointer(in: store, boardID: boardID, includeDeleted: false) { keyPtr in
            guard let writeQueue = getObject(store, "writeQueue") as? DispatchQueue else {
                throw PlatformError.saveFailed("Freeform store writeQueue is unavailable.")
            }
            var rawError: UnsafeMutableRawPointer?
            writeQueue.sync {
                _ = ObjCCallSwiftSelf3Throwing(
                    fnPtr(offsets.deleteBoard),
                    Unmanaged.passUnretained(store).toOpaque(),
                    UInt(bitPattern: keyPtr),
                    0, 0, &rawError)
            }
            if rawError != nil {
                throw PlatformError.saveFailed(
                    "Freeform failed to move board \(boardID.uuidString) to Recently Deleted.")
            }
        }
    }

    func undeleteBoard(in store: AnyObject, boardID: UUID) throws {
        try withBoardIdentifierPointer(in: store, boardID: boardID, includeDeleted: true) { keyPtr in
            guard let writeQueue = getObject(store, "writeQueue") as? DispatchQueue else {
                throw PlatformError.saveFailed("Freeform store writeQueue is unavailable.")
            }
            var rawError: UnsafeMutableRawPointer?
            writeQueue.sync {
                _ = ObjCCallSwiftSelf3Throwing(
                    fnPtr(offsets.undeleteBoard),
                    Unmanaged.passUnretained(store).toOpaque(),
                    UInt(bitPattern: keyPtr),
                    0, 0, &rawError)
            }
            if rawError != nil {
                throw PlatformError.saveFailed("Freeform failed to restore board \(boardID.uuidString).")
            }
        }
    }

    private func withBoardIdentifierPointer(
        in store: AnyObject, boardID: UUID, includeDeleted: Bool, _ body: (UnsafeRawPointer) throws -> Void
    ) throws {
        guard let idType = _typeByName("8Freeform18CRLBoardIdentifierV") as? any Decodable.Type else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "8Freeform18CRLBoardIdentifierV", reason: "CRLBoardIdentifier metadata is unavailable.")
        }
        let payload = try JSONSerialization.data(withJSONObject: [
            "storage": ["boardUUID": boardID.uuidString, "ownerName": ""]
        ])
        let key = try JSONDecoder().decode(idType, from: payload)
        func invoke<T>(_: T.Type) throws {
            guard var typed = key as? T else {
                throw PlatformError.unsupportedPrivateAPI(
                    selector: "CRLBoardIdentifier", reason: "Board identifier type mismatch.")
            }
            try withUnsafePointer(to: &typed) { try body(UnsafeRawPointer($0)) }
        }
        try _openExistential(type(of: key), do: invoke)
    }

    private func findBoardEntry(in fetchResult: AnyObject, uuid targetUUID: UUID) -> (key: Any, value: Any)? {
        guard
            let dict = Mirror(reflecting: fetchResult).children.first(where: {
                $0.label == "boardAndContainerDataDictionary"
            })?.value as? any Sequence
        else { return nil }
        for entry in dict {
            let children = Mirror(reflecting: entry).children
            guard let key = children.first(where: { $0.label == "key" })?.value,
                let value = children.first(where: { $0.label == "value" })?.value,
                let storage = Mirror(reflecting: key).children.first(where: { $0.label == "storage" })?.value
            else { continue }
            let foundUUID = Mirror(reflecting: storage).children.compactMap { $0.value as? UUID }.first
            if foundUUID == targetUUID { return (key, value) }
        }
        return nil
    }

    private func makeTransaction(for board: AnyObject, mode: UInt) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, UInt) -> UnsafeMutableRawPointer
        let raw = unsafeBitCast(fnPtr(offsets.makeTransaction), to: Fn.self)(
            Unmanaged.passUnretained(board).toOpaque(), mode)
        return Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue()
    }

    private func commitTransaction(_ tx: AnyObject) throws {
        let clsPtr = UnsafeRawPointer(Unmanaged.passUnretained(tx).toOpaque()).load(as: UnsafeRawPointer.self)
        let commitAddr =
            clsPtr.load(fromByteOffset: offsets.transactionCommitVtableOffset, as: UInt.self)
            & 0x0000_FFFF_FFFF_FFFF
        guard let commitFn = UnsafeMutableRawPointer(bitPattern: commitAddr) else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "CRLTransactionContext.commit", reason: "Transaction commit slot is null.")
        }
        var rawError: UnsafeMutableRawPointer?
        _ = ObjCCallSwiftSelf3Throwing(commitFn, Unmanaged.passUnretained(tx).toOpaque(), 0, 0, 0, &rawError)
        if rawError != nil {
            throw PlatformError.saveFailed("Failed to commit Freeform board transaction.")
        }
    }

    private func appendTransaction(_ tx: AnyObject, to board: AnyObject, isNewBoard: Bool) throws {
        guard
            let pendingObj = Mirror(reflecting: board).children.first(where: { $0.label == "pendingChanges" })?.value
                as AnyObject?,
            let pendingQueue = Mirror(reflecting: pendingObj).children.compactMap({ $0.value as? DispatchQueue }).first
        else {
            throw PlatformError.unsupportedPrivateAPI(
                selector: "CRLBoard.pendingChanges", reason: "Could not access Freeform board change set queue.")
        }
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer, UInt) -> Void
        let fn = unsafeBitCast(fnPtr(offsets.appendPendingChanges), to: Fn.self)
        pendingQueue.sync {
            fn(
                Unmanaged.passUnretained(tx).toOpaque(), Unmanaged.passUnretained(pendingObj).toOpaque(),
                isNewBoard ? 1 : 0)
        }
    }

    // MARK: - Factory & Command Controller (ObjC)

    func makeFactory(for board: AnyObject) -> AnyObject {
        let rawFactory = allocRaw(factoryClass)
        rawFactory.advanced(by: ivar_getOffset(factoryBoardIvar))
            .storeBytes(of: Unmanaged.passRetained(board).toOpaque(), as: UnsafeMutableRawPointer.self)

        let boardDataPtr = Unmanaged.passUnretained(board).toOpaque()
            .advanced(by: ivar_getOffset(boardDataIvar)).load(as: UnsafeMutableRawPointer.self)
        typealias MetaFn = @convention(c) (UInt) -> UnsafeRawPointer
        let crdtMeta = unsafeBitCast(fnPtr(offsets.boardCRDTDataMetadataAccessor), to: MetaFn.self)(0)
        let insertStyleOffset = Int(crdtMeta.load(fromByteOffset: 0x1c, as: Int32.self))
        let srcPtr = boardDataPtr.advanced(by: ivar_getOffset(boardDataCRDTIvar)).advanced(by: insertStyleOffset)
        let dstPtr = rawFactory.advanced(by: ivar_getOffset(factoryStyleIvar))

        typealias CopyFn =
            @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void
        unsafeBitCast(fnPtr(offsets.insertStyleCopyHelper), to: CopyFn.self)(
            srcPtr, dstPtr, fnPtr(offsets.insertStyleTypeAccessor))

        var sup = objc_super(receiver: Unmanaged<AnyObject>.fromOpaque(rawFactory), super_class: factoryClass)
        typealias SuperInitFn = @convention(c) (UnsafeMutablePointer<objc_super>, Selector) -> UnsafeMutableRawPointer
        let initialized = unsafeBitCast(msgSendSuper2, to: SuperInitFn.self)(&sup, NSSelectorFromString("init"))
        return Unmanaged<AnyObject>.fromOpaque(initialized).takeRetainedValue()
    }

    func makeCommandController(for board: AnyObject) -> AnyObject {
        let notifier = initNoArg(changeNotifierClass)
        let dispatcher = initNoArg(selectionDispatcherClass)
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(commandControllerClass),
            NSSelectorFromString("initWithBoard:changeNotifier:selectionDispatcher:"),
            board, notifier, dispatcher)
    }

    func enqueue(_ command: AnyObject, on controller: AnyObject) {
        sendVoidId(controller, "enqueueNonUndoableCommand:", command)
    }

    func withCommandGroup(on controller: AnyObject, _ body: () throws -> Void) rethrows {
        sendVoid(controller, "openGroup")
        defer { sendVoid(controller, "closeGroup") }
        try body()
    }

    // MARK: - ObjC Value & Item Constructors

    func makeGeometry(x: Double, y: Double, width: Double, height: Double, angle: Double = 0) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, CGPoint, CGSize, Double) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(geometryClass), NSSelectorFromString("initWithPosition:size:angle:"),
            CGPoint(x: x, y: y), CGSize(width: width, height: height), angle)
    }

    func makeColorFill(_ color: FreeformColor) -> AnyObject {
        typealias Fn = @convention(c) (AnyClass, Selector, Double, Double, Double, Double) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            colorFillClass, NSSelectorFromString("colorWithRed:green:blue:alpha:"),
            color.red, color.green, color.blue, color.alpha)
    }

    func makeStroke(color: FreeformColor, width: Double, pattern: FreeformStrokePatternKind) -> AnyObject {
        let colorFill = makeColorFill(color)
        let nativeColor = getObject(colorFill, "color")!
        let nativePattern = getObject(strokePatternClass, pattern.objcSelector)!
        typealias Fn = @convention(c) (AnyClass, Selector, AnyObject, Double, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            strokeClass, NSSelectorFromString("strokeWithColor:width:pattern:"), nativeColor, width, nativePattern)
    }

    func makeEmptyStroke() -> AnyObject {
        getObject(strokeClass, "emptyStroke")!
    }

    func makeLineEnd(_ kind: FreeformLineEndKind) -> AnyObject? {
        guard kind != .none else { return getObject(lineEndClass, "none") }
        return getObject(lineEndClass, kind.objcSelector)
    }

    func makeTextbox(factory: AnyObject, position: CGPoint, text: String) -> AnyObject {
        typealias Fn = @convention(c) (AnyObject, Selector, CGPoint, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            factory, NSSelectorFromString("makeTextboxItemWithPosition:string:"), position, text as NSString)
    }

    func makeAttributedTextbox(factory: AnyObject, attributedText: NSAttributedString) -> AnyObject {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            factory, NSSelectorFromString("makeTextboxItemWithAttributedString:"), attributedText)
    }

    func makeShape(factory: AnyObject, shapeType: Int) -> AnyObject {
        typealias Fn = @convention(c) (AnyObject, Selector, Int) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            factory, NSSelectorFromString("makeShapeItemWithShapeType:"), shapeType)
    }

    func makeSticky(factory: AnyObject, attributedText: NSAttributedString) -> AnyObject {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            factory, NSSelectorFromString("makeStickyNoteItemWithAttributedString:"),
            attributedText)
    }

    func makeTable(factory: AnyObject, rows: Int, columns: Int, geometry: AnyObject) throws -> AnyObject {
        let sel = NSSelectorFromString("makeTableItemWithRowCount:columnCount:geometry:")
        guard class_getInstanceMethod(factoryClass, sel) != nil else {
            throw PlatformError.missingSelector(
                className: NSStringFromClass(factoryClass), selector: "makeTableItemWithRowCount:columnCount:geometry:")
        }
        typealias Fn = @convention(c) (AnyObject, Selector, Int, Int, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            factory, NSSelectorFromString("makeTableItemWithRowCount:columnCount:geometry:"), rows, columns, geometry)
    }

    /// Builds a native populated `CRLTableItem` with live cell `CRLWPStorage`s via `CRLTableItemProvider`.
    func makePopulatedTable(factory: AnyObject, cells: [[String]], geometry: AnyObject, rtl: Bool) throws -> AnyObject {
        let rowCount = max(cells.count, 1)
        let colCount = max(cells.map(\.count).max() ?? 1, 1)
        let textTable = NSTextTable()
        textTable.numberOfColumns = colCount
        let attrString = NSMutableAttributedString()
        for r in 0..<rowCount {
            for c in 0..<colCount {
                let text = (r < cells.count && c < cells[r].count) ? cells[r][c] : ""
                let block = NSTextTableBlock(
                    table: textTable, startingRow: r, rowSpan: 1, startingColumn: c, columnSpan: 1)
                let para = NSMutableParagraphStyle()
                para.textBlocks = [block]
                if rtl || Self.containsRTL(text) { para.baseWritingDirection = .rightToLeft }
                attrString.append(NSAttributedString(string: text + "\n", attributes: [.paragraphStyle: para]))
            }
        }
        typealias InitFn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject) -> AnyObject
        let provider = unsafeBitCast(msgSend, to: InitFn.self)(
            allocRaw(tableProviderClass), NSSelectorFromString("initWithAttributedString:geometry:"), attrString,
            geometry)
        typealias ProvideFn =
            @convention(c) (AnyObject, Selector, AnyObject, @escaping @convention(block) () -> Void)
            -> Void
        let sem = DispatchSemaphore(value: 0)
        unsafeBitCast(msgSend, to: ProvideFn.self)(
            provider, NSSelectorFromString("provideBoardItemWithFactory:completionHandler:"), factory
        ) {
            sem.signal()
        }
        guard sem.wait(timeout: .now() + 15) == .success,
            let tableItem = getObject(provider, "boardItem")
        else {
            throw PlatformError.saveFailed("Freeform failed to create populated table.")
        }
        return tableItem
    }

    private static func containsRTL(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0590...0x05FF).contains(scalar.value) || (0x0600...0x06FF).contains(scalar.value)
        }
    }

    /// Reads the dimensions, RTL flag and cell text matrix of a live `CRLTableItem`.
    func readTable(_ tableItem: AnyObject) -> FreeformTableSnapshot {
        let rows = getInt(tableItem, "rowCount")
        let cols = getInt(tableItem, "columnCount")
        let rtl = getBool(tableItem, "isRTL")
        let rowIDs = ((getObject(tableItem, "allRowIDs") as? [NSUUID]) ?? []).map(\.uuidString)
        let colIDs = ((getObject(tableItem, "allColumnIDs") as? [NSUUID]) ?? []).map(\.uuidString)
        var grid = Array(repeating: Array(repeating: "", count: cols), count: rows)
        let storages = (getObject(tableItem, "wpStorages") as? [AnyObject]) ?? []
        for storage in storages {
            guard let (rIdx, cIdx) = cellPosition(of: storage, in: tableItem, rowIDs: rowIDs, colIDs: colIDs),
                rIdx < rows, cIdx < cols
            else { continue }
            grid[rIdx][cIdx] = plainText(of: storage)
        }
        return FreeformTableSnapshot(
            id: itemUUIDString(tableItem) ?? "", rows: rows, columns: cols, rtl: rtl, cells: grid)
    }

    /// Finds the `CRLWPStorage` for cell (row, col) in a `CRLTableItem` and creates an in-place text replace command.
    func makeSetTableCellCommand(tableItem: AnyObject, row: Int, column: Int, text: String) throws -> AnyObject {
        let rows = getInt(tableItem, "rowCount")
        let cols = getInt(tableItem, "columnCount")
        guard row >= 0, row < rows, column >= 0, column < cols else {
            throw AgentError.invalid(
                "Cell (\(row), \(column)) is out of bounds for this \(rows)x\(cols) table.",
                hint: "Use 0-based indices: row 0..\(max(rows - 1, 0)), column 0..\(max(cols - 1, 0)).")
        }
        let rowIDs = ((getObject(tableItem, "allRowIDs") as? [NSUUID]) ?? []).map(\.uuidString)
        let colIDs = ((getObject(tableItem, "allColumnIDs") as? [NSUUID]) ?? []).map(\.uuidString)
        let storages = (getObject(tableItem, "wpStorages") as? [AnyObject]) ?? []
        for storage in storages {
            if let (rIdx, cIdx) = cellPosition(of: storage, in: tableItem, rowIDs: rowIDs, colIDs: colIDs),
                rIdx == row && cIdx == column
            {
                let len = storageLength(storage)
                typealias Fn =
                    @convention(c) (
                        UnsafeMutableRawPointer, Selector, AnyObject, AnyObject, NSRange, AnyObject
                    ) -> AnyObject
                return unsafeBitCast(msgSend, to: Fn.self)(
                    allocRaw(replaceTextCommandClass),
                    NSSelectorFromString("initWithParentItem:storage:range:text:"),
                    tableItem, storage, NSRange(location: 0, length: len), text as NSString)
            }
        }
        throw AgentError(
            code: "cell_uninitialized",
            message:
                "Cell (\(row), \(column)) has no backing text storage yet (the table was created without pre-seeded cells).",
            hint: "Create tables with items add-table (which initializes all cells) or edit the cell once in Freeform.")
    }

    private func cellPosition(
        of storage: AnyObject, in tableItem: AnyObject, rowIDs: [String], colIDs: [String]
    ) -> (row: Int, column: Int)? {
        guard let subSel = getObjectArg(tableItem, "subSelectionForSelectingTextInStorage:", storage) else {
            return nil
        }
        let reflected = Reflected(subSel)
        guard let cellID = reflected["range.currentCellID"] ?? reflected["range.baseCellID"] else { return nil }
        let desc = String(describing: cellID.value)
        // Format from CRLTableCellID: "[r:<UUID>, c:<UUID>]"
        let uuids = desc.matches(of: /[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/)
            .map { String($0.output).uppercased() }
        guard uuids.count >= 2,
            let rIdx = rowIDs.firstIndex(where: { $0.uppercased() == uuids[0] }),
            let cIdx = colIDs.firstIndex(where: { $0.uppercased() == uuids[1] })
        else { return nil }
        return (rIdx, cIdx)
    }

    private func storageLength(_ storage: AnyObject) -> Int {
        if storage.responds(to: NSSelectorFromString("storageLength")) {
            return max(0, getInt(storage, "storageLength"))
        }
        if storage.responds(to: NSSelectorFromString("characterCount")) {
            return max(0, getInt(storage, "characterCount"))
        }
        return 0
    }

    private func plainText(of storage: AnyObject) -> String {
        let len = storageLength(storage)
        guard len > 0 else { return "" }
        if storage.responds(to: NSSelectorFromString("substringWithRange:")) {
            typealias SubFn = @convention(c) (AnyObject, Selector, NSRange) -> AnyObject?
            if let raw = unsafeBitCast(msgSend, to: SubFn.self)(
                storage, NSSelectorFromString("substringWithRange:"), NSRange(location: 0, length: len)) as? String
            {
                return raw.hasSuffix("\n") ? String(raw.dropLast()) : raw
            }
        }
        return ""
    }

    func makeSetPathSourceCommand(shapeItem: AnyObject, pathSource: AnyObject) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setPathSourceCommandClass), NSSelectorFromString("initWithShapeItem:pathSource:"), shapeItem,
            pathSource)
    }

    func makeSetDescriptionCommand(item: AnyObject, description: String) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setDescriptionCommandClass),
            NSSelectorFromString("initWithBoardItem:accessibilityDescription:"), item, description as NSString)
    }

    func renderBoard(_ board: AnyObject, format: FreeformExportFormat) throws -> Data {
        typealias InitFn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject) -> AnyObject
        let imager = unsafeBitCast(msgSend, to: InitFn.self)(
            allocRaw(canvasImagerClass), NSSelectorFromString("initWithBoard:"), board)
        let root = getObject(board, "rootContainer")
        let items = (root.flatMap { getObject($0, "childItems") } as? [AnyObject]) ?? []
        sendVoidId(imager, "setInfos:", items as NSArray)
        let selector = format == .pdf ? "pdfData" : "pngData"
        guard let data = getObject(imager, selector) as? Data, !data.isEmpty else {
            throw PlatformError.fetchFailed(
                "Freeform's canvas renderer returned no \(format.rawValue.uppercased()) data (is the board empty?).")
        }
        return data
    }

    func listScenes(on board: AnyObject) -> [FreeformSceneSnapshot] {
        let infos = (getObject(board, "sceneInfos") as? [AnyObject]) ?? []
        return infos.enumerated().compactMap { index, info in
            let rect = getCGRect(info, "savedUnscaledRect")
            let uuid = Mirror(reflecting: info).children.compactMap { child -> UUID? in
                if let u = child.value as? UUID { return u }
                if let u = child.value as? NSUUID { return u as UUID }
                return nil
            }.first
            guard let uuid else { return nil }
            let name = getObjectArg(board, "getSceneName:", uuid as NSUUID) as? String
            return FreeformSceneSnapshot(
                id: uuid.uuidString, name: name?.isEmpty == true ? nil : name, index: index,
                x: Double(rect.origin.x), y: Double(rect.origin.y),
                width: Double(rect.size.width), height: Double(rect.size.height))
        }
    }

    func createScene(on board: AnyObject, id: UUID, rect: CGRect, name: String?) throws {
        typealias CreateFn = @convention(c) (AnyObject, Selector, AnyObject, CGRect) -> AnyObject?
        guard
            unsafeBitCast(msgSend, to: CreateFn.self)(
                board, NSSelectorFromString("createSceneWithSceneID:savedRect:"), id as NSUUID, rect) != nil
        else {
            throw PlatformError.saveFailed("Freeform failed to create scene \(id.uuidString).")
        }
        if let name {
            _ = setSceneName(on: board, id: id, name: name)
        }
    }

    @discardableResult
    func setSceneName(on board: AnyObject, id: UUID, name: String) -> Bool {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Bool
        return unsafeBitCast(msgSend, to: Fn.self)(
            board, NSSelectorFromString("setSceneName::"), id as NSUUID, name as NSString)
    }

    @discardableResult
    func setSceneRect(on board: AnyObject, id: UUID, rect: CGRect) -> Bool {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject, CGRect) -> Bool
        return unsafeBitCast(msgSend, to: Fn.self)(
            board, NSSelectorFromString("setSceneSavedRect::"), id as NSUUID, rect)
    }

    @discardableResult
    func deleteScene(on board: AnyObject, id: UUID) -> Bool {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> Bool
        return unsafeBitCast(msgSend, to: Fn.self)(board, NSSelectorFromString("deleteSceneWith:"), id as NSUUID)
    }

    func makeConnectionLine(
        store: AnyObject, rootContainerID: AnyObject, geometry: AnyObject, style: FreeformConnectorStyle,
        stroke: AnyObject, headLineEnd: AnyObject?, tailLineEnd: AnyObject?
    ) -> AnyObject {
        let size = getCGSize(geometry, "size")
        let pathSize = CGSize(width: max(abs(size.width), 40), height: max(abs(size.height), 10))
        typealias PathFn = @convention(c) (AnyClass, Selector, CGSize, Int) -> AnyObject
        let pathSource = unsafeBitCast(msgSend, to: PathFn.self)(
            connectionPathSourceClass, NSSelectorFromString("pathSourceAtAngleOfSize:forType:"),
            pathSize, style.nativeType)
        typealias InitFn =
            @convention(c) (
                UnsafeMutableRawPointer, Selector, AnyObject, AnyObject, AnyObject, AnyObject, AnyObject, AnyObject?,
                AnyObject?
            ) -> AnyObject
        return unsafeBitCast(msgSend, to: InitFn.self)(
            allocRaw(connectionLineClass),
            NSSelectorFromString(
                "initWithStore:parentContainerUUID:geometry:pathSource:stroke:headLineEnd:tailLineEnd:"),
            store, rootContainerID, geometry, pathSource, stroke, headLineEnd, tailLineEnd)
    }

    func duplicateBoardItems(factory: AnyObject, items: [AnyObject]) -> [AnyObject] {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject?
        return
            (unsafeBitCast(msgSend, to: Fn.self)(
                factory, NSSelectorFromString("makeDuplicateOfBoardItems:"), items as NSArray) as? [AnyObject]) ?? []
    }

    func makeGroup(factory: AnyObject, items: [AnyObject]) throws -> AnyObject {
        typealias GeomFn = @convention(c) (AnyClass, Selector, AnyObject) -> AnyObject
        let groupGeometry = unsafeBitCast(msgSend, to: GeomFn.self)(
            groupItemClass, NSSelectorFromString("groupGeometryFromChildrenInfos:"), items as NSArray)
        guard let group = getObjectArg(factory, "makeGroupItemWithGeometry:", groupGeometry) else {
            throw PlatformError.saveFailed("Could not create Freeform group.")
        }
        return group
    }

    func ungroupedGeometry(group: AnyObject, child: AnyObject) -> AnyObject? {
        getObjectArg(group, "ungroupedGeometryForChildItem:", child)
    }

    // MARK: - ObjC Commands

    func makeInsertCommand(parentContainer: AnyObject, items: [AnyObject]) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(insertCommandClass), NSSelectorFromString("initWithParentContainer:boardItems:"),
            parentContainer, items as NSArray)
    }

    func makeDeleteCommand(items: [AnyObject]) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(deleteCommandClass), NSSelectorFromString("initWithBoardItemsToDelete:"), items as NSArray)
    }

    func makeSetGeometryCommand(item: AnyObject, geometry: AnyObject) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setGeometryCommandClass), NSSelectorFromString("initWithBoardItem:geometry:"), item, geometry)
    }

    func makeSetFillCommand(shapeItem: AnyObject, fill: AnyObject?) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject?) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setFillCommandClass), NSSelectorFromString("initWithShapeItem:fill:"), shapeItem, fill)
    }

    func makeSetStrokeCommand(styledItem: AnyObject, stroke: AnyObject) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setStrokeCommandClass), NSSelectorFromString("initWithStyledItem:stroke:"), styledItem, stroke)
    }

    func makeSetLineEndCommand(shapeItem: AnyObject, lineEnd: AnyObject?, chirality: Int) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject?, Int) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setLineEndCommandClass), NSSelectorFromString("initWithShapeItem:lineEnd:chirality:"),
            shapeItem, lineEnd, chirality)
    }

    func makeSetLockedCommand(item: AnyObject, locked: Bool) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, Bool) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setLockedCommandClass), NSSelectorFromString("initWithBoardItem:locked:"), item, locked)
    }

    func makeSetConnectionCommand(connector: AnyObject, targetItem: AnyObject?, chirality: Int) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject?, Int) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(setConnectionCommandClass),
            NSSelectorFromString("initWithConnectionLine:connectedItem:chirality:"),
            connector, targetItem, chirality)
    }

    func makeReorderCommand(parentContainer: AnyObject, children: [AnyObject], targetIndices: IndexSet) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(reorderCommandClass),
            NSSelectorFromString("initWithParentContainer:childrenToMove:targetIndices:"),
            parentContainer, children as NSArray, targetIndices as NSIndexSet)
    }

    func makeReparentCommand(destinationContainer: AnyObject, items: [AnyObject]) -> AnyObject {
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(reparentCommandClass), NSSelectorFromString("initWithDestinationContainer:boardItems:"),
            destinationContainer, items as NSArray)
    }

    func makeDirtyBoardCommand() -> AnyObject {
        initNoArg(dirtyBoardCommandClass)
    }

    func makeReplaceAllTextCommand(shapeItem: AnyObject, text: String) -> AnyObject {
        var existingLength = 0
        if let storage = getObject(shapeItem, "textStorage") ?? getObject(shapeItem, "text") {
            let lenSel = NSSelectorFromString("storageLength")
            if storage.responds(to: lenSel) {
                existingLength = max(0, getInt(storage, "storageLength"))
            } else if storage.responds(to: NSSelectorFromString("characterCount")) {
                existingLength = max(0, getInt(storage, "characterCount"))
            }
        }
        typealias Fn = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, NSRange, AnyObject) -> AnyObject
        return unsafeBitCast(msgSend, to: Fn.self)(
            allocRaw(replaceTextCommandClass), NSSelectorFromString("initWithShapeItem:range:text:"),
            shapeItem, NSRange(location: 0, length: existingLength), text as NSString)
    }

    func itemUUIDString(_ item: AnyObject) -> String? {
        (getObject(item, "id") as? NSUUID)?.uuidString
    }

    func itemGeometryRect(_ item: AnyObject) -> (x: Double, y: Double, width: Double, height: Double, angle: Double)? {
        guard let geometry = getObject(item, "geometry") else { return nil }
        let pos = getCGPoint(geometry, "position")
        let size = getCGSize(geometry, "size")
        let angle = getDouble(geometry, "angle")
        return (pos.x, pos.y, size.width, size.height, angle)
    }
}
