import QtQuick
import QtQuick.Controls

Switch {
    id: control

    implicitWidth: 54
    implicitHeight: 30

    indicator: Rectangle {
        implicitWidth: 54
        implicitHeight: 30
        radius: 15
        color: control.checked ? AppTheme.primary : AppTheme.inputBackground
        border.color: control.checked ? AppTheme.accent : AppTheme.inputBorder
        border.width: 1

        Rectangle {
            width: 22
            height: 22
            radius: 11
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? parent.width - width - 4 : 4
            color: control.checked ? AppTheme.text : AppTheme.muted

            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    contentItem: Item {}
}
