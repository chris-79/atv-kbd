import AppKit
import ObjectiveC
import SwiftUI
import ItsytvCore

/// The ATV KBD window: which Apple TV is connected, what it's doing, and the keys that control it.
struct KeyboardWindowView: View {
    @Environment(AppleTVManager.self) private var manager
    @State private var input = KeyboardInput()
    @State private var pin = ""
    @State private var didAutoConnect = false
    @State private var shortcutsExpanded = false

    private let background = Color.black

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                if input.textMode {
                    typedLine
                        .padding(.top, 8)
                }
                VStack(spacing: 0) {
                    if showsConnectionDetail {
                        connectionBody
                            .padding(.top, 12)
                    }
                    Spacer(minLength: 0)
                    AppleTVMark()
                        .padding(.horizontal, 36)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.32), value: showsDevicePicker)
                if !isPairing {
                    shortcutButton
                        .padding(.bottom, 18)
                }
            }
            .frame(height: WindowChrome.collapsedHeight)

            if shortcutsExpanded && !isPairing {
                shortcutList
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .background(background.ignoresSafeArea())
        .overlay(alignment: .topLeading) { windowControls }
        .preferredColorScheme(.dark)
        .coordinateSpace(name: "kbd")
        .onPreferenceChange(ControlHitAreaKey.self) { HitStore.shared.controls = $0 }
        .background(KeyCapture(input: $input, isPairing: isPairing, onPIN: handlePIN, onCommand: perform))
        .background(WindowChrome())
        .background(HitBridge(onActivate: activateControl))
        .onAppear {
            guard !didAutoConnect else { return }
            didAutoConnect = true
            if manager.connectionStatus == .disconnected {
                manager.connectToLastConnectedDevice()
            }
        }
        .onChange(of: manager.discoveredDevices.map(\.id)) { _, _ in
            AppDelegate.shared?.connectRequestedDeviceIfAvailable()
        }
        .onChange(of: manager.connectionStatus.isPairing) { _, pairing in
            if !pairing { pin = "" }
        }
        .onChange(of: shortcutsExpanded) { _, _ in
            WindowChrome.applyHeight(extra: shortcutExtra)
        }
        .onChange(of: input.textMode) { _, _ in
            guard shortcutsExpanded else { return }
            WindowChrome.applyHeight(extra: shortcutExtra)
        }
    }

    /// Height added below the shortcuts label. The window grows by this amount so the list can use a readable size.
    private var shortcutExtra: CGFloat {
        guard shortcutsExpanded else { return 0 }
        let rows = CGFloat(KeyboardInput.hints(textMode: input.textMode).count)
        return rows * 18 + max(0, rows - 1) * 3 + 20
    }

    /// Red quits. Yellow hides. Drawn here so the black window cannot cover them.
    private var windowControls: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 1, green: 0.373, blue: 0.341))
                .frame(width: 12, height: 12)
                .accessibilityLabel("Quit")
            Circle()
                .fill(Color(red: 0.996, green: 0.741, blue: 0.180))
                .frame(width: 12, height: 12)
                .accessibilityLabel("Hide")
        }
        .padding(.top, 16)
        .padding(.leading, 10)
        .allowsHitTesting(false)
    }

    private var header: some View {
        VStack(spacing: 4) {
            ZStack {
                Text(titleText)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .overlay(alignment: .leading) {
                        if !showsDevicePicker {
                            Circle()
                                .fill(connectionColor)
                                .frame(width: 6, height: 6)
                                .offset(x: -11)
                        }
                    }
                    .padding(.horizontal, 52)

                HStack {
                    if showsSwitch {
                        Spacer()
                        Button(action: { manager.disconnect() }) {
                            Text("SWITCH")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .controlHitArea("switch")
                    }
                }
            }
            if showsStatusLine {
                Text(statusLine)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var connectionBody: some View {
        switch manager.connectionStatus {
        case .pairing:
            pinEntry
        case .disconnected:
            deviceList
        case .localNetworkDenied:
            VStack(alignment: .leading, spacing: 10) {
                Text("Turn on ATV KBD in System Settings → Privacy & Security → Local Network.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Privacy & Security") {
                    SystemSettingsPane.privacySecurity.open()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .controlHitArea("privacy")
            }
        case .error:
            Button("Dismiss") { manager.disconnect() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .controlHitArea("dismiss")
        case .connecting, .connected:
            EmptyView()
        }
    }

    private var typedLine: some View {
        Text(input.text.isEmpty ? "Type to search" : input.text)
            .font(.system(size: 15, weight: .regular, design: .monospaced))
            .foregroundStyle(input.text.isEmpty ? .white.opacity(0.28) : .white.opacity(0.92))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deviceList: some View {
        Group {
            if manager.discoveredDevices.isEmpty {
                Text("Looking for Apple TVs on your network")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(sortedDevices, id: \.id) { device in
                                Button {
                                    manager.connect(to: device)
                                } label: {
                                    Text(device.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .lineLimit(1)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .controlHitArea(device.id, EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxHeight: 96)
            }
        }
    }

    private var pinEntry: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                let filled = index < pin.count
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(index == pin.count ? 0.7 : 0.16), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .frame(width: 36, height: 44)
                    .overlay {
                        if filled {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 7, height: 7)
                        }
                    }
            }
        }
    }

    private var shortcutButton: some View {
        Button {
            shortcutsExpanded.toggle()
        } label: {
            Text("CONTROLS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .overlay(alignment: .leading) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(shortcutsExpanded ? 90 : 0))
                        .offset(x: -14)
                }
                .foregroundStyle(.white.opacity(0.42))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .controlHitArea("controls", EdgeInsets(top: 8, leading: 22, bottom: 8, trailing: 10))
    }

    private var shortcutList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(KeyboardInput.hints(textMode: input.textMode)) { hint in
                HStack(spacing: 8) {
                    Text(hint.keys)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 84, alignment: .leading)
                    Text(hint.action)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .frame(height: 18)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sortedDevices: [AppleTVDevice] {
        manager.discoveredDevices.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var deviceName: String {
        if let name = manager.connectedDeviceName, !name.isEmpty { return name }
        return "Apple TV"
    }

    /// The switch menu replaces the device name with this title. No second "Apple TV" line under it.
    private var showsDevicePicker: Bool {
        if case .disconnected = manager.connectionStatus { return true }
        return false
    }

    private var titleText: String {
        showsDevicePicker ? "Choose an Apple TV" : deviceName
    }

    private var showsStatusLine: Bool {
        if showsDevicePicker { return false }
        return manager.connectionStatus != .connected || input.textMode
    }

    private var isPairing: Bool { manager.connectionStatus.isPairing }

    /// Device list, PIN, and errors sit above the mark. A live connection leaves that space to the graphic.
    private var showsConnectionDetail: Bool {
        switch manager.connectionStatus {
        case .connecting, .connected: false
        case .disconnected, .pairing, .error, .localNetworkDenied: true
        }
    }

    private var connectionColor: Color {
        switch manager.connectionStatus {
        case .connected: Color(red: 0.30, green: 0.86, blue: 0.46)
        case .connecting, .pairing: Color(red: 0.95, green: 0.72, blue: 0.22)
        case .error, .localNetworkDenied: Color(red: 0.95, green: 0.38, blue: 0.32)
        case .disconnected: Color.white.opacity(0.28)
        }
    }

    private var showsSwitch: Bool {
        switch manager.connectionStatus {
        case .connected, .connecting: true
        case .disconnected, .pairing, .error, .localNetworkDenied: false
        }
    }

    private var statusLine: String {
        if input.textMode, manager.connectionStatus == .connected { return "Text input" }
        switch manager.connectionStatus {
        case .disconnected:
            return manager.discoveredDevices.isEmpty ? "Looking for Apple TVs" : "Choose an Apple TV"
        case .connecting:
            return "Connecting"
        case .pairing:
            return "Enter the PIN on your Apple TV"
        case .connected:
            return "Connected"
        case .localNetworkDenied:
            return "Local network access is off"
        case .error(let message):
            return message
        }
    }

    private func handlePIN(_ kind: PINKey) {
        switch kind {
        case .backspace:
            if !pin.isEmpty { pin.removeLast() }
        case .digit(let value):
            guard pin.count < 4 else { return }
            pin.append(String(value))
            if pin.count == 4 {
                manager.submitPIN(pin)
            }
        }
    }

    private func activateControl(_ id: String) {
        switch id {
        case "switch", "dismiss":
            manager.disconnect()
        case "controls":
            shortcutsExpanded.toggle()
        case "privacy":
            SystemSettingsPane.privacySecurity.open()
        default:
            if let device = manager.discoveredDevices.first(where: { $0.id == id }) {
                manager.connect(to: device)
            }
        }
    }

    private func perform(_ command: KeyboardInput.Command) {
        switch command {
        case .toggleText:
            manager.resetTextInputState()
        case .replaceText(let text):
            guard manager.connectionStatus == .connected else { return }
            manager.updateRemoteText(text)
        case .moveUp: send(.up)
        case .moveDown: send(.down)
        case .moveLeft: send(.left)
        case .moveRight: send(.right)
        case .select: send(.select)
        case .playPause: send(.playPause)
        case .menu: send(.menu)
        case .home: send(.home)
        case .homeDouble: send(.home, .doubleClick)
        }
    }

    private func send(_ button: CompanionButton, _ action: InputAction = .click) {
        guard manager.connectionStatus == .connected else { return }
        manager.pressButton(button, action: action)
    }
}

private extension ConnectionStatus {
    var isPairing: Bool {
        if case .pairing = self { return true }
        return false
    }
}

enum PINKey {
    case digit(Int)
    case backspace
}

/// Installs a local key monitor while this window is key, so arrows and Escape
/// reach the Apple TV instead of the window's buttons.
private struct KeyCapture: NSViewRepresentable {
    @Binding var input: KeyboardInput
    var isPairing: Bool
    var onPIN: (PINKey) -> Void
    var onCommand: (KeyboardInput.Command) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = { event in context.coordinator.handle(event) }
        view.onResign = { context.coordinator.resign() }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        context.coordinator.input = $input
        context.coordinator.isPairing = isPairing
        context.coordinator.onPIN = onPIN
        context.coordinator.onCommand = onCommand
        nsView.onKeyDown = { event in context.coordinator.handle(event) }
        nsView.onResign = { context.coordinator.resign() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ nsView: KeyCaptureNSView, coordinator: Coordinator) {
        coordinator.invalidateTimer()
        nsView.teardown()
    }

    final class Coordinator {
        var input: Binding<KeyboardInput> = .constant(KeyboardInput())
        var isPairing = false
        var onPIN: (PINKey) -> Void = { _ in }
        var onCommand: (KeyboardInput.Command) -> Void = { _ in }
        private var timer: Timer?

        func handle(_ event: NSEvent) -> Bool {
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) {
                if isPairing && !isTextToggle(event) { return false }
            } else if isPairing {
                invalidateTimer()
                return handlePIN(event)
            }

            invalidateTimer()
            var model = input.wrappedValue
            let decision = model.handle(stroke(from: event), now: Date())
            input.wrappedValue = model
            decision.commands.forEach(onCommand)
            if let until = decision.commitHomeAt {
                let delay = max(until.timeIntervalSinceNow, 0.01)
                timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.commitHome()
                }
            }
            return decision.consume
        }

        func resign() {
            invalidateTimer()
            var model = input.wrappedValue
            model.cancelPendingHome()
            input.wrappedValue = model
        }

        func invalidateTimer() {
            timer?.invalidate()
            timer = nil
        }

        private func commitHome() {
            timer = nil
            var model = input.wrappedValue
            let command = model.commitPendingHome(now: Date())
            input.wrappedValue = model
            if let command { onCommand(command) }
        }

        private func handlePIN(_ event: NSEvent) -> Bool {
            if event.keyCode == KeyboardInput.KeyCode.delete {
                onPIN(.backspace)
                return true
            }
            if let character = event.characters?.first, let digit = character.wholeNumberValue {
                onPIN(.digit(digit))
                return true
            }
            return true
        }

        private func isTextToggle(_ event: NSEvent) -> Bool {
            event.keyCode == KeyboardInput.KeyCode.t
                && event.modifierFlags.contains(.command)
                && !event.modifierFlags.contains(.shift)
                && !event.modifierFlags.contains(.control)
                && !event.modifierFlags.contains(.option)
        }

        private func stroke(from event: NSEvent) -> KeyboardInput.Stroke {
            let flags = event.modifierFlags
            return KeyboardInput.Stroke(
                keyCode: event.keyCode,
                characters: event.characters ?? "",
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                control: flags.contains(.control),
                option: flags.contains(.option),
                isRepeat: event.isARepeat
            )
        }
    }
}

private final class KeyCaptureNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onResign: (() -> Void)?
    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        teardown()
        guard let window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, event.window === window, window.isKeyWindow else { return event }
            return self.onKeyDown?(event) == true ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onResign?()
        }
    }

    func teardown() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
    }

    deinit { teardown() }
}

private struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ChromeView()
        DispatchQueue.main.async { Self.style(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.style(nsView.window) }
    }

    fileprivate static func style(_ window: NSWindow?) {
        guard let window, !isStyling else { return }
        isStyling = true
        defer { isStyling = false }
        WindowKey.enable()
        window.title = "ATV KBD"
        window.styleMask = [.borderless, .resizable, .miniaturizable, .closable]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.black.cgColor
            content.layer?.cornerRadius = 10
            content.layer?.masksToBounds = true
        }
        window.isMovable = true
        window.isMovableByWindowBackground = false
        if !didCompactFrame {
            didCompactFrame = true
            Self.applyCompactFrame(window)
            // SwiftUI restores the previous frame just after launch. Apply again once that settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Self.applyCompactFrame(window)
            }
        }
    }

    private static var didCompactFrame = false
    private static var isStyling = false

    static let collapsedHeight: CGFloat = 250
    private static var expandedExtra: CGFloat = 0

    /// Grow or shrink downward so the top edge, and the name row, stay put.
    static func applyHeight(extra: CGFloat) {
        expandedExtra = extra
        guard let window = NSApp.windows.first(where: { $0.title == "ATV KBD" }) else { return }
        var frame = window.frame
        let height = collapsedHeight + extra
        let delta = height - frame.height
        guard abs(delta) > 0.5 else { return }
        frame.origin.y -= delta
        frame.size.height = height
        window.setFrame(frame, display: true, animate: false)
    }

    private static func applyCompactFrame(_ window: NSWindow) {
        let width: CGFloat = 280
        let height = collapsedHeight + expandedExtra
        var frame = window.frame
        frame.origin.x += (frame.width - width) / 2
        frame.origin.y += frame.height - height
        frame.size = NSSize(width: width, height: height)
        window.setFrame(frame, display: true)
    }
}

/// A borderless window cannot become key unless these getters say so.
private enum WindowKey {
    static func enable() {
        _ = once
    }

    private static let once: Void = {
        let yes: @convention(block) (AnyObject) -> Bool = { _ in true }
        let implementation = imp_implementationWithBlock(yes)
        class_replaceMethod(NSWindow.self, #selector(getter: NSWindow.canBecomeKey), implementation, "c@:")
        class_replaceMethod(NSWindow.self, #selector(getter: NSWindow.canBecomeMain), implementation, "c@:")
    }()
}

/// Reapplies the flat-black chrome whenever AppKit rebuilds the titlebar.
private final class ChromeView: NSView {
    private var observer: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        guard let window else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            WindowChrome.style(window)
        }
        WindowChrome.style(window)
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}

private struct ControlHit: Equatable {
    var id: String
    var core: CGRect
    var padded: CGRect
}

private struct ControlHitAreaKey: PreferenceKey {
    static var defaultValue: [ControlHit] = []
    static func reduce(value: inout [ControlHit], nextValue: () -> [ControlHit]) {
        value.append(contentsOf: nextValue())
    }
}

/// Remembers a larger hit target around a control. The padding does not change layout.
private extension View {
    func controlHitArea(_ id: String, _ insets: EdgeInsets = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)) -> some View {
        background {
            GeometryReader { proxy in
                let core = proxy.frame(in: .named("kbd"))
                Color.clear.preference(
                    key: ControlHitAreaKey.self,
                    value: [ControlHit(id: id, core: core, padded: core.expanded(by: insets))]
                )
            }
        }
    }
}

private extension CGRect {
    func expanded(by insets: EdgeInsets) -> CGRect {
        CGRect(
            x: minX - insets.leading,
            y: minY - insets.top,
            width: width + insets.leading + insets.trailing,
            height: height + insets.top + insets.bottom
        )
    }

    var area: CGFloat { width * height }
}

private final class HitStore {
    static let shared = HitStore()
    var controls: [ControlHit] = []
    var onActivate: (String) -> Void = { _ in }
}

/// Keeps the click handler for the padded area around buttons.
private struct HitBridge: NSViewRepresentable {
    var onActivate: (String) -> Void

    func makeNSView(context: Context) -> WindowDragView {
        let view = WindowDragView()
        view.install()
        return view
    }

    func updateNSView(_ nsView: WindowDragView, context: Context) {
        HitStore.shared.onActivate = onActivate
    }

    static func dismantleNSView(_ nsView: WindowDragView, coordinator: Void) {
        nsView.teardown()
    }
}

private final class WindowDragView: NSView {
    private var monitor: Any?
    private var pendingID: String?
    private var pendingPoint: CGPoint = .zero

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self, let window = self.window, event.window === window, let host = window.contentView else { return event }
            let point = host.convert(event.locationInWindow, from: nil)
            let local = host.isFlipped ? point : CGPoint(x: point.x, y: host.bounds.height - point.y)
            if event.type == .leftMouseUp {
                return self.finishClick(at: local, event)
            }
            if let action = self.windowControlAction(for: event) {
                NSApp.perform(action, with: nil)
                return nil
            }
            let controls = HitStore.shared.controls
            if controls.contains(where: { $0.core.contains(local) }) {
                self.pendingID = nil
                return event
            }
            if let pad = controls.filter({ $0.padded.contains(local) }).min(by: { $0.padded.area < $1.padded.area }) {
                self.pendingID = pad.id
                self.pendingPoint = local
                return nil
            }
            self.pendingID = nil
            window.performDrag(with: event)
            return nil
        }
    }

    private func finishClick(at local: CGPoint, _ event: NSEvent) -> NSEvent? {
        guard let id = pendingID else { return event }
        pendingID = nil
        let moved = hypot(local.x - pendingPoint.x, local.y - pendingPoint.y)
        if moved < 6 { HitStore.shared.onActivate(id) }
        return nil
    }

    /// Red and yellow stay their drawn 12-point size, with no extra hit padding.
    private func windowControlAction(for event: NSEvent) -> Selector? {
        guard let host = window?.contentView else { return nil }
        let point = host.convert(event.locationInWindow, from: nil)
        let local = host.isFlipped ? point : CGPoint(x: point.x, y: host.bounds.height - point.y)
        let close = CGRect(x: 10, y: 16, width: 12, height: 12)
        let hide = CGRect(x: 30, y: 16, width: 12, height: 12)
        if close.contains(local) { return #selector(NSApplication.terminate(_:)) }
        if hide.contains(local) { return #selector(NSApplication.hide(_:)) }
        return nil
    }

    func teardown() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit { teardown() }
}
