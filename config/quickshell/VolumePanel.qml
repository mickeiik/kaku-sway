import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Output, input (with a live level), then per-app volume
Popout {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Audio nodes sorted in one pass: outputs, inputs, and apps playing sound
    // (playback streams count as sinks; recording ones, like our level meter, don't)
    readonly property var nodes: {
        const result = { outputs: [], inputs: [], apps: [] };
        for (const n of Pipewire.nodes.values) {
            if (!n.audio)
                continue;
            if (!n.isStream)
                (n.isSink ? result.outputs : result.inputs).push(n);
            else if (n.isSink && !/quickshell/i.test(n.properties["application.name"] ?? n.name))
                result.apps.push(n);
        }
        return result;
    }

    function isHeadset(n) {
        const f = n.properties["device.form-factor"];
        return f === "headphone" || f === "headset";
    }

    // Volume control for the current device, then the devices to pick from
    component DeviceSection: ColumnLayout {
        id: section

        property string title
        property PwNode current
        property var devices: []
        property bool input: false
        signal picked(PwNode node)

        Layout.fillWidth: true
        spacing: 6

        SectionLabel { Layout.topMargin: 0; text: section.title }

        VolumeRow {
            node: section.current
            showLevel: section.input
            icon: section.input ? "" : ""
            mutedIcon: section.input ? "" : ""
        }

        Repeater {
            model: ScriptModel { values: section.devices }

            MenuRow {
                required property PwNode modelData
                icon: root.isHeadset(modelData) ? (section.input ? "" : "") : (section.input ? "" : "")
                text: modelData.description || modelData.nickname || modelData.name
                checked: modelData.id === section.current?.id
                onClicked: section.picked(modelData)
            }
        }
    }

    cardWidth: 380

    PwObjectTracker { objects: [root.sink, root.source].concat(root.nodes.outputs, root.nodes.inputs, root.nodes.apps) }

    PanelHeader { title: "Sound" }

    NowPlaying { id: nowPlaying }
    Separator { visible: nowPlaying.visible }

    DeviceSection {
        title: "Output"
        current: root.sink
        devices: root.nodes.outputs
        onPicked: n => Pipewire.preferredDefaultAudioSink = n
    }

    Separator { visible: root.nodes.inputs.length > 0 }

    DeviceSection {
        visible: root.nodes.inputs.length > 0
        title: "Input"
        current: root.source
        devices: root.nodes.inputs
        input: true
        onPicked: n => Pipewire.preferredDefaultAudioSource = n
    }

    SectionLabel {
        visible: root.nodes.apps.length > 0
        text: "Applications"
    }

    Repeater {
        model: ScriptModel { values: root.nodes.apps }

        ColumnLayout {
            id: app
            required property PwNode modelData
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: app.modelData.properties["application.name"] || app.modelData.description || app.modelData.name
                textFormat: Text.PlainText // names come from apps
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            ValueSlider {
                Layout.fillWidth: true
                value: app.modelData.audio.volume
                onMoved: v => app.modelData.audio.volume = v
            }
        }
    }
}
