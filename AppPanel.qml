import QtQuick

Rectangle {
    id: panel

    property int padding: 14
    property color panelColor: AppTheme.surface
    default property alias contentData: content.data

    radius: AppTheme.panelRadius
    color: panel.panelColor
    border.color: AppTheme.border
    border.width: 1
    clip: true

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: panel.padding
    }
}
