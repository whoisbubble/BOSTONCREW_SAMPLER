import QtQuick

Item {
    id: control

    property bool checked: false
    property string text: ""

    signal toggled()

    implicitWidth: contentRow.implicitWidth
    implicitHeight: 24
    opacity: enabled ? 1.0 : 0.45

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: 22
            height: 22
            radius: 6
            color: control.checked ? AppTheme.primary : AppTheme.inputBackground
            border.color: control.checked ? AppTheme.accent : (checkMouse.containsMouse ? AppTheme.muted : AppTheme.inputBorder)
            border.width: 1

            AppIcon {
                anchors.centerIn: parent
                width: 14
                height: 14
                name: "check"
                visible: control.checked
                lineColor: AppTheme.text
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            color: checkMouse.containsMouse ? AppTheme.text : AppTheme.muted
            font.family: AppTheme.fontFamily
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: checkMouse
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            control.checked = !control.checked
            control.toggled()
        }
    }
}
