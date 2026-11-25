import XCTest

final class KeyboardInputTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func stroke(
        _ keyCode: UInt16,
        characters: String = "",
        command: Bool = false,
        shift: Bool = false,
        control: Bool = false,
        option: Bool = false,
        isRepeat: Bool = false
    ) -> KeyboardInput.Stroke {
        KeyboardInput.Stroke(
            keyCode: keyCode,
            characters: characters,
            command: command,
            shift: shift,
            control: control,
            option: option,
            isRepeat: isRepeat
        )
    }

    func testRemoteKeysMapToTheAppleTV() {
        var input = KeyboardInput()
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.up), now: start).commands, [.moveUp])
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.down), now: start).commands, [.moveDown])
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.left), now: start).commands, [.moveLeft])
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.right), now: start).commands, [.moveRight])
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.returnKey), now: start).commands, [.select])
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.space), now: start).commands, [.playPause])
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.escape), now: start).commands, [.menu])
    }

    func testSingleHWaitsThenSendsHome() {
        var input = KeyboardInput()
        let first = input.handle(stroke(KeyboardInput.KeyCode.h), now: start)
        XCTAssertEqual(first.commands, [])
        XCTAssertEqual(first.commitHomeAt, start.addingTimeInterval(KeyboardInput.doubleTapInterval))
        XCTAssertNil(input.commitPendingHome(now: start.addingTimeInterval(0.1)))
        XCTAssertEqual(input.commitPendingHome(now: start.addingTimeInterval(KeyboardInput.doubleTapInterval)), .home)
    }

    func testHHSendsHomeDoublePress() {
        var input = KeyboardInput()
        _ = input.handle(stroke(KeyboardInput.KeyCode.h), now: start)
        let second = input.handle(stroke(KeyboardInput.KeyCode.h), now: start.addingTimeInterval(0.2))
        XCTAssertEqual(second.commands, [.homeDouble])
        XCTAssertNil(second.commitHomeAt)
        XCTAssertNil(input.commitPendingHome(now: start.addingTimeInterval(1)))
    }

    func testHAfterTheWindowIsANewHome() {
        var input = KeyboardInput()
        _ = input.handle(stroke(KeyboardInput.KeyCode.h), now: start)
        XCTAssertEqual(input.commitPendingHome(now: start.addingTimeInterval(0.3)), .home)
        let again = input.handle(stroke(KeyboardInput.KeyCode.h), now: start.addingTimeInterval(0.5))
        XCTAssertEqual(again.commands, [])
        XCTAssertNotNil(again.commitHomeAt)
    }

    func testAnotherKeyFlushesTheWaitingHome() {
        var input = KeyboardInput()
        _ = input.handle(stroke(KeyboardInput.KeyCode.h), now: start)
        let next = input.handle(stroke(KeyboardInput.KeyCode.right), now: start.addingTimeInterval(0.05))
        XCTAssertEqual(next.commands, [.home, .moveRight])
    }

    func testRepeatedHDoesNotDouble() {
        var input = KeyboardInput()
        _ = input.handle(stroke(KeyboardInput.KeyCode.h), now: start)
        let repeatHold = input.handle(stroke(KeyboardInput.KeyCode.h, isRepeat: true), now: start.addingTimeInterval(0.05))
        XCTAssertEqual(repeatHold.commands, [])
        XCTAssertNotNil(repeatHold.commitHomeAt)
    }

    func testCommandTTogglesTextMode() {
        var input = KeyboardInput()
        let on = input.handle(stroke(KeyboardInput.KeyCode.t, command: true), now: start)
        XCTAssertEqual(on.commands, [.toggleText])
        XCTAssertTrue(on.consume)
        XCTAssertTrue(input.textMode)
        let off = input.handle(stroke(KeyboardInput.KeyCode.t, command: true), now: start)
        XCTAssertEqual(off.commands, [.toggleText])
        XCTAssertFalse(input.textMode)
    }

    func testHTypesAnHInTextMode() {
        var input = KeyboardInput()
        _ = input.handle(stroke(KeyboardInput.KeyCode.t, command: true), now: start)
        let typed = input.handle(stroke(KeyboardInput.KeyCode.h, characters: "h"), now: start)
        XCTAssertEqual(typed.commands, [.replaceText("h")])
        XCTAssertEqual(input.text, "h")
        XCTAssertNil(typed.commitHomeAt)
    }

    func testShiftHTypesHInTextMode() {
        var input = KeyboardInput()
        input.textMode = true
        let typed = input.handle(stroke(KeyboardInput.KeyCode.h, characters: "H", shift: true), now: start)
        XCTAssertEqual(typed.commands, [.replaceText("H")])
    }

    func testSpaceTypesASpaceInTextModeAndArrowsStillMove() {
        var input = KeyboardInput()
        input.textMode = true
        XCTAssertEqual(
            input.handle(stroke(KeyboardInput.KeyCode.space, characters: " "), now: start).commands,
            [.replaceText(" ")]
        )
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.up), now: start).commands, [.moveUp])
        XCTAssertEqual(input.handle(stroke(KeyboardInput.KeyCode.returnKey), now: start).commands, [.select])
    }

    func testBackspaceDeletesTypedText() {
        var input = KeyboardInput()
        input.textMode = true
        _ = input.handle(stroke(KeyboardInput.KeyCode.h, characters: "h"), now: start)
        let deleted = input.handle(stroke(KeyboardInput.KeyCode.delete), now: start)
        XCTAssertEqual(deleted.commands, [.replaceText("")])
        XCTAssertEqual(input.text, "")
    }

    func testCommandShortcutsPassThrough() {
        var input = KeyboardInput()
        let quit = input.handle(stroke(12, command: true), now: start)
        XCTAssertFalse(quit.consume)
        XCTAssertTrue(quit.commands.isEmpty)
        let hide = input.handle(stroke(KeyboardInput.KeyCode.h, command: true), now: start)
        XCTAssertFalse(hide.consume)
        XCTAssertFalse(input.textMode)
    }

    func testCheatSheetFollowsTheMode() {
        let remote = KeyboardInput.hints(textMode: false)
        XCTAssertEqual(remote.first { $0.id == "h" }?.action, "Home")
        XCTAssertEqual(remote.first { $0.id == "hh" }?.action, "App Switcher")
        XCTAssertEqual(remote.first { $0.id == "toggle" }?.action, "Type")

        let typing = KeyboardInput.hints(textMode: true)
        XCTAssertEqual(typing.first { $0.id == "h" }?.action, "h")
        XCTAssertNil(typing.first { $0.id == "hh" })
        XCTAssertEqual(typing.first { $0.id == "toggle" }?.action, "Remote keys")
    }
}
