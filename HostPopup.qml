import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: popup

    required property var backend

    modal: true
    focus: true
    width: Math.min(380, parent ? parent.width - 40 : 380)
    height: 216
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: AppModalOverlay {}

    background: AppPanel {
        padding: 0
        panelColor: AppTheme.surfaceRaised
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Host"
            color: AppTheme.text
            font.family: AppTheme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        AppTextField {
            id: hostField
            Layout.fillWidth: true
            text: popup.backend.savedHost
            placeholderText: "192.168.0.10:81"
            onTextChanged: popup.backend.savedHost = text
            onAccepted: popup.backend.connectHost(text)
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: popup.backend.statusMessage
            color: AppTheme.muted
            font.family: AppTheme.fontFamily
            font.pixelSize: 11
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            TextButton {
                text: "Off"
                onClicked: popup.backend.disconnectHost()
            }

            TextButton {
                text: "Connect"
                accentFill: true
                onClicked: popup.backend.connectHost(hostField.text)
            }
        }
    }
}
