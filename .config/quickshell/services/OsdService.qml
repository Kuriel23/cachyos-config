// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S D   S E R V I C E                                                  │
// │   turns system changes into one transient island event                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every ephemeral system change arrives at the island through one signal.
//
// Volume, brightness and battery all render in the same layer, so adding an
// event later means emitting `requested`, not writing another layer. A bar is
// drawn when `progress` is 0 or more; pass -1 for a message with no level.
Singleton {
    id: root

    signal requested(string icon, string label, real progress)

    // Read LED state, never key presses. One long-lived, unprivileged process.
    readonly property Process keyboardLocks: Process {
        command: ["python3", "-u", Quickshell.shellPath("scripts/keyboard_locks.py")]
        running: true
        stdout: SplitParser {
            onRead: line => root.ingestKeyboardLock(line)
        }
        onExited: root.keyboardLockRetry.restart()
    }

    readonly property Timer keyboardLockRetry: Timer {
        interval: 5000
        onTriggered: root.keyboardLocks.running = true
    }

    function ingestKeyboardLock(line: string): void {
        let event
        try {
            event = JSON.parse(line)
        } catch (error) {
            return
        }
        if (!event || typeof event.enabled !== "boolean" || !root.armed)
            return
        if (event.lock === "fnlock") {
            root.requested("Fn", event.enabled ? "Fn Lock On" : "Fn Lock Off", -1)
            return
        }
        if (event.lock === "kbd_backlight") {
            const level = typeof event.level === "number" ? event.level : 0
            const maximum = typeof event.maximum === "number" ? event.maximum : 0
            const progress = typeof event.progress === "number" ? event.progress : -1
            root.requested("⌨", level === 0 ? "Keyboard Backlight Off" :
                           maximum > 0 ? `Keyboard Backlight ${Math.round(progress * 100)}%` : "Keyboard Backlight On", progress)
            return
        }
        const labels = { capslock: "Caps Lock", numlock: "Num Lock", scrolllock: "Scroll Lock" }
        const icons = { capslock: "⇪", numlock: "#", scrolllock: "↕" }
        if (!Object.prototype.hasOwnProperty.call(labels, event.lock))
            return
        root.requested(icons[event.lock],
                       labels[event.lock] + (event.enabled ? " On" : " Off"), -1)
    }

    // Bindings fire once as they initialise. Emitting then would pop an OSD
    // every time the shell starts, so nothing is emitted until this is armed.
    property bool armed: false

    // One frame. Holding a volume key fires dozens of changes and the island
    // would stutter through every one of them.
    readonly property int debounce: 16

    // A device connecting reports its own volume, which is not the user asking
    // to see the volume. Ignore it for as long as the switch takes.
    property bool audioSuppressed: false
    readonly property int suppression: 2000

    readonly property Timer armTimer: Timer {
        interval: 600
        running: true
        onTriggered: root.armed = true
    }

    readonly property Timer suppressionTimer: Timer {
        interval: root.suppression
        onTriggered: root.audioSuppressed = false
    }

    readonly property Timer volumeTimer: Timer {
        interval: root.debounce
        // Muted keeps the real level, so raising the volume while muted still
        // shows the new value. Skipped while the volume detail is open: its
        // slider already shows it, and the OSD would cover it.
        onTriggered: {
            if (ModuleService.openId === "volume")
                return
            root.requested(AudioService.icon,
                           `${AudioService.volume}%`,
                           AudioService.volume / 100)
        }
    }

    // The screen whose level changed, which is not always the focused one:
    // the backlight also moves on its own.
    property var brightnessDisplay: null

    readonly property Timer brightnessTimer: Timer {
        interval: root.debounce
        // Skipped while the brightness detail is open.
        onTriggered: {
            const display = root.brightnessDisplay
            if (!display || ModuleService.openId === "brightness")
                return
            root.requested(display.icon, `${display.percent}%`, display.percent / 100)
        }
    }

    readonly property Connections audio: Connections {
        target: AudioService
        enabled: root.armed && !root.audioSuppressed
        function onVolumeChanged(): void { root.volumeTimer.restart() }
        function onMutedChanged(): void { root.volumeTimer.restart() }
    }

    // Not on the reading: that also changes when the focus moves to another
    // screen, which is not the user asking to see it.
    readonly property Connections brightness: Connections {
        target: BrightnessService
        enabled: root.armed
        function onAdjusted(display): void {
            root.brightnessDisplay = display
            root.brightnessTimer.restart()
        }
    }

    // Not debounced: plugging in cannot repeat fast enough to need it.
    readonly property Connections battery: Connections {
        target: BatteryService
        enabled: root.armed
        function onChargingChanged(): void {
            root.requested(BatteryService.icon,
                           BatteryService.charging ? "Charging" : "On battery",
                           BatteryService.percent / 100)
        }
    }

    function suppressAudio(): void {
        root.audioSuppressed = true
        root.suppressionTimer.restart()
    }
}
