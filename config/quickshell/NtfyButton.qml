import QtQuick

// ntfy messages (NtfyService): a bell with the number of unread ones, red when one
// of them is urgent (priority 4-5), crossed out while the server can't be read.
// Shown once ntfy is set up (Tools > ntfy notifications in the launcher).
BarButton {
    readonly property int count: NtfyService.unread.length
    readonly property bool broken: NtfyService.configured && NtfyService.error !== ""

    visible: NtfyService.enabled
    panel: "ntfy"
    icon: broken ? "" : ""
    iconColor: broken ? Theme.muted : NtfyService.urgent ? Theme.red : count > 0 ? Theme.accent : Theme.fg
    text: count > 0 ? String(count) : ""
    textColor: NtfyService.urgent ? Theme.red : Theme.fg
}
