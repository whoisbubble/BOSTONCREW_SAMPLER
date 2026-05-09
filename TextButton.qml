import QtQuick
import QtQuick.Controls

Item {
    id: control

    property string text: ""
    property bool accentFill: false
    property bool dangerFill: false
    property string tip: ""

    signal clicked(var mouse)

    implicitWidth: 86
    implicitHeight: 34
    opacity: enabled ? 1.0 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: AppTheme.controlRadius
        color: mouseArea.pressed
            ? (control.accentFill ? AppTheme.secondary : AppTheme.tilePressed)
            : (control.accentFill
                ? AppTheme.primary
                : (control.dangerFill
                    ? Qt.rgba(0.55, 0.12, 0.18, 0.32)
                    : (mouseArea.containsMouse ? AppTheme.tileHover : AppTheme.tile)))
        border.width: 1
        border.color: control.accentFill
            ? AppTheme.accent
            : (control.dangerFill ? AppTheme.danger : AppTheme.border)
    }

    Text {
        anchors.fill: parent
        text: control.text
        color: AppTheme.text
        font.family: AppTheme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: control.enabled
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
