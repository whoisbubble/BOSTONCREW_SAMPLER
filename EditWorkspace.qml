pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: workspace

    required property var backend

    signal editSampleRequested(int index, string sampleName, real volume, bool stopSounds, var sampleColor)
    signal editSlideRequested(int index, string folderName, string slideType)

    readonly property bool compact: width < 860

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        visible: !workspace.compact

        SampleManager {
            Layout.fillWidth: true
            Layout.fillHeight: true
            backend: workspace.backend
            onEditSampleRequested: function(index, sampleName, volume, stopSounds, sampleColor) {
                workspace.editSampleRequested(index, sampleName, volume, stopSounds, sampleColor)
            }
        }

        SlideLibrary {
            Layout.preferredWidth: 390
            Layout.fillHeight: true
            backend: workspace.backend
            onEditSlideRequested: function(index, folderName, slideType) {
                workspace.editSlideRequested(index, folderName, slideType)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        visible: workspace.compact

        TabBar {
            id: tabs
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            background: Rectangle {
                color: AppTheme.surfacePressed
                radius: AppTheme.controlRadius
                border.color: AppTheme.border
            }

            TabButton {
                text: "Samples"
                font.family: AppTheme.fontFamily
                font.pixelSize: 12
            }

            TabButton {
                text: "BOSTONCREW SAMPLER / Slides"
                font.family: AppTheme.fontFamily
                font.pixelSize: 12
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            SampleManager {
                backend: workspace.backend
                onEditSampleRequested: function(index, sampleName, volume, stopSounds, sampleColor) {
                    workspace.editSampleRequested(index, sampleName, volume, stopSounds, sampleColor)
                }
            }

            SlideLibrary {
                backend: workspace.backend
                onEditSlideRequested: function(index, folderName, slideType) {
                    workspace.editSlideRequested(index, folderName, slideType)
                }
            }
        }
    }
}
