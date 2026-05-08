import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: gate

    required property var backend

    visible: !backend.licenseAllowed
    enabled: visible
    z: 1000
    focus: visible

    function submit() {
        if (backend.licenseBusy || keyInput.text.trim().length === 0)
            return
        backend.activateLicense(keyInput.text)
    }

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(0, parent.height - AppTheme.shellRadius)
            color: AppTheme.background
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: AppTheme.shellRadius * 2
            radius: AppTheme.shellRadius
            color: AppTheme.background
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }

    AppPanel {
        id: panel
        anchors.centerIn: parent
        width: Math.min(430, Math.max(300, gate.width - 42))
        height: content.implicitHeight + padding * 2
        padding: 18
        panelColor: AppTheme.surface

        ColumnLayout {
            id: content
            anchors.fill: parent
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Активация BOSTONCREW SAMPLER"
                color: AppTheme.text
                font.family: AppTheme.fontFamily
                font.pixelSize: 19
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Введите ключ, купленный на bostoncrew.ru. Первый запуск требует интернет, затем приложение сможет открываться оффлайн на этом устройстве."
                color: AppTheme.muted
                font.family: AppTheme.fontFamily
                font.pixelSize: 12
                lineHeight: 1.2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            AppTextField {
                id: keyInput
                Layout.fillWidth: true
                Layout.preferredHeight: 38
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
                Layout.minimumHeight: 38
                text: gate.backend.licenseErrorMessage !== ""
                    ? gate.backend.licenseErrorMessage
                    : gate.backend.licenseMessage
                color: gate.backend.licenseErrorMessage !== "" ? AppTheme.danger : AppTheme.muted
                font.family: AppTheme.fontFamily
                font.pixelSize: 12
                lineHeight: 1.18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                TextButton {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 36
                    text: "Купить ключ"
                    onClicked: gate.backend.openPurchasePage()
                }

                TextButton {
                    id: activateButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    text: gate.backend.licenseBusy ? "Проверяем..." : "Активировать"
                    accentFill: true
                    enabled: !gate.backend.licenseBusy && keyInput.text.trim().length > 0
                    onClicked: gate.submit()
                }
            }
        }
    }

    BusyIndicator {
        anchors.horizontalCenter: panel.horizontalCenter
        anchors.top: panel.bottom
        anchors.topMargin: 14
        running: gate.backend.licenseBusy
        visible: running
    }

    Component.onCompleted: {
        if (visible)
            keyInput.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible)
            keyInput.forceActiveFocus()
    }
}
