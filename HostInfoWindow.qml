import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: infoWindow

    property real ownerX: 0
    property real ownerY: 0

    function openInfo(xValue, yValue) {
        ownerX = xValue
        ownerY = yValue
        x = Math.max(40, ownerX + 120)
        y = Math.max(40, ownerY + 86)
        show()
        raise()
        requestActivate()
    }

    width: 560
    height: 520
    minimumWidth: 460
    minimumHeight: 360
    visible: false
    title: "BOSTONCREW SAMPLER / Host info"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: AppTheme.shellRadius
        color: AppTheme.background
        border.color: AppTheme.border
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    acceptedButtons: Qt.LeftButton
                    onPressed: infoWindow.startSystemMove()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BOSTONCREW SAMPLER / Host info"
                    color: AppTheme.text
                    font.family: AppTheme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                ChromeButton {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "close"
                    destructive: true
                    onClicked: infoWindow.hide()
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                background: Rectangle {
                    radius: AppTheme.panelRadius
                    color: AppTheme.surface
                    border.color: AppTheme.border
                    border.width: 1
                }

                TextArea {
                    width: parent.availableWidth
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextArea.Wrap
                    color: AppTheme.text
                    selectedTextColor: AppTheme.text
                    selectionColor: AppTheme.primary
                    font.family: AppTheme.fontFamily
                    font.pixelSize: 12
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 12
                    bottomPadding: 12
                    text:
                        "Как подключать host\n\n" +
                        "Для твоего ESP32 кода компьютер должен быть подключен к Wi-Fi TUMBA_SHOW_KANYEWEST. Адрес host: 192.168.4.15:81. Приложение подключается как WebSocket-клиент к ws://192.168.4.15:81/ без TLS.\n\n" +
                        "Что должен сделать host\n" +
                        "1. Слушать TCP-порт.\n" +
                        "2. Принять обычный WebSocket upgrade.\n" +
                        "3. Ответить HTTP 101 Switching Protocols.\n" +
                        "4. После этого читать и отправлять текстовые WebSocket frames.\n\n" +
                        "Что приложение отправляет\n" +
                        "После успешного подключения сразу уходят два текстовых сообщения:\n" +
                        "HOST\n" +
                        "HSFALSE\n\n" +
                        "Во время работы:\n" +
                        "RIGHT - когда запускается фиксированный сэмпл OK.\n" +
                        "WRONG - когда запускается фиксированный сэмпл NO.\n\n" +
                        "Что приложение принимает\n" +
                        "Если host присылает текст Игрок 1 или Игрок 2, приложение запускает фиксированный сэмпл P1.\n\n" +
                        "Важно\n" +
                        "Приложение не является WebSocket-сервером. Оно только подключается к внешнему host. Если статус показывает timeout, чаще всего Windows не подключен к Wi-Fi ESP32, адрес 192.168.4.15 недоступен или порт 81 закрыт. Если TCP подключился, но upgrade отклонён, host не отвечает как WebSocket-сервер."

                    background: null
                }
            }
        }
    }

    WindowResizeHandle {
        edge: Qt.RightEdge
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: thickness
    }

    WindowResizeHandle {
        edge: Qt.BottomEdge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: thickness
    }

    WindowResizeHandle {
        edge: Qt.RightEdge | Qt.BottomEdge
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: thickness + 5
        height: thickness + 5
    }
}
