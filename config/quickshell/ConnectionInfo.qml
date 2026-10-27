import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Details of the connection used to reach the internet: live traffic, link
// quality and addresses. Only polls while the network panel is open.
ColumnLayout {
    id: root

    property var info: ({})
    property real rxRate: 0 // bytes per second
    property real txRate: 0
    property var lastSample: null

    readonly property bool isWifi: info.type === "wifi"
    readonly property var wifiFields: (info.wifi ?? "").split(":") // SIGNAL:FREQ:CHAN:SECURITY
    readonly property int freq: parseInt(wifiFields[1]) || 0

    function rate(bytesPerSec) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let v = Math.max(0, bytesPerSec), i = 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1000; i++; }
        return (v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)) + " " + units[i];
    }
    function band(mhz) {
        return mhz < 3000 ? "2.4 GHz" : mhz < 5925 ? "5 GHz" : "6 GHz";
    }

    visible: info.dev !== undefined
    Layout.fillWidth: true
    spacing: 6

    // Connection details ("key=value" lines), refreshed when the network changes
    Process {
        id: details
        running: true
        command: ["sh", "-c", `
            dev=$(ip -o route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \\([^ ]*\\).*/\\1/p')
            [ -n "$dev" ] || exit 0
            type=$(nmcli -g GENERAL.TYPE device show "$dev")
            echo "dev=$dev"
            echo "type=$type"
            nmcli -t -f GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS device show "$dev" | sed 's/\\\\:/:/g; s/^\\([^:]*\\):/\\1=/'
            # Not managed by NetworkManager (e.g. a VPN client's own tunnel): addresses from the kernel
            [ -n "$type" ] || ip -o addr show dev "$dev" | awk '{ print ($3 == "inet" ? "IP4" : "IP6") ".ADDRESS=" $4 }'
            if [ "$type" = wifi ]; then
                nmcli -t -f IN-USE,SIGNAL,FREQ,CHAN,SECURITY device wifi list ifname "$dev" --rescan no | sed -n 's/^\\*:/wifi=/p'
                iw dev "$dev" link | sed -n 's/^\\s*signal: \\(.*\\)/dbm=\\1/p; s/^\\s*rx bitrate: \\([0-9.]*\\).*/rxlink=\\1/p; s/^\\s*tx bitrate: \\([0-9.]*\\).*/txlink=\\1/p'
            else
                echo "speed=$(cat /sys/class/net/$dev/speed 2>/dev/null)"
            fi
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = { dns: [], ip6: [] };
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0)
                        continue;
                    const key = line.slice(0, i), value = line.slice(i + 1).trim();
                    if (!value)
                        continue;
                    if (key.startsWith("IP4.ADDRESS") && !out.ip4) out.ip4 = value.split("/")[0];
                    else if (key === "IP4.GATEWAY") out.gateway = value;
                    else if (key.startsWith("IP4.DNS")) out.dns.push(value);
                    else if (key.startsWith("IP6.ADDRESS") && !value.startsWith("fe80")) out.ip6.push(value.split("/")[0]);
                    else if (key === "GENERAL.HWADDR") out.mac = value;
                    else out[key] = value;
                }
                if (out.dev !== root.info.dev)
                    root.lastSample = null;
                root.info = out;
            }
        }
    }
    function refresh() {
        if (!details.running)
            details.running = true;
    }
    Connections {
        target: NetworkService
        function onLabelChanged() { root.refresh(); }
        function onWiredChanged() { root.refresh(); }
    }
    // Signal, link speed and the like drift on their own: re-read now and then
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Live traffic from the kernel byte counters, every second
    Process {
        id: traffic
        command: ["cat", `/sys/class/net/${root.info.dev}/statistics/rx_bytes`, `/sys/class/net/${root.info.dev}/statistics/tx_bytes`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [rx, tx] = text.trim().split("\n").map(Number);
                const now = Date.now();
                const last = root.lastSample;
                if (last && now > last.t) {
                    const dt = (now - last.t) / 1000;
                    root.rxRate = (rx - last.rx) / dt;
                    root.txRate = (tx - last.tx) / dt;
                }
                root.lastSample = { rx: rx, tx: tx, t: now };
            }
        }
    }
    Timer {
        interval: 1000
        running: root.info.dev !== undefined
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!traffic.running) traffic.running = true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 6

            SectionLabel { Layout.topMargin: 0; text: "Traffic" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: [
                        { icon: "", color: Theme.green, value: root.rxRate },
                        { icon: "", color: Theme.accent, value: root.txRate }
                    ]

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Icon {
                            text: parent.modelData.icon
                            color: parent.modelData.color
                            font.pixelSize: Theme.fontSize - 2
                        }
                        Label {
                            text: root.lastSample ? root.rate(parent.modelData.value) : "…"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            SectionLabel { text: "Link" }

            InfoRow {
                visible: root.isWifi
                label: "Signal"
                value: (root.wifiFields[0] ? root.wifiFields[0] + "%" : "—") + (root.info.dbm ? "  (" + root.info.dbm + ")" : "")
            }
            InfoRow {
                visible: root.isWifi
                label: "Band"
                value: root.freq ? root.band(root.freq) + " · channel " + root.wifiFields[2] : "—"
            }
            InfoRow {
                label: "Link speed"
                value: root.isWifi
                    ? (root.info.rxlink ? "↓ " + Math.round(root.info.rxlink) + "  ↑ " + Math.round(root.info.txlink) + " Mbit/s" : "—")
                    : (parseInt(root.info.speed) > 0 ? root.info.speed + " Mbit/s" : "—")
            }
            InfoRow {
                label: "Security"
                value: root.isWifi ? (root.wifiFields[3] || "Open")
                    : root.info.type === "ethernet" ? "Wired"
                    : root.info.type === "wireguard" ? "WireGuard"
                    : "VPN"
            }
            InfoRow { label: "Interface"; value: root.info.dev ?? "—" }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.bgAlt
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 6

            SectionLabel { Layout.topMargin: 0; text: "Addresses" }

            InfoRow { label: "IPv4"; value: root.info.ip4 ?? "—"; copyable: true }
            InfoRow {
                visible: root.info.ip6?.length > 0
                label: "IPv6"
                value: root.info.ip6?.[0] ?? "—"
                copyable: true
            }
            InfoRow { label: "Gateway"; value: root.info.gateway ?? "—"; copyable: true }
            Repeater {
                model: root.info.dns ?? []

                InfoRow {
                    required property string modelData
                    required property int index
                    label: index === 0 ? "DNS" : ""
                    value: modelData
                    copyable: true
                }
            }
            InfoRow { label: "MAC"; value: root.info.mac ?? "—"; copyable: true }
        }
    }
}
