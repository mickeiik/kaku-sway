import QtQuick
import QtQuick.Layouts

// The ntfy panel's settings (NtfyService): server, account, topics, and from
// which priority each topic's messages also pop up. Saved right away; the server
// and topics are checked against the server first.
ColumnLayout {
    id: root

    property string serverResult: ""
    property bool serverOk: false
    property bool showToken: false
    property bool showPassword: false
    property bool useToken: false // paste an access token instead of signing in
    property string accountResult: ""
    property bool signingIn: false
    property string topicResult: ""

    // The popup level choices: ntfy priorities go from 1 (min) to 5 (max)
    readonly property var levels: [
        { label: "All", value: 1 }, { label: "3+", value: 3 }, { label: "4+", value: 4 }, { label: "Off", value: 6 }
    ]

    function test() {
        serverResult = "Checking…";
        serverOk = false;
        NtfyService.testServer(NtfyService.server, (ok, text) => {
            serverOk = ok;
            serverResult = text;
        });
    }

    function saveServer() {
        const url = NtfyService.normalizeServer(serverBox.text);
        if (url === "") {
            serverBox.error = true;
            return;
        }
        serverBox.text = url;
        NtfyService.setServer(url);
        test();
    }

    function saveToken() {
        if (tokenBox.text.trim() === "")
            return;
        NtfyService.saveToken(tokenBox.text);
        tokenBox.clear();
        showToken = false;
        if (NtfyService.server !== "")
            testAfterSave.restart();
    }

    function signIn() {
        if (userBox.text.trim() === "" || passwordBox.text === "")
            return;
        if (NtfyService.server === "") {
            accountResult = "Set the server first";
            return;
        }
        signingIn = true;
        accountResult = "Signing in…";
        NtfyService.signIn(userBox.text.trim(), passwordBox.text, (ok, text) => {
            signingIn = false;
            accountResult = text;
            if (ok) {
                passwordBox.clear();
                showPassword = false;
            } else {
                passwordBox.error = true;
            }
        });
    }

    function addTopic() {
        const name = topicBox.text.trim();
        if (name === "")
            return;
        if (NtfyService.server === "") {
            topicResult = "Set the server first";
            return;
        }
        topicResult = "Checking…";
        NtfyService.checkTopic(name, (ok, text) => {
            if (ok) {
                NtfyService.addTopic(name);
                topicBox.clear();
                topicResult = "";
            } else {
                topicBox.error = true;
                topicResult = text;
            }
        });
    }

    Layout.fillWidth: true
    spacing: 8
    Component.onCompleted: serverBox.text = NtfyService.server

    // The token is written in the background: test it once it's there
    Timer {
        id: testAfterSave
        interval: 500
        onTriggered: root.test()
    }

    SectionLabel { text: "Server" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        TextBox {
            id: serverBox
            placeholder: "https://ntfy.sh"
            onAccepted: root.saveServer()
        }
        TextButton {
            text: "Save"
            onClicked: root.saveServer()
        }
    }

    Label {
        visible: root.serverResult !== ""
        text: root.serverResult
        color: root.serverOk ? Theme.green : root.serverResult === "Checking…" ? Theme.muted : Theme.yellow
        font.pixelSize: Theme.fontSize - 2
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    SectionLabel { text: "Account" }

    // Signed in: who, and signing out
    RowLayout {
        visible: NtfyService.hasToken
        Layout.fillWidth: true
        spacing: 6

        Label {
            text: NtfyService.account !== "" ? "Signed in as " + NtfyService.account : "Signed in"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        TextButton {
            text: "Sign out"
            onClicked: {
                root.accountResult = "";
                NtfyService.signOut();
            }
        }
    }

    // Not signed in: username and password (or an access token)
    ColumnLayout {
        visible: !NtfyService.hasToken && !root.useToken
        Layout.fillWidth: true
        spacing: 6

        TextBox {
            id: userBox
            placeholder: "Username"
            onAccepted: passwordBox.takeFocus()
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextBox {
                id: passwordBox
                echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                placeholder: "Password"
                onAccepted: root.signIn()
            }
            IconButton {
                icon: root.showPassword ? "" : ""
                onClicked: root.showPassword = !root.showPassword
            }
            TextButton {
                text: "Sign in"
                enabled: !root.signingIn && userBox.text.trim() !== "" && passwordBox.text !== ""
                onClicked: root.signIn()
            }
        }
    }

    RowLayout {
        visible: !NtfyService.hasToken && root.useToken
        Layout.fillWidth: true
        spacing: 6

        TextBox {
            id: tokenBox
            echoMode: root.showToken ? TextInput.Normal : TextInput.Password
            placeholder: "tk_…"
            onAccepted: root.saveToken()
        }
        IconButton {
            icon: root.showToken ? "" : ""
            onClicked: root.showToken = !root.showToken
        }
        TextButton {
            text: "Save"
            enabled: tokenBox.text.trim() !== ""
            onClicked: root.saveToken()
        }
    }

    Label {
        visible: root.accountResult !== ""
        text: root.accountResult
        color: root.accountResult === "Signing in…" ? Theme.muted : Theme.yellow
        font.pixelSize: Theme.fontSize - 2
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    Label {
        visible: !NtfyService.hasToken
        text: root.useToken
            ? "Create one in ntfy's web app: Account > Access tokens. Kept in ~/.config/kaku/ntfy-token, on this PC only."
            : "Your password isn't kept: the server gives this PC its own access token instead."
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 3
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    TextButton {
        visible: !NtfyService.hasToken
        text: root.useToken ? "Sign in with a password instead" : "Use an access token instead"
        onClicked: {
            root.useToken = !root.useToken;
            root.accountResult = "";
        }
    }

    SectionLabel { text: "Topics" }

    Label {
        visible: NtfyService.topics.length === 0
        text: "No topics yet"
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
    }

    Repeater {
        model: NtfyService.topics

        RowLayout {
            id: topicRow

            required property var modelData

            Layout.fillWidth: true
            spacing: 6

            Label {
                text: topicRow.modelData.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            // Same width on every row, so the choices line up (a layout of filling
            // buttons would fill too otherwise)
            RowLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 200
                spacing: 2

                Repeater {
                    model: root.levels

                    SegmentButton {
                        required property var modelData
                        text: modelData.label
                        padding: 5
                        selected: topicRow.modelData.popup === modelData.value
                        onClicked: NtfyService.setPopup(topicRow.modelData.name, modelData.value)
                    }
                }
            }
            IconButton {
                icon: ""
                onClicked: NtfyService.removeTopic(topicRow.modelData.name)
            }
        }
    }

    Label {
        visible: NtfyService.topics.length > 0
        text: "Pop-up: from which priority a message also shows as a notification. All of them are listed here."
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 3
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        TextBox {
            id: topicBox
            placeholder: "Add a topic"
            onAccepted: root.addTopic()
        }
        TextButton {
            icon: ""
            text: "Add"
            onClicked: root.addTopic()
        }
    }

    Label {
        visible: root.topicResult !== ""
        text: root.topicResult
        color: root.topicResult === "Checking…" ? Theme.muted : Theme.yellow
        font.pixelSize: Theme.fontSize - 2
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
}
