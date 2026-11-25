import Foundation

/// Keys the focused ATV KBD window turns into Apple TV commands.
///
/// A single H waits briefly so a second H can become a Home double-press
/// (the App Switcher) instead of two Home presses. In text mode, H inserts "h".
struct KeyboardInput: Equatable {
    var textMode = false
    private(set) var text = ""
    private var homePendingUntil: Date?

    /// How long the first H waits for a second tap.
    static let doubleTapInterval: TimeInterval = 0.30

    /// Virtual key codes. These match the ANSI keyboard (`kVK_*`).
    enum KeyCode {
        static let h: UInt16 = 4
        static let t: UInt16 = 17
        static let returnKey: UInt16 = 36
        static let space: UInt16 = 49
        static let delete: UInt16 = 51
        static let escape: UInt16 = 53
        static let keypadEnter: UInt16 = 76
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    struct Stroke: Equatable {
        var keyCode: UInt16
        var characters: String
        var command = false
        var shift = false
        var control = false
        var option = false
        var isRepeat = false
    }

    struct Decision: Equatable {
        var commands: [Command]
        var consume: Bool
        /// When set, call `commitPendingHome(now:)` at this time if H was not tapped again.
        var commitHomeAt: Date?
    }

    enum Command: Equatable {
        case moveUp, moveDown, moveLeft, moveRight
        case select
        case playPause
        case menu
        case home
        case homeDouble
        case toggleText
        case replaceText(String)
    }

    struct Hint: Identifiable, Equatable {
        var id: String
        var keys: String
        var action: String
    }

    static func hints(textMode: Bool) -> [Hint] {
        if textMode {
            return [
                Hint(id: "letters", keys: "letters", action: "Type"),
                Hint(id: "h", keys: "H", action: "h"),
                Hint(id: "space", keys: "space", action: "Space"),
                Hint(id: "delete", keys: "delete", action: "Delete"),
                Hint(id: "arrows", keys: "↑ ↓ ← →", action: "Move"),
                Hint(id: "return", keys: "return", action: "Select"),
                Hint(id: "esc", keys: "esc", action: "Back"),
                Hint(id: "toggle", keys: "⌘T", action: "Remote keys"),
            ]
        }
        return [
            Hint(id: "arrows", keys: "↑ ↓ ← →", action: "Move"),
            Hint(id: "return", keys: "return", action: "Select"),
            Hint(id: "space", keys: "space", action: "Play / Pause"),
            Hint(id: "esc", keys: "esc", action: "Back"),
            Hint(id: "h", keys: "H", action: "Home"),
            Hint(id: "hh", keys: "H H", action: "App Switcher"),
            Hint(id: "toggle", keys: "⌘T", action: "Type"),
        ]
    }

    mutating func handle(_ stroke: Stroke, now: Date) -> Decision {
        if isTextToggle(stroke) {
            var commands: [Command] = []
            if let home = flushPendingHome() { commands.append(home) }
            textMode.toggle()
            if !textMode { text = "" }
            commands.append(.toggleText)
            return Decision(commands: commands, consume: true, commitHomeAt: nil)
        }

        // Leave ⌘Q, ⌘W, ⌘H, and other shortcuts to the system.
        if stroke.command || stroke.control || stroke.option {
            homePendingUntil = nil
            return Decision(commands: [], consume: false, commitHomeAt: nil)
        }

        if isHomeKey(stroke), !textMode {
            if stroke.isRepeat {
                return Decision(commands: [], consume: true, commitHomeAt: homePendingUntil)
            }
            if let until = homePendingUntil, now < until {
                homePendingUntil = nil
                return Decision(commands: [.homeDouble], consume: true, commitHomeAt: nil)
            }
            let until = now.addingTimeInterval(Self.doubleTapInterval)
            homePendingUntil = until
            return Decision(commands: [], consume: true, commitHomeAt: until)
        }

        var commands: [Command] = []
        if let home = flushPendingHome() { commands.append(home) }

        if let navigation = navigationCommand(stroke) {
            let repeatable = isArrow(stroke)
            if stroke.isRepeat && !repeatable {
                return Decision(commands: commands, consume: true, commitHomeAt: nil)
            }
            commands.append(navigation)
            return Decision(commands: commands, consume: true, commitHomeAt: nil)
        }

        if textMode && editText(stroke) {
            commands.append(.replaceText(text))
            return Decision(commands: commands, consume: true, commitHomeAt: nil)
        }

        if textMode && (stroke.keyCode == KeyCode.delete || isHomeKey(stroke) || stroke.keyCode == KeyCode.space) {
            return Decision(commands: commands, consume: true, commitHomeAt: nil)
        }

        return Decision(commands: commands, consume: true, commitHomeAt: nil)
    }

    /// Sends the waiting single Home press once the double-tap window has passed.
    mutating func commitPendingHome(now: Date) -> Command? {
        guard let until = homePendingUntil, now >= until else { return nil }
        homePendingUntil = nil
        return .home
    }

    mutating func cancelPendingHome() {
        homePendingUntil = nil
    }

    private mutating func flushPendingHome() -> Command? {
        guard homePendingUntil != nil else { return nil }
        homePendingUntil = nil
        return .home
    }

    private func isTextToggle(_ stroke: Stroke) -> Bool {
        stroke.command && !stroke.shift && !stroke.control && !stroke.option
            && stroke.keyCode == KeyCode.t && !stroke.isRepeat
    }

    private func isHomeKey(_ stroke: Stroke) -> Bool {
        stroke.keyCode == KeyCode.h
    }

    private func isArrow(_ stroke: Stroke) -> Bool {
        switch stroke.keyCode {
        case KeyCode.up, KeyCode.down, KeyCode.left, KeyCode.right: true
        default: false
        }
    }

    private func navigationCommand(_ stroke: Stroke) -> Command? {
        switch stroke.keyCode {
        case KeyCode.up: .moveUp
        case KeyCode.down: .moveDown
        case KeyCode.left: .moveLeft
        case KeyCode.right: .moveRight
        case KeyCode.returnKey, KeyCode.keypadEnter: .select
        case KeyCode.escape: .menu
        case KeyCode.space where !textMode: .playPause
        default: nil
        }
    }

    /// Inserts or deletes text. Returns true when `text` changed.
    private mutating func editText(_ stroke: Stroke) -> Bool {
        if stroke.keyCode == KeyCode.delete {
            guard !text.isEmpty else { return false }
            text.removeLast()
            return true
        }
        guard let character = stroke.characters.first, stroke.characters.count == 1 else { return false }
        guard character == " " || (!character.isNewline && !character.isWhitespace && character.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 0x7F }) else {
            return false
        }
        // Arrow and function keys report private-use characters, not letters.
        guard character.unicodeScalars.allSatisfy({ $0.value < 0xF700 }) else { return false }
        text.append(character)
        return true
    }
}
