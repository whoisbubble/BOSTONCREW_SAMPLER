pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: root

    width: 608
    height: 500
    minimumWidth: 610
    minimumHeight: 390
    maximumWidth: 794
    maximumHeight: 1080
    visible: true
    title: "BOSTONCREW SAMPLER"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window

    // qmllint disable unqualified
    readonly property var backend: samplerBackend
    // qmllint enable unqualified
    readonly property bool maximized: visibility === Window.Maximized

    onClosing: root.backend.saveAll()

    background: Rectangle {
        color: "transparent"
    }

    Rectangle {
        id: windowShadow
        anchors.fill: parent
        anchors.margins: root.maximized ? 0 : 3
        radius: root.maximized ? 0 : 17
        color: AppTheme.shadow
        opacity: root.maximized ? 0 : 0.5
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: root.maximized ? 0 : 5
        radius: root.maximized ? 0 : 15
        color: AppTheme.border

        Rectangle {
            id: shell
            anchors.fill: parent
            anchors.margins: root.maximized ? 0 : 1
            radius: root.maximized ? 0 : 14
            color: AppTheme.background
            border.color: AppTheme.alpha(AppTheme.accent, 0.2)
            border.width: 1
            clip: true

            TitleBar {
                id: titleBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 42
                backend: root.backend
                maximized: root.maximized
                licensed: root.backend.licenseAllowed
                onHostRequested: {
                    if (root.backend.licenseAllowed)
                        hostPopup.open()
                }
                onRemoteRequested: {
                    if (root.backend.licenseAllowed)
                        remoteWindow.openRemote()
                }
                onMinimizeRequested: root.showMinimized()
                onMaximizeRequested: root.maximized ? root.showNormal() : root.showMaximized()
                onCloseRequested: {
                    root.backend.saveAll()
                    Qt.quit()
                }
            }

            DashboardView {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: titleBar.bottom
                anchors.bottom: parent.bottom
                backend: root.backend
                enabled: root.backend.licenseAllowed
                opacity: root.backend.licenseAllowed ? 1.0 : 0.25
                timerRunning: timerWindow.running
                onAssignQuickSlotRequested: function(index) {
                    if (root.backend.licenseAllowed)
                        assignPopup.openFor(index)
                }
                onEditSampleRequested: function(index, sampleName, volume, stopSounds, sampleColor) {
                    if (root.backend.licenseAllowed)
                        sampleDialog.openEditor(index, sampleName, volume, stopSounds, sampleColor)
                }
                onEditSlideRequested: function(index, folderName, slideType) {
                    if (root.backend.licenseAllowed)
                        slideDialog.openEditor(index, folderName, slideType)
                }
                onTimerRequested: {
                    if (root.backend.licenseAllowed)
                        timerWindow.openTimer()
                }
                onManagerRequested: {
                    if (root.backend.licenseAllowed)
                        slideManagerWindow.openManager()
                }
                onPreviewRequested: {
                    if (root.backend.licenseAllowed)
                        previewSelectWindow.openPreview()
                }
            }

            LicenseGate {
                anchors.left: parent.left
                anchors.leftMargin: 1
                anchors.right: parent.right
                anchors.rightMargin: 1
                anchors.top: titleBar.bottom
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                backend: root.backend
            }
        }
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.LeftEdge
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: thickness
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.RightEdge
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: thickness
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.TopEdge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: thickness
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.BottomEdge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: thickness
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.LeftEdge | Qt.TopEdge
        anchors.left: parent.left
        anchors.top: parent.top
        width: thickness + 5
        height: thickness + 5
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.RightEdge | Qt.TopEdge
        anchors.right: parent.right
        anchors.top: parent.top
        width: thickness + 5
        height: thickness + 5
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.LeftEdge | Qt.BottomEdge
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: thickness + 5
        height: thickness + 5
    }

    WindowResizeHandle {
        visible: !root.maximized
        edge: Qt.RightEdge | Qt.BottomEdge
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: thickness + 5
        height: thickness + 5
    }

    AssignSlidePopup {
        id: assignPopup
        parent: Overlay.overlay
        backend: root.backend
    }

    SampleDialog {
        id: sampleDialog
        parent: Overlay.overlay
        backend: root.backend
    }

    SlideDialog {
        id: slideDialog
        parent: Overlay.overlay
        backend: root.backend
    }

    HostPopup {
        id: hostPopup
        parent: Overlay.overlay
        backend: root.backend
        onInfoRequested: hostInfoWindow.openInfo(root.x, root.y)
    }

    HostInfoWindow {
        id: hostInfoWindow
    }

    SlideManagerWindow {
        id: slideManagerWindow
        backend: root.backend
        ownerX: root.x
        ownerY: root.y
    }

    TimerWindow {
        id: timerWindow
    }

    PreviewSelectWindow {
        id: previewSelectWindow
        backend: root.backend
        ownerX: root.x
        ownerY: root.y
    }

    RemoteWindow {
        id: remoteWindow
        backend: root.backend
        ownerX: root.x
        ownerY: root.y
    }

    StageWindow {
        backend: root.backend
        ownerX: root.x
        ownerY: root.y
    }

    Connections {
        target: root.backend

        function onLicenseStateChanged() {
            if (root.backend.licenseAllowed)
                return
            assignPopup.close()
            sampleDialog.close()
            slideDialog.close()
            hostPopup.close()
            hostInfoWindow.hide()
            slideManagerWindow.hide()
            timerWindow.hide()
            previewSelectWindow.hide()
            remoteWindow.hide()
        }
    }
}
