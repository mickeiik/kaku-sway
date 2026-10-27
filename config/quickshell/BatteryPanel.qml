import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower

Popout {
    id: root

    readonly property var dev: BatteryService.device
    readonly property real level: BatteryService.level
    readonly property bool charging: BatteryService.charging
    readonly property bool discharging: dev.state === UPowerDeviceState.Discharging
    // Below this the rate is just noise and time estimates are meaningless
    readonly property bool rateKnown: dev.changeRate >= 0.5

    // Extra details only the kernel knows (filled in from sysfs below)
    property var sys: ({})

    function hoursMinutes(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? h + " h " + String(m).padStart(2, "0") + " min" : m + " min";
    }

    readonly property string status: {
        switch (dev.state) {
        case UPowerDeviceState.FullyCharged: return "Fully charged";
        case UPowerDeviceState.Charging: return rateKnown ? "Charging at " + dev.changeRate.toFixed(1) + " W" : "Charging";
        case UPowerDeviceState.Discharging: return rateKnown ? "Using " + dev.changeRate.toFixed(1) + " W" : "On battery";
        case UPowerDeviceState.PendingCharge: return "Plugged in, not charging";
        default: return "Plugged in";
        }
    }

    readonly property string timeLabel: charging ? "Full in" : "Time left"
    readonly property string timeValue: { // "" when there's no estimate
        if (!rateKnown || !(charging || discharging))
            return "";
        const t = charging ? dev.timeToFull : dev.timeToEmpty;
        return t > 0 ? hoursMinutes(t) : "";
    }

    // Current full capacity vs. when new; batteries report it in Wh or in mAh
    readonly property real health: {
        if (dev.healthSupported && dev.healthPercentage > 0)
            return dev.healthPercentage;
        const full = parseFloat(sys.energy_full ?? sys.charge_full);
        const design = parseFloat(sys.energy_full_design ?? sys.charge_full_design);
        return full > 0 && design > 0 ? full / design * 100 : 0;
    }

    readonly property string chargeMode: {
        const mode = (sys.charge_types || "").match(/\[(\w+)\]/)?.[1] ?? "";
        if (mode === "Custom" && sys.charge_control_start_threshold && sys.charge_control_end_threshold)
            return "Custom (" + sys.charge_control_start_threshold + "–" + sys.charge_control_end_threshold + "%)";
        return mode;
    }

    cardWidth: 380

    // One-shot read of battery details from sysfs ("key=value" lines)
    Process {
        running: true
        command: ["sh", "-c", "b=$(ls -d /sys/class/power_supply/BAT* | head -1); for f in charge_full charge_full_design energy_full energy_full_design charge_types charge_control_start_threshold charge_control_end_threshold cycle_count manufacturer model_name technology; do [ -r \"$b/$f\" ] && echo \"$f=$(cat \"$b/$f\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        out[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.sys = out;
            }
        }
    }

    PanelHeader {
        title: "Battery"
        detail: UPower.onBattery ? "On battery" : "Plugged in"
    }

    // Charge at a glance
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Label {
            text: Math.round(root.level * 100) + "%"
            font.pixelSize: Theme.fontSize * 2.4
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 8
            color: Theme.bgAlt

            Rectangle {
                height: parent.height
                width: parent.width * root.level
                color: BatteryService.levelColor
            }
        }

        Label {
            text: root.status
            color: root.charging ? Theme.green : Theme.fg
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
        }
        Label {
            visible: root.timeValue !== ""
            text: root.timeLabel + " " + root.timeValue
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
        }
    }

    Separator {}

    // Details
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        InfoRow { label: "Power source"; value: UPower.onBattery ? "Battery" : "AC adapter" }
        InfoRow {
            visible: root.rateKnown
            label: root.charging ? "Charging speed" : "Power draw"
            value: root.dev.changeRate.toFixed(1) + " W"
        }
        InfoRow { visible: root.timeValue !== ""; label: root.timeLabel; value: root.timeValue }
        InfoRow { label: "Energy"; value: root.dev.energy.toFixed(1) + " / " + root.dev.energyCapacity.toFixed(1) + " Wh" }
        InfoRow {
            label: "Health"
            value: root.health > 0 ? Math.round(root.health) + "%" : "—"
            valueColor: root.health > 0 && root.health < 70 ? Theme.yellow : Theme.fg
        }
        InfoRow { visible: root.chargeMode !== ""; label: "Charge mode"; value: root.chargeMode }
        InfoRow { visible: parseInt(root.sys.cycle_count) > 0; label: "Cycles"; value: root.sys.cycle_count }
        InfoRow {
            visible: !!root.sys.model_name
            label: "Model"
            value: [root.sys.manufacturer, root.sys.model_name, root.sys.technology].filter(x => x).join(" ")
        }
    }

    SectionLabel { text: "Power mode" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { profile: PowerProfile.PowerSaver, icon: "\uf06c", color: Theme.green, text: "Power saver" },
                { profile: PowerProfile.Balanced, icon: "\uf24e", color: Theme.fg, text: "Balanced" },
                { profile: PowerProfile.Performance, icon: "\uf135", color: Theme.red, text: "Performance" }
            ]

            SegmentButton {
                required property var modelData
                visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                icon: modelData.icon
                iconColor: modelData.color
                text: modelData.text
                selected: PowerProfiles.profile === modelData.profile
                onClicked: PowerProfiles.profile = modelData.profile
            }
        }
    }
}
