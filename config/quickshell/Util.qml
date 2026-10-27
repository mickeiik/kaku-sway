pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3

// Small helpers shared by several components
Singleton {
    // The screen that has focus (where the launcher and pop-ups appear)
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) ?? Quickshell.screens[0]

    function clamp01(v) {
        return Math.max(0, Math.min(1, v));
    }

    // Scroll amount where "up" is positive. The touchpad uses natural scrolling,
    // so it's flipped to keep "swipe up = more".
    function wheelDelta(wheel) {
        return wheel.pixelDelta.y !== 0 ? -wheel.angleDelta.y : wheel.angleDelta.y;
    }

    // A volume-like value after one scroll step: up to 100%, but a value already
    // above 100% (set elsewhere) isn't pulled down
    function scrollStep(value, step) {
        return step > 0 ? Math.max(value, Math.min(1, value + step)) : Math.max(0, value + step);
    }

    // "m:ss"
    function duration(seconds) {
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
}
