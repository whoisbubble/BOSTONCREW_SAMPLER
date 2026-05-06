import QtQuick
import QtQuick.Window

Item {
    id: handle

    property int edge: Qt.RightEdge
    property int thickness: 8

    readonly property bool hasLeft: (edge & Qt.LeftEdge) !== 0
    readonly property bool hasRight: (edge & Qt.RightEdge) !== 0
    readonly property bool hasTop: (edge & Qt.TopEdge) !== 0
    readonly property bool hasBottom: (edge & Qt.BottomEdge) !== 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: (handle.hasLeft || handle.hasRight) && (handle.hasTop || handle.hasBottom)
            ? (handle.hasLeft === handle.hasTop ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
            : ((handle.hasLeft || handle.hasRight) ? Qt.SizeHorCursor : Qt.SizeVerCursor)
        onPressed: {
            if (Window.window)
                Window.window.startSystemResize(handle.edge)
        }
    }
}
