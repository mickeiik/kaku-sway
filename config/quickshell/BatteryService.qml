pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery state shared by the bar icon and the battery panel, and the low battery
// warnings: a notification at 10%, a critical one (stays until dismissed) at 5%.
// Plugging in replaces it with a short "Charging" one.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device.isLaptopBattery
    readonly property real level: device.percentage > 1 ? device.percentage / 100 : device.percentage
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    readonly property bool full: device.state === UPowerDeviceState.FullyCharged
    readonly property color levelColor: level < 0.1 ? Theme.red : level < 0.2 ? Theme.yellow : Theme.green
    readonly property string icon: charging || full ? "" : ["", "", "", "", ""][Math.min(4, Math.floor(level * 5))]

    readonly property bool discharging: device.state === UPowerDeviceState.Discharging
    property int warned: 0 // last warning given (10 or 5), 0 = none since last plugged in

    function notify(urgency, title, body, timeout) {
        // Same tag: each one replaces the previous battery notification
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", urgency, "-t", String(timeout),
            "-i", urgency === "critical" ? "battery-caution" : "battery-low",
            "-h", "string:x-canonical-private-synchronous:battery", title, body]);
    }

    function check() {
        if (!present)
            return;
        if (!discharging) {
            if (warned > 0 && charging)
                notify("low", "Charging", Math.round(level * 100) + "%", 3000);
            warned = 0;
            return;
        }
        const percent = Math.round(level * 100);
        const minutes = Math.round(device.timeToEmpty / 60);
        const left = minutes <= 0 ? ""
            : ", about " + (minutes >= 60 ? Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " min" : minutes + " min") + " left";
        if (percent <= 5 && warned !== 5) {
            warned = 5;
            notify("critical", "Battery almost empty", percent + "%" + left + ". Plug in now.", 0);
        } else if (percent <= 10 && percent > 5 && warned === 0) {
            warned = 10;
            notify("normal", "Battery low", percent + "%" + left + ".", 8000);
        }
    }

    onLevelChanged: check()
    onDischargingChanged: check()
}
