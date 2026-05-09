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
    signal helpRequested()
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
            tip: "Host connection"
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
            tip: "Video remote"
            enabled: bar.licensed
            onClicked: bar.remoteRequested()
        }

        IconButton {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 30
            side: 30
            iconSize: 16
            iconName: "help"
            showChrome: false
            tip: "Quick help"
            onClicked: bar.helpRequested()
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
            tip: "Minimize"
            onClicked: bar.minimizeRequested()
        }

        ChromeButton {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 30
            iconName: bar.maximized ? "restore" : "max"
            tip: bar.maximized ? "Restore" : "Maximize"
            onClicked: bar.maximizeRequested()
        }

        ChromeButton {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 30
            iconName: "close"
            destructive: true
            tip: "Close"
            onClicked: bar.closeRequested()
        }
    }
}
