import QtQuick

Item {
    id: control

    property string iconName: "play"
    property url iconSource: ""
    property string tip: ""
    property bool accentFill: false
    property bool dangerFill: false
    property bool showChrome: true
    property int side: 46
    property int iconSize: Math.max(16, Math.round(side * 0.45))

    signal clicked(var mouse)

    implicitWidth: side
    implicitHeight: side
    opacity: enabled ? 1.0 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: AppTheme.controlRadius
        color: !control.showChrome
            ? "transparent"
            : (mouseArea.pressed
            ? (control.dangerFill ? AppTheme.secondary : AppTheme.tilePressed)
            : (control.accentFill
                ? AppTheme.primary
                : (control.dangerFill
                    ? Qt.rgba(0.55, 0.12, 0.18, 0.36)
                    : (mouseArea.containsMouse ? AppTheme.tileHover : AppTheme.tile))))
        border.width: control.showChrome ? 1 : 0
        border.color: control.accentFill
            ? AppTheme.accent
            : (control.dangerFill ? AppTheme.danger : AppTheme.border)
    }

    Image {
        anchors.centerIn: parent
        width: control.iconSize
        height: control.iconSize
        source: control.iconSource
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        opacity: control.showChrome || !control.enabled ? 1.0 : (mouseArea.containsMouse ? 1.0 : 0.74)
        visible: control.iconSource.toString() !== ""
    }

    AppIcon {
        anchors.centerIn: parent
        width: control.iconSize
        height: control.iconSize
        name: control.iconName
        lineColor: control.dangerFill ? "#ffdbe0" : AppTheme.text
        opacity: control.showChrome || !control.enabled ? 1.0 : (mouseArea.containsMouse ? 1.0 : 0.74)
        visible: control.iconSource.toString() === ""
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { control.clicked(mouse) }
    }
}
