import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: gate

    required property var backend
    property bool expanded: false

    visible: !backend.licenseAllowed
    enabled: visible
    z: 1000

    function submit() {
        if (backend.licenseBusy || keyInput.text.trim().length === 0)
            return
        backend.activateLicense(keyInput.text)
    }

    TextButton {
        id: openButton

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        width: 136
        height: 34
        text: gate.expanded ? "Hide key" : "Enter key"
        accentFill: true
        visible: !gate.expanded
        onClicked: {
            gate.expanded = true
            keyInput.forceActiveFocus()
        }
    }

    AppPanel {
        id: panel

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        width: Math.min(390, Math.max(310, gate.width - 28))
        height: content.implicitHeight + padding * 2
        padding: 14
        panelColor: AppTheme.surfaceRaised
        visible: gate.expanded

        ColumnLayout {
            id: content

            anchors.fill: parent
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Free mode"
                    color: AppTheme.text
                    font.family: AppTheme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                TextButton {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 28
                    text: "Hide"
                    onClicked: gate.expanded = false
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Limits: 3 slide buttons, 5 samples, 5 slide blocks, 5 media files per slide."
                color: AppTheme.muted
                font.family: AppTheme.fontFamily
                font.pixelSize: 11
                lineHeight: 1.15
                wrapMode: Text.WordWrap
            }

            AppTextField {
                id: keyInput

                Layout.fillWidth: true
                Layout.preferredHeight: 36
                placeholderText: "BCS-XXXX-XXXX-XXXX-XXXX"
                enabled: !gate.backend.licenseBusy
                horizontalAlignment: TextInput.AlignHCenter
                inputMethodHints: Qt.ImhUppercaseOnly | Qt.ImhNoPredictiveText
                onTextEdited: {
                    const cursor = cursorPosition
                    text = text.toUpperCase()
                    cursorPosition = cursor
                }
                onAccepted: gate.submit()
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumHeight: 32
                text: gate.backend.licenseErrorMessage !== ""
                    ? gate.backend.licenseErrorMessage
                    : gate.backend.licenseMessage
                color: gate.backend.licenseErrorMessage !== "" ? AppTheme.danger : AppTheme.muted
                font.family: AppTheme.fontFamily
                font.pixelSize: 11
                lineHeight: 1.12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextButton {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 34
                    text: "Buy key"
                    onClicked: gate.backend.openPurchasePage()
                }

                TextButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    text: gate.backend.licenseBusy ? "Checking..." : "Activate"
                    accentFill: true
                    enabled: !gate.backend.licenseBusy && keyInput.text.trim().length > 0
                    onClicked: gate.submit()
                }
            }
        }
    }

    BusyIndicator {
        anchors.horizontalCenter: panel.horizontalCenter
        anchors.bottom: panel.top
        anchors.bottomMargin: 10
        running: gate.backend.licenseBusy
        visible: running
    }

    onExpandedChanged: {
        if (expanded)
            keyInput.forceActiveFocus()
    }
}
