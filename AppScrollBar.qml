import QtQuick
import QtQuick.Controls

ScrollBar {
    id: control
    interactive: true
    hoverEnabled: true
    padding: 2

    contentItem: Rectangle {
        implicitWidth: control.hovered || control.pressed ? 10 : 6
        implicitHeight: 40
        radius: width / 2
        color: control.pressed ? AppTheme.accent : (control.hovered ? AppTheme.text : AppTheme.muted)
        opacity: control.policy === ScrollBar.AlwaysOn || control.size < 1.0 ? 1.0 : 0.0
        
        Behavior on implicitWidth { NumberAnimation { duration: 150 } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
