pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: view

    required property var backend
    property bool timerRunning: false

    signal assignQuickSlotRequested(int index)
    signal editSampleRequested(int index, string sampleName, real volume, bool stopSounds, var sampleColor)
    signal editSlideRequested(int index, string folderName, string slideType)
    signal timerRequested()
    signal managerRequested()
    signal previewRequested()

    readonly property int firstColumnWidth: 276
    readonly property int sideMargin: 15
    readonly property int topMargin: 5
    readonly property int bottomMargin: 15
    readonly property int topRowHeight: Math.min(220, Math.max(140, height - 88))
    readonly property int samplesY: topRowHeight + 15

    QuickSlotsPanel {
        id: quickPanel
        x: view.sideMargin
        y: view.topMargin
        width: view.firstColumnWidth - view.sideMargin - 10
        height: view.topRowHeight - view.topMargin
        backend: view.backend
        timerRunning: view.timerRunning
        onAssignQuickSlotRequested: function(index) { view.assignQuickSlotRequested(index) }
        onTimerRequested: view.timerRequested()
        onManagerRequested: view.managerRequested()
    }

    StagePanel {
        id: previewPanel
        x: view.firstColumnWidth + 5
        y: view.topMargin
        width: Math.max(180, view.width - view.firstColumnWidth - 20)
        height: view.topRowHeight - view.topMargin
        backend: view.backend
        onPreviewRequested: view.previewRequested()
    }

    SamplesConsole {
        id: samplesPanel
        x: view.sideMargin
        y: view.samplesY
        width: Math.max(260, view.width - view.sideMargin * 2)
        height: Math.max(58, view.height - view.samplesY - view.bottomMargin)
        backend: view.backend
        onEditSampleRequested: function(index, sampleName, volume, stopSounds, sampleColor) {
            view.editSampleRequested(index, sampleName, volume, stopSounds, sampleColor)
        }
        onEditSlideRequested: function(index, folderName, slideType) {
            view.editSlideRequested(index, folderName, slideType)
        }
    }
}
