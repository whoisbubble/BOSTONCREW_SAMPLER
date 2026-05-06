import QtQuick
import QtQuick.Window

Item {
    id: overlayRoot

    readonly property var hostWindow: Window.window
    readonly property bool roundedHost: hostWindow && hostWindow.visibility !== Window.Maximized

    Rectangle {
        anchors.fill: parent
        anchors.margins: overlayRoot.roundedHost ? 5 : 0
        radius: overlayRoot.roundedHost ? AppTheme.shellRadius : 0
        color: AppTheme.overlay
        clip: true
    }
}
