import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popout {
    id: root

    readonly property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()

    function shift(n) {
        const d = new Date(year, month + n, 1);
        month = d.getMonth();
        year = d.getFullYear();
    }

    cardWidth: 320

    RowLayout {
        Layout.fillWidth: true

        MenuRow { icon: ""; Layout.fillWidth: false; implicitWidth: 36; onClicked: root.shift(-1) }
        Label {
            text: Theme.locale.toString(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        MenuRow { icon: ""; Layout.fillWidth: false; implicitWidth: 36; onClicked: root.shift(1) }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: Theme.locale
        delegate: Text {
            required property string shortName
            text: shortName.slice(0, 2)
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 3
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MonthGrid {
        Layout.fillWidth: true
        locale: Theme.locale
        Layout.preferredHeight: 6 * 34 + 5 * spacing
        month: root.month
        year: root.year

        delegate: Rectangle {
            required property var model
            readonly property bool isToday: model.today

            implicitHeight: 34
            color: isToday ? Theme.accent : "transparent"

            Label {
                anchors.centerIn: parent
                text: parent.model.day
                color: parent.isToday ? Theme.bg : parent.model.month === root.month ? Theme.fg : Theme.border
                font.pixelSize: Theme.fontSize - 2
                font.bold: parent.isToday
            }
        }
    }
}
