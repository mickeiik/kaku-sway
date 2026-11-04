import QtQuick
import QtQuick.Layouts
import Quickshell

// ntfy messages (NtfyService), newest first, filtered by topic. A click on a long
// message shows all of its text; the x on a message (or Clear all) clears it here. Attachments open with this PC's apps (the browser if none
// can), links and "Open in ntfy" in the browser. The gear shows the settings
// (NtfySettings). Closing the panel marks everything read.
Popout {
    id: root

    property bool settings: !NtfyService.configured
    property string topic: "" // "" = all topics
    property string expandedId: ""

    readonly property var shown: NtfyService.items.filter(m => topic === "" || m.topic === topic)

    // "mer. 4 nov. 2026 · 14:32"
    function dateTime(time) {
        return new Date(time * 1000).toLocaleString(Theme.locale, "ddd d MMM yyyy · HH:mm");
    }

    function size(bytes) {
        return bytes >= 1e6 ? (bytes / 1e6).toFixed(1) + " MB" : bytes >= 1e3 ? Math.round(bytes / 1e3) + " KB" : bytes + " B";
    }

    // Plain text with its web links clickable
    function linkify(text) {
        return NtfyService.escapeMarkup(text).replace(/(https?:\/\/[^\s<]+[^\s<.,;:!?)])/g, '<a href="$1">$1</a>').replace(/\n/g, "<br>");
    }

    function priorityColor(p) {
        return p >= 5 ? Theme.red : p === 4 ? Theme.orange : p === 3 ? Theme.accent : Theme.muted;
    }

    cardWidth: 440
    Component.onDestruction: NtfyService.markRead()

    RowLayout {
        Layout.fillWidth: true

        Label {
            text: root.settings ? "ntfy settings" : "Notifications"
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            Layout.fillWidth: true
        }

        // Connect again now (it also does by itself after a drop)
        IconButton {
            visible: NtfyService.configured
            icon: ""
            spinning: NtfyService.configured && !NtfyService.connected && NtfyService.error === ""
            onClicked: NtfyService.restart()
        }
        IconButton {
            icon: ""
            active: root.settings
            onClicked: root.settings = !root.settings
        }
    }

    Label {
        visible: NtfyService.error !== "" && NtfyService.configured
        text: NtfyService.error
        color: Theme.yellow
        font.pixelSize: Theme.fontSize - 2
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    NtfySettings {
        visible: root.settings
    }

    // --- messages ---------------------------------------------------------

    RowLayout {
        visible: !root.settings && NtfyService.topics.length > 1
        Layout.fillWidth: true
        spacing: 2

        SegmentButton {
            text: "All"
            padding: 6
            selected: root.topic === ""
            onClicked: root.topic = ""
        }
        Repeater {
            model: NtfyService.topics

            SegmentButton {
                required property var modelData
                readonly property int unread: NtfyService.unread.filter(m => m.topic === modelData.name).length

                text: modelData.name + (unread > 0 ? " · " + unread : "")
                padding: 6
                selected: root.topic === modelData.name
                onClicked: root.topic = modelData.name
            }
        }
    }

    Label {
        visible: !root.settings && root.shown.length === 0
        text: NtfyService.messages.length > 0 ? "No messages" : NtfyService.connected ? "No messages in the last 7 days" : "Loading…"
        color: Theme.muted
        Layout.topMargin: 6
        Layout.bottomMargin: 6
    }

    // The list, with a scroll bar and faded edges when it's longer than the panel
    Item {
        visible: !root.settings && root.shown.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.contentHeight, 560)

        ListView {
            id: list

            readonly property bool scrollable: contentHeight > height + 1

            anchors.fill: parent
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            // ScriptModel keeps the existing rows (and the scroll position) when one comes in
            model: ScriptModel { values: root.shown }

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property var m: modelData
                readonly property bool unread: m.time > NtfyService.readUntil
                readonly property bool open: root.expandedId === m.id

                width: list.width - (list.scrollable ? 12 : 0)
                implicitHeight: body.implicitHeight + 20
                color: hover.hovered ? Qt.tint(Theme.card, Qt.alpha(Theme.accent, 0.1)) : Theme.card
                Behavior on color { ColorAnimation { duration: 100 } }

                // Long text (cut at 3 lines) or shown in full
                readonly property bool expandable: open || textLabel.truncated

                // Hovered anywhere on the card, its text and buttons included
                HoverHandler {
                    id: hover
                    cursorShape: row.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                // Under the text and buttons: a click elsewhere on the card shows all its text
                MouseArea {
                    anchors.fill: parent
                    enabled: row.expandable
                    onClicked: root.expandedId = row.open ? "" : row.m.id
                }

                // Priority stripe
                Rectangle {
                    width: 3
                    height: parent.height
                    color: root.priorityColor(row.m.priority)
                }

                ColumnLayout {
                    id: body

                    x: 15
                    y: 10
                    width: parent.width - 27
                    spacing: 6

                    // When it came, whether it's unread, and clearing it
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: root.dateTime(row.m.time)
                            color: Theme.fgDim
                            font.pixelSize: Theme.fontSize - 3
                        }
                        Rectangle {
                            visible: row.unread
                            implicitWidth: 7
                            implicitHeight: 7
                            color: root.priorityColor(row.m.priority)
                        }
                        Item { Layout.fillWidth: true }
                        IconButton {
                            icon: "\uf00d"
                            Layout.topMargin: -6
                            Layout.bottomMargin: -6
                            Layout.rightMargin: -6
                            onClicked: NtfyService.clear([row.m.id])
                        }
                    }

                    Label {
                        text: (NtfyService.emojiOf(row.m) ? NtfyService.emojiOf(row.m) + " " : "") + NtfyService.heading(row.m)
                        textFormat: Text.PlainText
                        font.bold: true
                        color: Theme.fg
                        wrapMode: Text.Wrap // shown in full, on more lines if needed
                        Layout.fillWidth: true
                    }

                    Label {
                        id: textLabel
                        visible: row.m.text !== ""
                        text: root.linkify(row.m.text)
                        textFormat: Text.StyledText
                        color: Theme.fgDim
                        linkColor: Theme.accent
                        font.pixelSize: Theme.fontSize - 2
                        wrapMode: Text.Wrap
                        maximumLineCount: row.open ? 1000 : 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        onLinkActivated: link => NtfyService.openLink(link)
                    }

                    // Says that the card opens, and closes again
                    RowLayout {
                        visible: row.expandable
                        spacing: 6

                        Icon {
                            text: row.open ? "\uf077" : "\uf078"
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize - 5
                        }
                        Label {
                            text: row.open ? "Show less" : "Show more"
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }

                    // Topic (when all are shown), other tags, attachment, link: one line, the
                    // attachment's name cut to fit
                    Row {
                        id: extras

                        readonly property bool showTopic: root.topic === "" && NtfyService.topics.length > 1
                        readonly property var tags: NtfyService.wordTags(row.m)

                        visible: showTopic || tags.length > 0 || row.m.attachment !== null || row.m.click !== ""
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 6

                        Label {
                            id: topicLabel
                            anchors.verticalCenter: parent.verticalCenter
                            visible: extras.showTopic
                            text: row.m.topic
                            textFormat: Text.PlainText
                            color: Theme.cyan
                            font.pixelSize: Theme.fontSize - 3
                        }
                        Row {
                            id: tagRow
                            anchors.verticalCenter: parent.verticalCenter
                            visible: extras.tags.length > 0
                            spacing: 6

                            Repeater {
                                model: extras.tags

                                Label {
                                    required property string modelData
                                    text: "#" + modelData
                                    textFormat: Text.PlainText
                                    color: Theme.fgDim
                                    font.pixelSize: Theme.fontSize - 3
                                }
                            }
                        }
                        TextButton {
                            // "backup-2026-11-04" + ".log · 51 KB"
                            readonly property string name: row.m.attachment?.name ?? ""
                            readonly property string ext: (name.match(/\.[A-Za-z0-9]{1,8}$/) ?? [""])[0]

                            visible: row.m.attachment !== null
                            enabled: !NtfyService.attachmentExpired(row.m)
                            fill: Theme.border
                            icon: "\uf0c6"
                            text: name.slice(0, name.length - ext.length)
                            suffix: ext + " · " + root.size(row.m.attachment?.size ?? 0) + (enabled ? "" : " (expired)")
                            // What's left of the line
                            maxWidth: Math.max(80, extras.width
                                - (topicLabel.visible ? topicLabel.implicitWidth + 6 : 0)
                                - (tagRow.visible ? tagRow.implicitWidth + 6 : 0)
                                - (linkButton.visible ? linkButton.implicitWidth + 6 : 0))
                            onClicked: NtfyService.openAttachment(row.m)
                        }
                        TextButton {
                            id: linkButton
                            visible: row.m.click !== ""
                            fill: Theme.border
                            icon: "\uf35d"
                            text: "Open link"
                            onClicked: NtfyService.openLink(row.m.click)
                        }
                    }
                }
            }
        }

        // Scroll bar: its size shows how much of the list is in view; drag it or click
        // its track to move
        Rectangle {
            visible: list.scrollable
            anchors.right: parent.right
            width: 6
            height: parent.height
            color: Theme.card

            // From the list's visible area: its cards differ in height, so it only
            // estimates its full length, and its start (originY) moves as it scrolls
            Rectangle {
                readonly property real ratio: list.visibleArea.heightRatio
                width: parent.width
                height: Math.max(24, parent.height * ratio)
                y: Math.max(0, Math.min(parent.height - height,
                    (parent.height - height) * list.visibleArea.yPosition / Math.max(0.001, 1 - ratio)))
                color: track.pressed || track.containsMouse ? Theme.accent : Theme.border
            }
            MouseArea {
                id: track
                anchors.fill: parent
                anchors.leftMargin: -4
                hoverEnabled: true
                function scrollTo(y) {
                    list.contentY = list.originY + Math.max(0, Math.min(1, y / height)) * (list.contentHeight - list.height);
                }
                onPressed: mouse => scrollTo(mouse.y)
                onPositionChanged: mouse => {
                    if (pressed)
                        scrollTo(mouse.y);
                }
            }
        }

        // Faded edges: there's more above / below
        Rectangle {
            visible: list.scrollable && !list.atYBeginning
            width: list.width - 12
            height: 28
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.bg }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            visible: list.scrollable && !list.atYEnd
            anchors.bottom: parent.bottom
            width: list.width - 12
            height: 36
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Theme.bg }
            }
        }
    }

    RowLayout {
        visible: !root.settings && NtfyService.configured
        Layout.fillWidth: true
        spacing: 6

        // The topic in ntfy's web app (the first one when all are shown)
        TextButton {
            icon: ""
            text: "Open in ntfy"
            onClicked: NtfyService.openLink(NtfyService.topicUrl(root.topic || NtfyService.topics[0].name))
        }
        Item { Layout.fillWidth: true }
        // Clears what's listed (with the topic filter: that topic's)
        TextButton {
            visible: root.shown.length > 0
            icon: "\uf1f8"
            text: "Clear all"
            onClicked: {
                NtfyService.clear(root.shown.map(m => m.id));
                root.expandedId = "";
            }
        }
        TextButton {
            visible: NtfyService.unread.length > 0
            icon: ""
            text: "Mark all read"
            onClicked: NtfyService.markRead()
        }
    }
}
