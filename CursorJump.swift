// compile and create executable
// swiftc -o cursorjump cursorjump.swift


import Cocoa
import Carbon.HIToolbox

// MARK: - Cursor warping logic

func jumpCursorToOtherDisplay() {
    let screens = NSScreen.screens
    guard screens.count >= 2 else { return }

    // Current cursor position in Cocoa coordinates (origin bottom-left of main screen)
    let mouseCocoa = NSEvent.mouseLocation

    // Find which screen the cursor is currently on
    let currentScreen = screens.first { NSMouseInRect(mouseCocoa, $0.frame, false) }
        ?? NSScreen.main!

    // Pick the "other" screen (with 2 displays this is a perfect toggle;
    // with 3+ it cycles to the next one in the list)
    guard let currentIndex = screens.firstIndex(of: currentScreen) else { return }
    let target = screens[(currentIndex + 1) % screens.count]

    // Center of target screen, in Cocoa coordinates
    let f = target.frame
    let centerCocoa = NSPoint(x: f.midX, y: f.midY)

    // Convert Cocoa coords (bottom-left origin, y up) -> Quartz/CG coords (top-left origin, y down).
    // Quartz global space shares its origin with the main display's top-left.
    let mainScreenHeight = NSScreen.screens[0].frame.maxY
    let centerCG = CGPoint(x: centerCocoa.x, y: mainScreenHeight - centerCocoa.y)

    // Warp the cursor
    CGWarpMouseCursorPosition(centerCG)

    // Post a synthetic mouse-moved event so apps notice the cursor immediately
    if let move = CGEvent(mouseEventSource: nil,
                          mouseType: .mouseMoved,
                          mouseCursorPosition: centerCG,
                          mouseButton: .left) {
        move.post(tap: .cghidEventTap)
    }
}

// MARK: - Global hot key (Carbon RegisterEventHotKey — no Accessibility permission needed)

var hotKeyRef: EventHotKeyRef?

func registerHotKey() {
    // ⌥X  (kVK_ANSI_X = 7)
    let modifiers: UInt32 = UInt32(optionKey)
    let keyCode: UInt32 = UInt32(kVK_ANSI_X)

    let hotKeyID = EventHotKeyID(signature: OSType(0x4355_524A), // 'CURJ'
                                 id: 1)

    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))

    InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
        var hkID = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject),
                          EventParamType(typeEventHotKeyID), nil,
                          MemoryLayout<EventHotKeyID>.size, nil, &hkID)
        if hkID.id == 1 {
            jumpCursorToOtherDisplay()
        }
        return noErr
    }, 1, &eventType, nil, nil)

    RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                        GetApplicationEventTarget(), 0, &hotKeyRef)
}

// MARK: - App bootstrap (background agent, no Dock icon)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, no menu bar
registerHotKey()
print("CursorJump running — press ⌥X to toggle cursor between displays.")
app.run()















/*
// compile and create executable
// swiftc -o cursorjump cursorjump.swift



Run in background
nohup ./CursorJump >/dev/null 2>&1 &
disown


pkill -f CursorJump




*/




