import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: bar

    required property var backend
    property bool maximized: false
    property bool licensed: true

    signal hostRequested()
    signal remoteRequested()
    signal minimizeRequested()
    signal maximizeRequested()
    signal closeRequested()

    implicitHeight: 42

    MouseArea {
        anchors.left: parent.left
        anchors.right: controls.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (Window.window)
                Window.window.startSystemMove()
        }
        onDoubleClicked: bar.maximizeRequested()
    }

    RowLayout {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        spacing: 6

        IconButton {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 30
            side: 30
            iconSize: 16
            iconSource: "qrc:/assets/icons/host.svg"
            showChrome: false
            enabled: bar.licensed
            onClicked: bar.hostRequested()
        }

        IconButton {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 30
            side: 30
            iconSize: 16
            iconSource: "qrc:/assets/icons/remote.svg"
            showChrome: false
            enabled: bar.licensed
            onClicked: bar.remoteRequested()
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: AppTheme.border
        }

        ChromeButton {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 30
            iconName: "min"
            onClicked: bar.minimizeRequested()
        }

        ChromeButton {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 30
            iconName: bar.maximized ? "restore" : "max"
            onClicked: bar.maximizeRequested()
        }

        ChromeButton {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 30
            iconName: "close"
            destructive: true
            onClicked: bar.closeRequested()
        }
    }
}
