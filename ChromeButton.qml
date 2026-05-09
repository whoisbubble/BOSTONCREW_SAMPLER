import QtQuick
import QtQuick.Controls

Item {
    id: control

    property string iconName: "min"
    property bool destructive: false
    property string tip: ""

    signal clicked(var mouse)

    implicitWidth: 38
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouseArea.pressed
            ? (control.destructive ? "#5a1823" : AppTheme.tilePressed)
            : (mouseArea.containsMouse
                ? (control.destructive ? "#46131b" : AppTheme.tileHover)
                : "transparent")
        border.width: mouseArea.containsMouse ? 1 : 0
        border.color: control.destructive ? AppTheme.danger : AppTheme.border
    }

    AppIcon {
        anchors.centerIn: parent
        width: 15
        height: 15
        name: control.iconName
        lineColor: control.destructive ? "#ffe3e7" : AppTheme.muted
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { control.clicked(mouse) }
    }

    ToolTip.visible: control.tip !== "" && mouseArea.containsMouse
    ToolTip.delay: 650
    ToolTip.timeout: 5000
    ToolTip.text: control.tip
}
