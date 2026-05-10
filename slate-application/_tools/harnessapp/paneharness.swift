import Cocoa
import ObjectiveC.runtime
import UniformTypeIdentifiers

private var gHarnessRuntimeExecutablePath: String = ""

private func canonicalExecutablePath(_ path: String) -> String {
    var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
    if realpath(path, &resolved) != nil {
        return String(cString: resolved)
    }
    return path
}

private enum HarnessConfig {
    static let controlsHeight: CGFloat = 48.0
    static let defaultPaneHeight: CGFloat = 360.0
    static let defaultContentHeight: CGFloat = controlsHeight + defaultPaneHeight
    static let defaultWindowRect = NSRect(x: 100, y: 100, width: 1280, height: defaultContentHeight)
    static let minimumContentWidth: CGFloat = 900.0
    static let minimumContentHeight: CGFloat = defaultContentHeight
    static let toolbarInsetX: CGFloat = 12.0
    static let toolbarControlGap: CGFloat = 8.0
    static let toolbarCurrentSizeWidth: CGFloat = 172.0
    static let toolbarCurrentSizeGapAfterReadout: CGFloat = 12.0
    static let toolbarStatusRightInset: CGFloat = 14.0

    static let envRepoRootPath = "SLATE_HARNESS_REPO_ROOT"
    static let slateAdapterExecutableName = "Slate"
    static let slatePackageRuntimeExecutableName = "SlatePackageRuntime"
    static let slateChapterRuntimeExecutableName = "SlateChapterRuntime"
    static let slateTrackRuntimeExecutableName = "SlateTrackRuntime"
    static let slateValidationRuntimeExecutableName = "SlateValidationRuntime"
    static let slateReviewRuntimeExecutableName = "SlateReviewRuntime"
    static let slateTimelineRuntimeExecutableName = "SlateTimelineRuntime"
    static let movieFixtureRelativeDirectory = "media_mov/valid"

    static let smallFixtureRelativePathCandidates = [
        "media_pkg/valid/source-basic.itmsp/metadata.xml",
        "media_pkg/valid/source-basic-01.itmsp/metadata.xml"
    ]
    static let bigFixtureRelativePathCandidates = [
        "media_pkg/valid/source-chapters-crop.itmsp/metadata.xml"
    ]
}

private enum HarnessValidation {
    static let reportSchemaVersion = "1"
    static let observedStateSchemaVersion = "validationObservedState.v1"

    static let keySchemaVersion = "schemaVersion"
    static let keyFindings = "findings"
    static let keyOperatorText = "operatorText"

    static let findingKeyCode = "code"
    static let findingKeySeverity = "severity"
    static let findingKeyCategory = "category"
    static let findingKeyScope = "scope"
    static let findingKeyTitle = "title"
    static let findingKeyEvidence = "evidence"

    static let categoryTracks = "tracks"
    static let categoryRoles = "roles"
    static let categoryPackage = "package"
    static let categoryMetadata = "metadata"
    static let categoryChapters = "chapters"
}

private func fourCharCode(_ text: String) -> OSType {
    var result: UInt32 = 0
    for scalar in text.utf8.prefix(4) {
        result = (result << 8) | UInt32(scalar)
    }
    return result
}

private func fourCharString(_ code: OSType) -> String {
    let bytes = [
        UInt8((code >> 24) & 0xff),
        UInt8((code >> 16) & 0xff),
        UInt8((code >> 8) & 0xff),
        UInt8(code & 0xff)
    ]
    return String(bytes: bytes, encoding: .macOSRoman) ?? String(format: "%08X", code)
}

private enum HarnessAppleEvent {
    static let eventClass = fourCharCode("SLAT")
    static let ping = fourCharCode("PING")
    static let setMode = fourCharCode("SMOD")
    static let setWindow = fourCharCode("SWND")
    static let loadFixture = fourCharCode("FPTH")
    static let trackMovieDetails = fourCharCode("TDET")
    static let chapterDetails = fourCharCode("CDET")
    static let snapshot = fourCharCode("SNAP")
    static let handledEventIDs: [OSType] = [ping, setMode, setWindow, loadFixture, trackMovieDetails, chapterDetails, snapshot]
}

private func isSlateRepositoryRoot(_ url: URL) -> Bool {
    let fm = FileManager.default
    return fm.fileExists(atPath: url.appendingPathComponent("Slate.xcodeproj").path)
}

private func findRepositoryRootByWalkingUp(from start: URL, maxDepth: Int = 12) -> URL? {
    var current = start.standardizedFileURL
    var isDir: ObjCBool = false
    if !FileManager.default.fileExists(atPath: current.path, isDirectory: &isDir) || !isDir.boolValue {
        current = current.deletingLastPathComponent()
    }

    for _ in 0...maxDepth {
        if isSlateRepositoryRoot(current) {
            return current
        }
        let parent = current.deletingLastPathComponent()
        if parent.path == current.path {
            break
        }
        current = parent
    }

    return nil
}

private func resolveRepositoryRoot() -> URL {
    let env = ProcessInfo.processInfo.environment
    if let overridePath = env[HarnessConfig.envRepoRootPath], !overridePath.isEmpty {
        let url = URL(fileURLWithPath: overridePath)
        if isSlateRepositoryRoot(url) {
            return url
        }
        fatalError("Invalid \(HarnessConfig.envRepoRootPath): \(overridePath)")
    }

    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    if let found = findRepositoryRootByWalkingUp(from: cwd) {
        return found
    }

    let executableRoot = Bundle.main.bundleURL
    if let found = findRepositoryRootByWalkingUp(from: executableRoot) {
        return found
    }

    fatalError("Unable to locate Slate repository root. Set \(HarnessConfig.envRepoRootPath).")
}

private func resolveFixtureRootURL(repoRootURL: URL) -> URL {
    let fm = FileManager.default
    let candidates = [
        repoRootURL.appendingPathComponent("fixtures", isDirectory: true),
        repoRootURL.appendingPathComponent("slate-validation-engine/fixtures", isDirectory: true),
        repoRootURL.deletingLastPathComponent().appendingPathComponent("fixtures", isDirectory: true)
    ]

    for candidate in candidates {
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return candidate
        }
    }

    return candidates[0]
}

private func executableExists(_ executableURL: URL) -> Bool {
    let fm = FileManager.default
    var isDir: ObjCBool = false
    if !fm.fileExists(atPath: executableURL.path, isDirectory: &isDir) || isDir.boolValue {
        return false
    }
    return fm.isExecutableFile(atPath: executableURL.path)
}

private func siblingSlateAdapterExecutableURL() -> URL {
    Bundle.main.bundleURL
        .deletingLastPathComponent()
        .appendingPathComponent("Slate.app", isDirectory: true)
        .appendingPathComponent("Contents", isDirectory: true)
        .appendingPathComponent("MacOS", isDirectory: true)
        .appendingPathComponent(HarnessConfig.slateAdapterExecutableName, isDirectory: false)
}

private func siblingRuntimeExecutableURL(named executableName: String) -> URL {
    Bundle.main.bundleURL
        .deletingLastPathComponent()
        .appendingPathComponent(executableName, isDirectory: false)
}

private func requiredControllerClass(_ name: String) -> NSViewController.Type? {
    let candidates = [name, "Slate.\(name)", "slate.\(name)"]
    for candidate in candidates {
        if let cls = NSClassFromString(candidate) as? NSViewController.Type {
            return cls
        }
        if let cls = objc_getClass(candidate) as? NSViewController.Type {
            return cls
        }
    }

    return nil
}

private func runtimeClassExists(_ name: String) -> Bool {
    let candidates = [name, "Slate.\(name)", "slate.\(name)"]
    for candidate in candidates {
        if NSClassFromString(candidate) != nil {
            return true
        }
        if objc_getClass(candidate) != nil {
            return true
        }
    }
    return false
}

private func instantiateController(className: String) -> NSViewController? {
    guard let cls = requiredControllerClass(className) else {
        return nil
    }
    let controller = cls.init()
    controller.loadView()
    controller.view.isHidden = false
    controller.view.autoresizingMask = [.width, .height]
    return controller
}

@discardableResult
private func invokeObject(_ target: AnyObject, selectorName: String, object: AnyObject?) -> Unmanaged<AnyObject>? {
    let selector = NSSelectorFromString(selectorName)
    guard target.responds(to: selector) else {
        return nil
    }
    return target.perform(selector, with: object)
}

@discardableResult
private func invokeNoArgs(_ target: AnyObject, selectorName: String) -> Unmanaged<AnyObject>? {
    let selector = NSSelectorFromString(selectorName)
    guard target.responds(to: selector) else {
        return nil
    }
    return target.perform(selector)
}

private func invokeCGFloat(_ target: AnyObject, selectorName: String, value: CGFloat) {
    let selector = NSSelectorFromString(selectorName)
    guard target.responds(to: selector),
          let method = class_getInstanceMethod(type(of: target), selector) else {
        return
    }

    typealias Function = @convention(c) (AnyObject, Selector, CGFloat) -> Void
    let implementation = method_getImplementation(method)
    let function = unsafeBitCast(implementation, to: Function.self)
    function(target, selector, value)
}

private enum HarnessMode: String {
    case chapter
    case track
    case package
}

final class PaneHarnessApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    @objc dynamic var delegate: AnyObject { self }
    @objc dynamic var movie: AnyObject?
    @objc dynamic var movieFrameRate: Double = 24.0
    @objc dynamic var hasMovie: NSNumber { NSNumber(value: movie != nil) }

    @objc(codec:)
    func codec(_ trackMedia: Any?) -> String {
        _ = trackMedia
        return ""
    }

    @objc(setMovieIsDirty:)
    func setMovieIsDirty(_ dirty: Bool) {
        _ = dirty
    }

    @objc(showStatusMessage:persist:)
    func showStatusMessage(_ message: String, persist: Bool) {
        _ = persist
        updateStatus(message)
    }

    @objc(showChapterCropRectStatusWithTop:left:bottom:right:context:suffix:persist:)
    func showChapterCropRectStatusWithTop(_ top: CGFloat,
                                          left: CGFloat,
                                          bottom: CGFloat,
                                          right: CGFloat,
                                          context: String?,
                                          suffix: String?,
                                          persist: Bool) {
        _ = persist
        let label = trimmedStatusPart(context) ?? "Chapter crop rect"
        var message = String(format: "%@ TL{%.0f %.0f} BR{%.0f %.0f}",
                             label,
                             Double(top),
                             Double(left),
                             Double(bottom),
                             Double(right))
        if let normalizedSuffix = trimmedStatusPart(suffix) {
            message += " \(normalizedSuffix)"
        }
        updateStatus(message)
    }

    @objc(refreshValidationViewAdapters)
    func refreshValidationViewAdapters() {
        refreshCanonicalValidationFindings()
    }

    @objc(refreshTimelineDurationFromPlaybackState)
    func refreshTimelineDurationFromPlaybackState() {
    }

    @objc(syncSidecarVisibilityState)
    func syncSidecarVisibilityState() {
    }

    @objc(playerView)
    func playerView() -> AnyObject? {
        return nil
    }

    private var didStart = false
    private var window: NSWindow!
    private let rootView = NSView(frame: .zero)
    private let controlsView = NSView(frame: .zero)
    private let paneHostView = NSView(frame: .zero)
    private let modeSegment = NSSegmentedControl(labels: ["Chapter", "Track", "Package"], trackingMode: .selectOne, target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let paneSizeLabel = NSTextField(labelWithString: "")

    private var chapterController: NSViewController?
    private var trackController: NSViewController?
    private var packageController: NSViewController?

    private var repoRootURL: URL!
    private var fixtureRootURL: URL!
    private var currentFixtureURL: URL?
    private var currentPackageContext: [String: Any]?
    private var currentMovieURL: URL?
    private var currentCanonicalValidationFindings: [[String: Any]] = []
    private var activeMode: HarnessMode = .package

    func applicationDidFinishLaunching(_ notification: Notification) {
        startIfNeeded()
    }

    func startIfNeeded() {
        guard !didStart else {
            return
        }
        didStart = true

        NSApp.setActivationPolicy(.regular)

        let adapterExecutable = siblingSlateAdapterExecutableURL()
        guard executableExists(adapterExecutable) else {
            presentStartupErrorAndTerminate(
                """
                Slate.app must be in the same directory as paneharness.app.

                Expected at:
                \(adapterExecutable.path)
                """
            )
            return
        }

        repoRootURL = resolveRepositoryRoot()
        fixtureRootURL = resolveFixtureRootURL(repoRootURL: repoRootURL)

        guard loadSlateAdapter(fromExecutableURL: adapterExecutable) else {
            presentStartupErrorAndTerminate(
                """
                Failed to load Slate adapter executable:
                \(adapterExecutable.path)
                """
            )
            return
        }

        buildWindow()
        loadControllers()
        registerAppleEvents()
        updateStatus("fixture not loaded")

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterAppleEvents()
    }

    func windowDidResize(_ notification: Notification) {
        layoutChrome()
        applyResponsiveLayout()
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minimumFrameSize = sender.frameRect(forContentRect: NSRect(x: 0,
                                                                       y: 0,
                                                                       width: HarnessConfig.minimumContentWidth,
                                                                       height: HarnessConfig.minimumContentHeight)).size
        return NSSize(width: max(frameSize.width, minimumFrameSize.width),
                      height: max(frameSize.height, minimumFrameSize.height))
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: HarnessConfig.defaultWindowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "paneharness"
        window.contentMinSize = NSSize(width: HarnessConfig.minimumContentWidth,
                                       height: HarnessConfig.minimumContentHeight)
        window.setContentSize(NSSize(width: HarnessConfig.defaultWindowRect.width,
                                     height: HarnessConfig.defaultContentHeight))
        window.delegate = self

        rootView.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
        rootView.autoresizingMask = [.width, .height]
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        controlsView.wantsLayer = true
        controlsView.layer?.backgroundColor = NSColor(calibratedWhite: 0.94, alpha: 1.0).cgColor
        controlsView.autoresizingMask = [.width, .minYMargin]
        rootView.addSubview(controlsView)

        paneHostView.wantsLayer = true
        paneHostView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        paneHostView.autoresizingMask = [.width, .height]
        rootView.addSubview(paneHostView)

        modeSegment.selectedSegment = 2
        modeSegment.target = self
        modeSegment.action = #selector(modeSegmentChanged(_:))
        controlsView.addSubview(modeSegment)

        let loadDailyButton = makeButton(title: "Load Daily", action: #selector(loadDailyFixture(_:)))
        controlsView.addSubview(loadDailyButton)

        let loadBigButton = makeButton(title: "Load Big", action: #selector(loadBigFixture(_:)))
        controlsView.addSubview(loadBigButton)

        let loadCustomButton = makeButton(title: "Load Package…", action: #selector(loadFixtureFromPanel(_:)))
        controlsView.addSubview(loadCustomButton)

        let openMovieButton = makeButton(title: "Open Movie…", action: #selector(openMovieFromPanel(_:)))
        controlsView.addSubview(openMovieButton)

        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 11.0, weight: .regular)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.autoresizingMask = [.width]
        controlsView.addSubview(statusLabel)

        paneSizeLabel.font = NSFont.monospacedSystemFont(ofSize: 11.0, weight: .regular)
        paneSizeLabel.textColor = NSColor.labelColor
        paneSizeLabel.alignment = .left
        paneSizeLabel.lineBreakMode = .byTruncatingTail
        controlsView.addSubview(paneSizeLabel)

        let contentController = NSViewController()
        contentController.view = rootView
        window.contentViewController = contentController
        layoutChrome()
        updatePaneSizeReadout()
    }

    private func loadControllers() {
        ensureAllControllersLoaded()
        setMode(.track)
        applyResponsiveLayout()
    }

    private func ensureApplicationDelegateSelectorSurface() {
        if NSApplication.shared.delegate !== self {
            NSApplication.shared.delegate = self
        }
    }

    private func controller(for mode: HarnessMode) -> NSViewController? {
        switch mode {
        case .chapter: return chapterController
        case .track: return trackController
        case .package: return packageController
        }
    }

    private func instantiatePaneController(for mode: HarnessMode) -> NSViewController? {
        switch mode {
        case .chapter:
            return instantiateController(className: "ChapterViewController")
        case .track:
            return instantiateController(className: "TrackViewController")
        case .package:
            return instantiateController(className: "PackageViewController")
        }
    }

    private func applyCurrentPackageContextToController(_ controller: NSViewController, mode: HarnessMode) {
        guard let packageContext = currentPackageContext else {
            return
        }

        switch mode {
        case .package:
            let packageSnapshot = packageContext["packageSnapshot"] as? NSDictionary
            _ = invokeObject(controller, selectorName: "presentPackageSnapshot:", object: packageSnapshot)
        case .track:
            _ = invokeObject(controller, selectorName: "assetTypeFromPackageContext:", object: packageContext as NSDictionary)
        case .chapter:
            if let chapterSnapshot = chapterSnapshotForCurrentFixture() {
                _ = invokeObject(controller, selectorName: "applyChapterSnapshot:", object: chapterSnapshot as NSDictionary)
            }
        }
    }

    private func ensureControllerLoaded(for mode: HarnessMode) -> NSViewController? {
        if let existing = controller(for: mode) {
            return existing
        }

        ensureApplicationDelegateSelectorSurface()
        guard let controller = instantiatePaneController(for: mode) else {
            let runtimePath = gHarnessRuntimeExecutablePath.isEmpty ? "<unresolved>" : gHarnessRuntimeExecutablePath
            let attemptedClasses = [
                "ChapterViewController",
                "TrackViewController",
                "PackageViewController",
                "Slate.ChapterViewController",
                "Slate.TrackViewController",
                "Slate.PackageViewController",
                "slate.ChapterViewController",
                "slate.TrackViewController",
                "slate.PackageViewController"
            ]
            presentStartupErrorAndTerminate(
                """
                Unable to resolve required controller class for mode \(mode.rawValue).

                Runtime executable:
                \(runtimePath)

                Tried class symbols:
                \(attemptedClasses.joined(separator: ", "))
                """
            )
            return nil
        }
        applyCurrentPackageContextToController(controller, mode: mode)

        switch mode {
        case .chapter:
            chapterController = controller
        case .track:
            trackController = controller
            primeTrackControllerWithCurrentMovie(controller)
        case .package:
            packageController = controller
        }
        applyCurrentValidationFindingsToController(controller, mode: mode)

        return controller
    }

    private func mountActiveControllerView(_ controller: NSViewController) {
        let activeView = controller.view
        activeView.isHidden = false
        if activeView.superview !== paneHostView {
            paneHostView.subviews.forEach { $0.removeFromSuperview() }
            activeView.frame = paneHostView.bounds
            activeView.autoresizingMask = [.width, .height]
            paneHostView.addSubview(activeView)
        }
        modeSegment.selectedSegment = segmentIndex(for: activeMode)
    }

    private func layoutChrome() {
        let bounds = rootView.bounds
        controlsView.frame = NSRect(x: 0, y: bounds.height - HarnessConfig.controlsHeight, width: bounds.width, height: HarnessConfig.controlsHeight)
        let paneHeight = max(0.0, bounds.height - HarnessConfig.controlsHeight)
        paneHostView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: paneHeight)
        controller(for: activeMode)?.view.frame = paneHostView.bounds

        paneSizeLabel.frame = NSRect(x: HarnessConfig.toolbarInsetX,
                                     y: 15,
                                     width: HarnessConfig.toolbarCurrentSizeWidth,
                                     height: 18)

        var x: CGFloat = HarnessConfig.toolbarInsetX
            + HarnessConfig.toolbarCurrentSizeWidth
            + HarnessConfig.toolbarCurrentSizeGapAfterReadout
        let y: CGFloat = 13.0
        layoutControl(modeSegment, x: &x, y: y, width: 220)
        if let button = controlsView.subviews.first(where: { $0 is NSButton && ($0 as? NSButton)?.title == "Load Daily" }) {
            layoutControl(button, x: &x, y: y, width: 88)
        }
        if let button = controlsView.subviews.first(where: { $0 is NSButton && ($0 as? NSButton)?.title == "Load Big" }) {
            layoutControl(button, x: &x, y: y, width: 74)
        }
        if let button = controlsView.subviews.first(where: { $0 is NSButton && ($0 as? NSButton)?.title == "Load Package…" }) {
            layoutControl(button, x: &x, y: y, width: 116)
        }
        if let button = controlsView.subviews.first(where: { $0 is NSButton && ($0 as? NSButton)?.title == "Open Movie…" }) {
            layoutControl(button, x: &x, y: y, width: 108)
        }

        let statusX = x
        let statusWidth = max(0, bounds.width - statusX - HarnessConfig.toolbarStatusRightInset)
        statusLabel.frame = NSRect(x: statusX,
                                   y: 15,
                                   width: statusWidth,
                                   height: 18)
        statusLabel.isHidden = (statusWidth < 80.0)
        updatePaneSizeReadout()
    }

    private func layoutControl(_ view: NSView, x: inout CGFloat, y: CGFloat, width: CGFloat) {
        view.frame = NSRect(x: x, y: y, width: width, height: 22)
        x += width + HarnessConfig.toolbarControlGap
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func modeSegmentChanged(_ sender: NSSegmentedControl) {
        let mode: HarnessMode
        switch sender.selectedSegment {
        case 0: mode = .chapter
        case 1: mode = .track
        default: mode = .package
        }
        setMode(mode)
    }

    @objc private func loadDailyFixture(_ sender: Any?) {
        let url = fixtureURL(for: HarnessConfig.smallFixtureRelativePathCandidates)
        _ = loadFixture(at: url)
    }

    @objc private func loadBigFixture(_ sender: Any?) {
        let url = fixtureURL(for: HarnessConfig.bigFixtureRelativePathCandidates)
        _ = loadFixture(at: url)
    }

    private func fixtureURL(for relativePathCandidates: [String]) -> URL {
        for relativePath in relativePathCandidates {
            let url = fixtureRootURL.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return fixtureRootURL.appendingPathComponent(relativePathCandidates[0])
    }

    private func runtimeJSONPayload(executableName: String, arguments: [String]) -> [String: Any]? {
        let executableURL = siblingRuntimeExecutableURL(named: executableName)
        guard executableExists(executableURL) else {
            updateStatus("runtime missing: \(executableName)")
            return nil
        }

        let task = Process()
        task.executableURL = executableURL
        task.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        do {
            try task.run()
        } catch {
            updateStatus("runtime launch failed: \(executableName)")
            return nil
        }

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let stderrText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            updateStatus(stderrText?.isEmpty == false ? stderrText! : "runtime failed: \(executableName)")
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: outputData, options: []),
              let payload = json as? [String: Any] else {
            updateStatus("runtime JSON failed: \(executableName)")
            return nil
        }

        return payload
    }

    private func validationReportPayload(packageURL: URL) -> [String: Any]? {
        let executableURL = siblingRuntimeExecutableURL(named: HarnessConfig.slateValidationRuntimeExecutableName)
        guard executableExists(executableURL) else {
            updateStatus("runtime missing: \(HarnessConfig.slateValidationRuntimeExecutableName)")
            return nil
        }

        let task = Process()
        task.executableURL = executableURL
        task.arguments = ["report", "--package", packageURL.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        do {
            try task.run()
        } catch {
            updateStatus("runtime launch failed: \(HarnessConfig.slateValidationRuntimeExecutableName)")
            return nil
        }

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let json = try? JSONSerialization.jsonObject(with: outputData, options: []),
              let payload = json as? [String: Any],
              payload[HarnessValidation.keySchemaVersion] as? String == HarnessValidation.reportSchemaVersion,
              payload[HarnessValidation.keyFindings] is [[String: Any]],
              payload[HarnessValidation.keyOperatorText] is String else {
            let stderrText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            updateStatus(stderrText?.isEmpty == false ? stderrText! : "validation report JSON failed")
            return nil
        }

        return payload
    }

    private func canonicalValidationFindings(from report: [String: Any]?) -> [[String: Any]] {
        guard let findings = report?[HarnessValidation.keyFindings] as? [[String: Any]] else {
            return []
        }

        return findings.filter { finding in
            finding[HarnessValidation.findingKeyCode] is String
                && finding[HarnessValidation.findingKeySeverity] is String
                && finding[HarnessValidation.findingKeyCategory] is String
                && finding[HarnessValidation.findingKeyScope] is String
                && finding[HarnessValidation.findingKeyTitle] is String
                && finding[HarnessValidation.findingKeyEvidence] is String
        }
    }

    private func canonicalValidationFindings(for categories: Set<String>) -> NSArray {
        let filtered = currentCanonicalValidationFindings.filter { finding in
            guard let category = finding[HarnessValidation.findingKeyCategory] as? String else {
                return false
            }
            return categories.contains(category)
        }
        return filtered as NSArray
    }

    private func applyCurrentValidationFindingsToController(_ controller: NSViewController, mode: HarnessMode) {
        let findings: NSArray
        switch mode {
        case .package:
            findings = canonicalValidationFindings(for: [
                HarnessValidation.categoryPackage,
                HarnessValidation.categoryMetadata
            ])
        case .track:
            findings = canonicalValidationFindings(for: [
                HarnessValidation.categoryTracks,
                HarnessValidation.categoryRoles
            ])
        case .chapter:
            findings = canonicalValidationFindings(for: [
                HarnessValidation.categoryChapters
            ])
        }
        _ = invokeObject(controller,
                         selectorName: "applyCanonicalValidationFindings:",
                         object: findings)
    }

    private func applyCurrentValidationFindingsToLoadedControllers() {
        if let controller = packageController {
            applyCurrentValidationFindingsToController(controller, mode: .package)
        }
        if let controller = trackController {
            applyCurrentValidationFindingsToController(controller, mode: .track)
        }
        if let controller = chapterController {
            applyCurrentValidationFindingsToController(controller, mode: .chapter)
        }
    }

    private func refreshCanonicalValidationFindings() {
        guard let fixtureURL = currentFixtureURL else {
            currentCanonicalValidationFindings = []
            applyCurrentValidationFindingsToLoadedControllers()
            return
        }

        currentCanonicalValidationFindings = canonicalValidationFindings(from: validationReportPayload(packageURL: fixtureURL))
        applyCurrentValidationFindingsToLoadedControllers()
    }

    private func packageContext(from fixtureURL: URL) -> [String: Any]? {
        let context = runtimeJSONPayload(executableName: HarnessConfig.slatePackageRuntimeExecutableName,
                                         arguments: ["context", "--package", fixtureURL.path])
        guard let context, context["schemaVersion"] as? String == "packageContext.v1" else {
            return nil
        }
        return context
    }

    private func chapterSnapshotForCurrentFixture() -> [String: Any]? {
        guard let fixtureURL = currentFixtureURL else {
            return [
                "schemaVersion": "chapterSnapshot.v1",
                "hasPackage": false,
                "rows": [],
                "chapterCount": 0
            ]
        }

        var arguments = ["snapshot", "--package", fixtureURL.path]
        if let currentMovieURL {
            arguments.append("--movie")
            arguments.append(currentMovieURL.path)
        }

        let snapshot = runtimeJSONPayload(executableName: HarnessConfig.slateChapterRuntimeExecutableName,
                                          arguments: arguments)
        guard let snapshot, snapshot["schemaVersion"] as? String == "chapterSnapshot.v1" else {
            return nil
        }
        return snapshot
    }

    @objc private func loadFixtureFromPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.xml, .json]
        panel.directoryURL = fixtureRootURL

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        _ = loadFixture(at: url)
    }

    @objc private func openMovieFromPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.quickTimeMovie, .mpeg4Movie]
        panel.directoryURL = fixtureRootURL.appendingPathComponent(HarnessConfig.movieFixtureRelativeDirectory,
                                                                    isDirectory: true)

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        _ = loadMovie(at: url)
    }

    private func applyResponsiveLayout() {
        let width = max(0, paneHostView.bounds.width)
        if let controller = chapterController {
            invokeCGFloat(controller, selectorName: "applyWorkspaceLayoutForWidth:", value: width)
        }
        if let controller = trackController {
            invokeCGFloat(controller, selectorName: "applyWorkspaceLayoutForWidth:", value: width)
        }
        if let controller = packageController {
            invokeCGFloat(controller, selectorName: "applyWorkspaceLayoutForWidth:", value: width)
        }
        updatePaneSizeReadout()
    }

    private func updatePaneSizeReadout() {
        let activePaneSize: NSSize
        if let activeView = controller(for: activeMode)?.view {
            activePaneSize = activeView.bounds.size
        } else {
            activePaneSize = paneHostView.bounds.size
        }

        let width = Int(activePaneSize.width.rounded())
        let height = Int(activePaneSize.height.rounded())
        paneSizeLabel.stringValue = "Current Size: \(width) x \(height)"
    }

    @discardableResult
    private func loadFixture(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            updateStatus("fixture missing: \(url.path)")
            return false
        }

        guard let packageContext = packageContext(from: url),
              (packageContext["hasPackage"] as? Bool) == true else {
            updateStatus("package runtime failed: \(url.lastPathComponent)")
            return false
        }

        currentPackageContext = packageContext
        currentFixtureURL = url
        if let controller = packageController {
            let packageSnapshot = packageContext["packageSnapshot"] as? NSDictionary
            _ = invokeObject(controller, selectorName: "presentPackageSnapshot:", object: packageSnapshot)
        }
        if let controller = trackController {
            _ = invokeObject(controller, selectorName: "assetTypeFromPackageContext:", object: packageContext as NSDictionary)
        }
        if let controller = chapterController {
            if let chapterSnapshot = chapterSnapshotForCurrentFixture() {
                _ = invokeObject(controller, selectorName: "applyChapterSnapshot:", object: chapterSnapshot as NSDictionary)
            }
        }
        refreshCanonicalValidationFindings()
        applyResponsiveLayout()
        updateStatus("fixture=\(url.lastPathComponent)")
        return true
    }

    private func updateStatus(_ message: String) {
        statusLabel.stringValue = message
        print("Harness: \(message)")
    }

    private func trimmedStatusPart(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func currentModeName() -> String {
        activeMode.rawValue
    }

    private func segmentIndex(for mode: HarnessMode) -> Int {
        switch mode {
        case .chapter: return 0
        case .track: return 1
        case .package: return 2
        }
    }

    private func setMode(_ mode: HarnessMode) {
        guard let controller = ensureControllerLoaded(for: mode) else {
            return
        }
        activeMode = mode
        if mode == .track {
            primeTrackControllerWithCurrentMovie(controller)
        }
        mountActiveControllerView(controller)
        applyResponsiveLayout()
    }

    @discardableResult
    private func loadMovie(at movieURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: movieURL.path) else {
            updateStatus("movie missing: \(movieURL.path)")
            movie = nil
            currentMovieURL = nil
            return false
        }
        guard let movieClass = NSClassFromString("SMMovie") as? NSObject.Type else {
            updateStatus("track movie class missing: SMMovie")
            movie = nil
            currentMovieURL = nil
            return false
        }

        let selector = NSSelectorFromString("movieWithFile:")
        guard movieClass.responds(to: selector),
              let result = movieClass.perform(selector, with: movieURL.path as NSString) else {
            updateStatus("track movie open failed: \(movieURL.lastPathComponent)")
            movie = nil
            currentMovieURL = nil
            return false
        }

        movie = result.takeUnretainedValue()
        currentMovieURL = movieURL
        if let controller = trackController {
            primeTrackControllerWithCurrentMovie(controller)
        }
        if let controller = chapterController,
           let chapterSnapshot = chapterSnapshotForCurrentFixture() {
            _ = invokeObject(controller, selectorName: "applyChapterSnapshot:", object: chapterSnapshot as NSDictionary)
        }
        refreshCanonicalValidationFindings()
        applyResponsiveLayout()
        updateStatus("movie=\(movieURL.lastPathComponent)")
        return true
    }

    private func primeTrackControllerWithCurrentMovie(_ controller: NSViewController) {
        let controllerObject = controller as AnyObject
        _ = invokeNoArgs(controllerObject, selectorName: "removeMovieReference")
        _ = invokeNoArgs(controllerObject, selectorName: "refreshTrackData")
        _ = invokeNoArgs(controllerObject, selectorName: "refreshValidationAdaptersAfterMutation")
        invokeCGFloat(controllerObject,
                      selectorName: "applyWorkspaceLayoutForWidth:",
                      value: max(0.0, paneHostView.bounds.width))
    }

    private func setMode(_ mode: String) -> Bool {
        let normalized = mode.lowercased()
        if normalized == "chapter" || normalized == "c" || normalized == "0" {
            setMode(.chapter)
            return true
        }
        if normalized == "track" || normalized == "t" || normalized == "1" {
            setMode(.track)
            return true
        }
        if normalized == "package" || normalized == "p" || normalized == "2" {
            setMode(.package)
            return true
        }
        return false
    }

    private func workspaceWidthClassCode(for width: CGFloat) -> String {
        if width >= 1280.0 { return "2" }
        if width >= 1100.0 { return "1" }
        return "0"
    }

    private func ensureAllControllersLoaded() {
        _ = ensureControllerLoaded(for: .chapter)
        _ = ensureControllerLoaded(for: .track)
        _ = ensureControllerLoaded(for: .package)
    }

    private func jsonString(for payload: Any, fallback: String) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return fallback
        }
        return json
    }

    private func operatorResultPayload(eventID: OSType, result: Any) -> [String: Any] {
        return [
            "result": result,
            "ok": true,
            "schemaVersion": "operatorResult.v1",
            "eventClass": fourCharString(HarnessAppleEvent.eventClass),
            "eventID": fourCharString(eventID)
        ]
    }

    private func runtimeCommandResult(command: String,
                                      payload: [String: Any],
                                      result: Any) -> [String: Any] {
        return [
            "schemaVersion": "runtimeCommandResult.v1",
            "command": command,
            "payload": payload,
            "accepted": true,
            "result": result
        ]
    }

    private func operatorErrorPayload(eventID: OSType,
                                      errorNo: Int16,
                                      code: String,
                                      message: String) -> [String: Any] {
        return [
            "result": NSNull(),
            "ok": false,
            "schemaVersion": "operatorResult.v1",
            "eventClass": fourCharString(HarnessAppleEvent.eventClass),
            "eventID": fourCharString(eventID),
            "error": [
                "code": code,
                "message": message,
                "appleEventError": Int(errorNo)
            ]
        ]
    }

    private func paneharnessStatusPayload() -> [String: Any] {
        let requiredAdapterClasses = [
            "SMMovie",
            "ChapterViewController",
            "TrackViewController",
            "PackageViewController"
        ]
        let missingAdapterClasses = requiredAdapterClasses.filter { !runtimeClassExists($0) }
        let adapterLoaded = !gHarnessRuntimeExecutablePath.isEmpty
        let adapterExecutableOK = adapterLoaded && executableExists(URL(fileURLWithPath: gHarnessRuntimeExecutablePath))
        let runtimeExecutableNames = [
            HarnessConfig.slatePackageRuntimeExecutableName,
            HarnessConfig.slateChapterRuntimeExecutableName,
            HarnessConfig.slateTrackRuntimeExecutableName,
            HarnessConfig.slateValidationRuntimeExecutableName,
            HarnessConfig.slateReviewRuntimeExecutableName,
            HarnessConfig.slateTimelineRuntimeExecutableName
        ]
        let runtimeExecutables = runtimeExecutableNames.map { name -> [String: Any] in
            let url = siblingRuntimeExecutableURL(named: name)
            let available = executableExists(url)
            return [
                "name": name,
                "path": url.path,
                "available": available
            ]
        }
        let runtimeExecutablesOK = runtimeExecutables.allSatisfy { ($0["available"] as? Bool) == true }
        let contentSize = window.contentLayoutRect.size
        let paneSize = paneHostView.bounds.size

        let checks: [[String: Any]] = [
            [
                "name": "siblingAdapterExecutable",
                "ok": adapterExecutableOK,
                "message": adapterExecutableOK ? "Slate adapter executable is loaded." : "Slate adapter executable is not loaded."
            ],
            [
                "name": "requiredAdapterClasses",
                "ok": missingAdapterClasses.isEmpty,
                "message": missingAdapterClasses.isEmpty ? "Required adapter classes are available." : "Required adapter classes are missing."
            ],
            [
                "name": "siblingRuntimeExecutables",
                "ok": runtimeExecutablesOK,
                "message": runtimeExecutablesOK ? "Sibling runtime executables are available." : "One or more sibling runtime executables are missing."
            ],
            [
                "name": "repositoryRoot",
                "ok": repoRootURL != nil,
                "message": repoRootURL == nil ? "Repository root is not resolved." : "Repository root is resolved."
            ],
            [
                "name": "window",
                "ok": window.isVisible,
                "message": window.isVisible ? "Harness window is visible." : "Harness window is not visible."
            ]
        ]
        let healthy = checks.allSatisfy { ($0["ok"] as? Bool) == true }

        return [
            "schemaVersion": "paneharnessStatus.v1",
            "ok": healthy,
            "status": healthy ? "ready" : "degraded",
            "application": [
                "name": "paneharness",
                "bundleIdentifier": Bundle.main.bundleIdentifier ?? ""
            ],
            "adapter": [
                "strategy": "siblingApplication",
                "application": "Slate.app",
                "executable": HarnessConfig.slateAdapterExecutableName,
                "loaded": adapterLoaded,
                "executableAvailable": adapterExecutableOK,
                "requiredClasses": requiredAdapterClasses,
                "missingClasses": missingAdapterClasses,
                "installLocations": [
                    "Place Slate.app in the same directory as paneharness.app"
                ],
                "message": adapterExecutableOK
                    ? "Sibling Slate.app adapter is available."
                    : "Missing sibling Slate.app adapter. Copy Slate.app next to paneharness.app and relaunch."
            ],
            "runtime": [
                "strategy": "siblingExecutables",
                "executables": runtimeExecutables,
                "ok": runtimeExecutablesOK,
                "installLocations": [
                    "Place Slate runtime executables in the same directory as paneharness.app"
                ],
                "message": runtimeExecutablesOK
                    ? "Sibling Slate runtime executables are available."
                    : "Missing one or more sibling Slate runtime executables."
            ],
            "state": [
                "activeMode": currentModeName(),
                "packageFixtureLoaded": currentPackageContext != nil,
                "packageFixtureName": currentFixtureURL?.lastPathComponent ?? "",
                "movieLoaded": movie != nil,
                "controllersLoaded": [
                    "chapter": chapterController != nil,
                    "track": trackController != nil,
                    "package": packageController != nil
                ]
            ],
            "window": [
                "visible": window.isVisible,
                "key": window.isKeyWindow,
                "contentWidth": contentSize.width,
                "contentHeight": contentSize.height,
                "paneWidth": paneSize.width,
                "paneHeight": paneSize.height,
                "workspaceWidthClass": workspaceWidthClassCode(for: paneSize.width)
            ],
            "appleEvents": [
                "eventClass": fourCharString(HarnessAppleEvent.eventClass),
                "events": HarnessAppleEvent.handledEventIDs.map { fourCharString($0) }
            ],
            "checks": checks
        ]
    }

    private func trackMovieDetailsPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "schemaVersion": "trackMovieDetails.v1",
            "hasMovie": movie != nil,
            "mode": currentModeName()
        ]

        guard movie != nil else {
            payload["error"] = "noMovie"
            payload["message"] = "No movie is currently loaded."
            payload["trackCount"] = 0
            payload["tracks"] = []
            return payload
        }

        guard let controller = ensureControllerLoaded(for: .track) else {
            payload["error"] = "trackInspectorUnavailable"
            payload["message"] = "Track + Movie inspector data is unavailable."
            payload["trackCount"] = 0
            payload["tracks"] = []
            return payload
        }

        let tracks = (invokeNoArgs(controller as AnyObject,
                                   selectorName: "trackMovieInspectorDetailRows")?.takeUnretainedValue() as? [[String: Any]]) ?? []
        payload["trackCount"] = tracks.count
        payload["tracks"] = tracks
        return payload
    }

    private func trackMovieDetailsJSONString() -> String {
        let payload = trackMovieDetailsPayload()
        if let errorCode = payload["error"] as? String {
            let message = (payload["message"] as? String) ?? "Track + Movie inspector data is unavailable."
            return jsonString(for: operatorErrorPayload(eventID: HarnessAppleEvent.trackMovieDetails,
                                                        errorNo: Int16(errAENoSuchObject),
                                                        code: errorCode,
                                                        message: message),
                              fallback: "{\"error\":\"track-movie-details-json-failed\",\"ok\":false}")
        }
        return jsonString(for: operatorResultPayload(eventID: HarnessAppleEvent.trackMovieDetails, result: payload),
                          fallback: "{\"error\":\"track-movie-details-json-failed\",\"ok\":false}")
    }

    private func chapterDetailsPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "schemaVersion": "chapterDetails.v1",
            "hasPackage": currentPackageContext != nil,
            "mode": currentModeName()
        ]

        guard currentPackageContext != nil else {
            payload["error"] = "noPackage"
            payload["message"] = "No package is currently loaded."
            payload["chapterCount"] = 0
            payload["chapters"] = []
            return payload
        }

        guard let controller = ensureControllerLoaded(for: .chapter) else {
            payload["error"] = "chapterInspectorUnavailable"
            payload["message"] = "Chapter inspector data is unavailable."
            payload["chapterCount"] = 0
            payload["chapters"] = []
            return payload
        }

        let chapters = (invokeNoArgs(controller as AnyObject,
                                     selectorName: "chapterInspectorDetailRows")?.takeUnretainedValue() as? [[String: Any]]) ?? []
        payload["chapterCount"] = chapters.count
        payload["chapters"] = chapters
        return payload
    }

    private func chapterDetailsJSONString() -> String {
        let payload = chapterDetailsPayload()
        if let errorCode = payload["error"] as? String {
            let message = (payload["message"] as? String) ?? "Chapter inspector data is unavailable."
            return jsonString(for: operatorErrorPayload(eventID: HarnessAppleEvent.chapterDetails,
                                                        errorNo: Int16(errAENoSuchObject),
                                                        code: errorCode,
                                                        message: message),
                              fallback: "{\"error\":\"chapter-details-json-failed\",\"ok\":false}")
        }
        return jsonString(for: operatorResultPayload(eventID: HarnessAppleEvent.chapterDetails, result: payload),
                          fallback: "{\"error\":\"chapter-details-json-failed\",\"ok\":false}")
    }

    private func loadSlateAdapter(fromExecutableURL executableURL: URL) -> Bool {
        let executablePath = canonicalExecutablePath(executableURL.path)
        gHarnessRuntimeExecutablePath = executablePath

        guard dlopen(executablePath, RTLD_NOW | RTLD_GLOBAL) != nil else {
            if let raw = dlerror() {
                updateStatus("adapter load failed (\(executablePath)): \(String(cString: raw))")
            } else {
                updateStatus("adapter load failed (\(executablePath)): unknown")
            }
            return false
        }

        let requiredClasses = [
            "SMMovie",
            "ChapterViewController",
            "TrackViewController",
            "PackageViewController"
        ]
        let missingClasses = requiredClasses.filter { !runtimeClassExists($0) }
        if !missingClasses.isEmpty {
            updateStatus("adapter missing classes: \(missingClasses.joined(separator: ", "))")
            return false
        }

        return true
    }

    private func presentStartupErrorAndTerminate(_ message: String) {
        fputs("Harness startup error: \(message)\n", stderr)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "paneharness"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func registerAppleEvents() {
        let manager = NSAppleEventManager.shared()
        let selector = #selector(handleHarnessAppleEvent(_:withReplyEvent:))
        for eventID in HarnessAppleEvent.handledEventIDs {
            manager.setEventHandler(self,
                                    andSelector: selector,
                                    forEventClass: HarnessAppleEvent.eventClass,
                                    andEventID: eventID)
        }
    }

    private func unregisterAppleEvents() {
        let manager = NSAppleEventManager.shared()
        for eventID in HarnessAppleEvent.handledEventIDs {
            manager.removeEventHandler(forEventClass: HarnessAppleEvent.eventClass,
                                       andEventID: eventID)
        }
    }

    @objc(handleHarnessAppleEvent:withReplyEvent:)
    func handleHarnessAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        let eventID = event.eventID
        let direct = event.paramDescriptor(forKeyword: keyDirectObject)

        switch eventID {
        case HarnessAppleEvent.ping:
            setOperatorReply(replyEvent, eventID: eventID, result: "pong")

        case HarnessAppleEvent.setMode:
            guard let mode = descriptorString(direct), setMode(mode) else {
                setOperatorErrorReply(replyEvent,
                                      eventID: eventID,
                                      errorNo: Int16(paramErr),
                                      code: "expectedMode",
                                      message: "Mode must be chapter/track/package (or c/t/p or 0/1/2).")
                return
            }
            setOperatorReply(replyEvent,
                             eventID: eventID,
                             result: runtimeCommandResult(command: "setMode",
                                                          payload: ["mode": descriptorString(direct) ?? ""],
                                                          result: ["mode": currentModeName()]))

        case HarnessAppleEvent.setWindow:
            guard let bounds = parseBoundsList(direct) else {
                setOperatorErrorReply(replyEvent,
                                      eventID: eventID,
                                      errorNo: Int16(paramErr),
                                      code: "expectedBounds",
                                      message: "Expected bounds list {x, y, width, height}.")
                return
            }
            window.setFrame(bounds, display: true)
            applyResponsiveLayout()
            setOperatorReply(replyEvent,
                             eventID: eventID,
                             result: [window.frame.origin.x,
                                      window.frame.origin.y,
                                      window.frame.size.width,
                                      window.frame.size.height])

        case HarnessAppleEvent.loadFixture:
            guard let path = descriptorPath(direct), !path.isEmpty else {
                setOperatorErrorReply(replyEvent,
                                      eventID: eventID,
                                      errorNo: Int16(paramErr),
                                      code: "expectedPath",
                                      message: "Expected fixture path string.")
                return
            }

            let ok = loadFixture(at: URL(fileURLWithPath: path))
            if !ok {
                setOperatorErrorReply(replyEvent,
                                      eventID: eventID,
                                      errorNo: Int16(fnfErr),
                                      code: "fixtureLoadFailed",
                                      message: "Fixture load failed: \(path)")
                return
            }
            setOperatorReply(replyEvent,
                             eventID: eventID,
                             result: runtimeCommandResult(command: "openPath",
                                                          payload: ["path": path],
                                                          result: ["path": path]))

        case HarnessAppleEvent.trackMovieDetails:
            setReply(replyEvent, result: NSAppleEventDescriptor(string: trackMovieDetailsJSONString()))

        case HarnessAppleEvent.chapterDetails:
            setReply(replyEvent, result: NSAppleEventDescriptor(string: chapterDetailsJSONString()))

        case HarnessAppleEvent.snapshot:
            setOperatorReply(replyEvent, eventID: eventID, result: paneharnessStatusPayload())

        default:
            setOperatorErrorReply(replyEvent,
                                  eventID: eventID,
                                  errorNo: Int16(errAEEventNotHandled),
                                  code: "unknownEvent",
                                  message: "Unknown harness Apple Event.")
        }
    }

    private func descriptorString(_ descriptor: NSAppleEventDescriptor?) -> String? {
        guard let descriptor else { return nil }
        if let raw = descriptor.stringValue, !raw.isEmpty {
            return raw
        }
        if let coerced = descriptor.coerce(toDescriptorType: typeUnicodeText),
           let raw = coerced.stringValue,
           !raw.isEmpty {
            return raw
        }
        return nil
    }

    private func normalizedPathString(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""
        }
        if trimmed.hasPrefix("file://"), let url = URL(string: trimmed) {
            return url.standardizedFileURL.path
        }
        return (trimmed as NSString).expandingTildeInPath
    }

    private func descriptorPath(_ descriptor: NSAppleEventDescriptor?) -> String? {
        guard let descriptor else { return nil }

        if let raw = descriptor.stringValue, !raw.isEmpty {
            return normalizedPathString(raw)
        }

        if descriptor.descriptorType == typeFileURL,
           let raw = descriptor.stringValue,
           let url = URL(string: raw) {
            return url.standardizedFileURL.path
        }

        if let coerced = descriptor.coerce(toDescriptorType: typeFileURL),
           let raw = coerced.stringValue,
           let url = URL(string: raw) {
            return url.standardizedFileURL.path
        }

        if let coerced = descriptor.coerce(toDescriptorType: typeUnicodeText),
           let raw = coerced.stringValue,
           !raw.isEmpty {
            return normalizedPathString(raw)
        }

        return nil
    }

    private func parseBoundsList(_ descriptor: NSAppleEventDescriptor?) -> NSRect? {
        guard let descriptor, descriptor.numberOfItems == 4 else {
            return nil
        }

        guard let x = descriptor.atIndex(1)?.doubleValue,
              let y = descriptor.atIndex(2)?.doubleValue,
              let w = descriptor.atIndex(3)?.doubleValue,
              let h = descriptor.atIndex(4)?.doubleValue,
              w >= 320,
              h >= 300 else {
            return nil
        }

        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func setReply(_ replyEvent: NSAppleEventDescriptor,
                          result: NSAppleEventDescriptor? = nil,
                          errorNo: Int16 = 0,
                          message: String? = nil) {
        replyEvent.setParam(NSAppleEventDescriptor(int32: Int32(errorNo)), forKeyword: keyErrorNumber)
        if let message {
            replyEvent.setParam(NSAppleEventDescriptor(string: message), forKeyword: keyErrorString)
        }
        if let result {
            replyEvent.setParam(result, forKeyword: keyDirectObject)
        }
    }

    private func setOperatorReply(_ replyEvent: NSAppleEventDescriptor,
                                  eventID: OSType,
                                  result: Any) {
        let payload = operatorResultPayload(eventID: eventID, result: result)
        let json = jsonString(for: payload, fallback: "{\"result\":null,\"ok\":false}")
        replyEvent.setParam(NSAppleEventDescriptor(string: json), forKeyword: keyDirectObject)
    }

    private func setOperatorErrorReply(_ replyEvent: NSAppleEventDescriptor,
                                       eventID: OSType,
                                       errorNo: Int16,
                                       code: String,
                                       message: String) {
        let payload = operatorErrorPayload(eventID: eventID,
                                           errorNo: errorNo,
                                           code: code,
                                           message: message)
        let json = jsonString(for: payload, fallback: "{\"result\":null,\"ok\":false}")
        replyEvent.setParam(NSAppleEventDescriptor(string: json), forKeyword: keyDirectObject)
    }
}

private var harnessDelegate: PaneHarnessApp?

private func hasWindowServerSession() -> Bool {
    CGSessionCopyCurrentDictionary() != nil
}

@main
struct HarnessMain {
    static func main() {
        guard hasWindowServerSession() else {
            fputs("paneharness requires an active macOS WindowServer session.\n", stderr)
            exit(1)
        }

        let app = NSApplication.shared
        let delegate = PaneHarnessApp()
        harnessDelegate = delegate
        app.delegate = delegate
        delegate.startIfNeeded()
        app.run()
    }
}
