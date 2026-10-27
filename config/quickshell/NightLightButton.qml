import QtQuick

// Night light: click cycles Off → Automatic (sunset to sunrise) → On.
// Blue moon = automatic, orange = on all the time, grey = off.
BarButton {
    icon: ""
    iconColor: NightLightService.mode === "on" ? Theme.orange : NightLightService.mode === "auto" ? Theme.accent : Theme.muted
    onClicked: NightLightService.cycle()
}
