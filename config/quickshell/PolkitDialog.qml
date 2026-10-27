import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

// Password window for apps asking for admin rights (the polkit authentication agent).
// Fedora's polkit asks for your own password (you're in the wheel group), or your
// fingerprint once one is enrolled. Enter confirms, Escape refuses.
Scope {
    id: root

    property string error: ""

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: root.error = ""
    }

    Connections {
        target: agent.flow
        ignoreUnknownSignals: true
        // A wrong password: polkit starts over, keep the dialog open and say so
        function onFailedChanged() {
            if (agent.flow.failed)
                root.error = "Wrong password, try again.";
        }
    }

    PanelWindow {
        id: window

        readonly property var flow: agent.flow

        visible: agent.isActive && flow !== null
        screen: Util.focusedScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-polkit"
        // Modal while open: it needs the keyboard for the password
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) password.forceActiveFocus()

        // The screen behind, dimmed
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            opacity: 0.6
        }

        // Just what's asking and the password field: Enter confirms, Escape cancels
        Card {
            anchors.centerIn: parent
            width: 440
            height: column.implicitHeight + 32

            ColumnLayout {
                id: column

                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // What the app wants to do, in its own words: never ask for the
                // password without saying what for
                Label {
                    text: window.flow?.message ?? ""
                    textFormat: Text.PlainText
                    color: Theme.muted
                    font.pixelSize: Theme.fontSize - 1
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: Theme.bgAlt
                    border.color: root.error ? Theme.red : Theme.accent
                    border.width: 1

                    TextInput {
                        id: password

                        function submit() {
                            if (window.flow?.isResponseRequired && text !== "") {
                                window.flow.submit(text);
                                text = "";
                            }
                        }

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: window.flow?.isResponseRequired ?? false
                        echoMode: window.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        focus: true

                        onTextChanged: if (text !== "") root.error = ""
                        onAccepted: submit()
                        Keys.onEscapePressed: {
                            text = "";
                            window.flow?.cancelAuthenticationRequest();
                        }

                        // Errors, PAM's messages (e.g. a fingerprint request), else its prompt
                        Label {
                            readonly property string pam: window.flow?.supplementaryMessage ?? ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            visible: password.text === ""
                            text: root.error || pam || (window.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: root.error || window.flow?.supplementaryIsError ? Theme.red
                                : pam ? Theme.yellow : Theme.muted
                        }
                    }
                }
            }
        }
    }
}
