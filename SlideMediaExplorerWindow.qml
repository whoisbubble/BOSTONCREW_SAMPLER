pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: explorerWindow

    required property var backend
    property int slideIndex: -1
    property string slideFolderName: ""
    property var selectedIndices: []
    property int lastClickedIndex: -1
    property var mediaList: []

    property bool anchorMoveMode: false
    property bool isProcessing: false

    property real ownerX: 0
    property real ownerY: 0

    function openExplorer(idx, name, origX, origY) {
        slideIndex = idx
        slideFolderName = name
        selectedIndices = []
        lastClickedIndex = -1
        anchorMoveMode = false
        isProcessing = false
        if (origX !== undefined && origY !== undefined) {
            x = Math.max(40, origX + 30)
            y = Math.max(40, origY + 30)
        }
        refreshMediaList()
        show()
        raise()
        requestActivate()
    }

    function closeExplorer() {
        hide()
        slideIndex = -1
        slideFolderName = ""
        selectedIndices = []
        lastClickedIndex = -1
        anchorMoveMode = false
        isProcessing = false
        mediaList = []
    }

    function refreshMediaList() {
        if (slideIndex < 0 || !backend) {
            mediaList = []
            return
        }
        mediaList = backend.getSlideMediaPaths(slideIndex)
    }

    function isSelected(idx) {
        for (var i = 0; i < selectedIndices.length; ++i) {
            if (selectedIndices[i] === idx)
                return true
        }
        return false
    }

    function toggleSelect(idx) {
        var arr = selectedIndices.slice()
        var pos = -1
        for (var i = 0; i < arr.length; ++i) {
            if (arr[i] === idx) {
                pos = i
                break
            }
        }
        if (pos >= 0) {
            arr.splice(pos, 1)
        } else {
            arr.push(idx)
        }
        selectedIndices = arr
        lastClickedIndex = idx
    }

    function selectRange(fromIdx, toIdx) {
        var start = Math.min(fromIdx, toIdx)
        var end = Math.max(fromIdx, toIdx)
        var arr = selectedIndices.slice()
        for (var i = start; i <= end; ++i) {
            var found = false
            for (var j = 0; j < arr.length; ++j) {
                if (arr[j] === i) {
                    found = true
                    break
                }
            }
            if (!found)
                arr.push(i)
        }
        selectedIndices = arr
    }

    function selectAll() {
        var arr = []
        for (var i = 0; i < mediaList.length; ++i) {
            arr.push(i)
        }
        selectedIndices = arr
    }

    function clearSelection() {
        selectedIndices = []
        lastClickedIndex = -1
        anchorMoveMode = false
    }

    function handleTileClick(idx, mouse) {
        if (anchorMoveMode) {
            if (backend && slideIndex >= 0 && selectedIndices.length > 0) {
                isProcessing = true
                backend.moveLibrarySlideMediaBatch(slideIndex, selectedIndices, idx + 1)
                clearSelection()
                refreshMediaList()
                isProcessing = false
            }
            return
        }

        if (mouse.modifiers & Qt.ControlModifier) {
            toggleSelect(idx)
        } else if ((mouse.modifiers & Qt.ShiftModifier) && lastClickedIndex >= 0) {
            selectRange(lastClickedIndex, idx)
        } else {
            selectedIndices = [idx]
            lastClickedIndex = idx
        }
    }

    width: 760
    height: 640
    minimumWidth: 620
    minimumHeight: 440
    visible: false
    title: "BOSTONCREW SAMPLER / Проводник медиа"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    Connections {
        target: explorerWindow.backend
        function onLibrarySlidesChanged() {
            if (explorerWindow.slideIndex >= 0)
                explorerWindow.refreshMediaList()
        }
    }

    // Outer Shell Container
    Rectangle {
        id: shell
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
            spacing: 8

            // Custom Titlebar with Drag, Maximize & Close buttons
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: windowButtons.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: {
                        if (explorerWindow.visibility === Window.FullScreen)
                            explorerWindow.showNormal()
                        else
                            explorerWindow.showFullScreen()
                    }
                    onPressed: explorerWindow.startSystemMove()
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    AppIcon {
                        width: 18
                        height: 18
                        name: "folder"
                        lineColor: AppTheme.accent
                    }

                    Text {
                        text: "BOSTONCREW SAMPLER / Проводник медиа — " + explorerWindow.slideFolderName
                        color: AppTheme.text
                        font.family: AppTheme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                RowLayout {
                    id: windowButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    ChromeButton {
                        iconName: explorerWindow.visibility === Window.FullScreen ? "min" : "max"
                        tip: explorerWindow.visibility === Window.FullScreen ? "Оконный режим" : "Полноэкранный режим"
                        onClicked: {
                            if (explorerWindow.visibility === Window.FullScreen)
                                explorerWindow.showNormal()
                            else
                                explorerWindow.showFullScreen()
                        }
                    }

                    ChromeButton {
                        iconName: "close"
                        destructive: true
                        tip: "Закрыть окно"
                        onClicked: explorerWindow.closeExplorer()
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: AppTheme.border
            }

            // Action Toolbar with Wide "📌 Вставить после..." Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconButton {
                    side: 34
                    iconSize: 16
                    iconName: "plus"
                    tip: "Добавить новые медиафайлы (после выделенного или в конец)"
                    onClicked: {
                        if (explorerWindow.backend && explorerWindow.slideIndex >= 0) {
                            explorerWindow.isProcessing = true
                            var insertPos = -1
                            if (explorerWindow.selectedIndices.length > 0) {
                                var maxIdx = explorerWindow.selectedIndices[0]
                                for (var i = 1; i < explorerWindow.selectedIndices.length; ++i) {
                                    if (explorerWindow.selectedIndices[i] > maxIdx)
                                        maxIdx = explorerWindow.selectedIndices[i]
                                }
                                insertPos = maxIdx + 1
                            }
                            explorerWindow.backend.addMediaToLibrarySlideAt(explorerWindow.slideIndex, insertPos)
                            explorerWindow.clearSelection()
                            explorerWindow.refreshMediaList()
                            explorerWindow.isProcessing = false
                        }
                    }
                }

                IconButton {
                    side: 34
                    iconSize: 16
                    iconName: "check"
                    tip: "Выделить все файлы (Ctrl+A)"
                    onClicked: explorerWindow.selectAll()
                }

                IconButton {
                    side: 34
                    iconSize: 16
                    iconName: "close"
                    enabled: explorerWindow.selectedIndices.length > 0
                    tip: "Снять выделение"
                    onClicked: explorerWindow.clearSelection()
                }

                Rectangle {
                    width: 1
                    height: 24
                    color: AppTheme.border
                }

                // Wide "📌 Вставить после..." Button
                TextButton {
                    Layout.preferredWidth: 175
                    text: explorerWindow.anchorMoveMode ? "Отмена вставки" : "📌 Вставить после..."
                    accentFill: explorerWindow.anchorMoveMode
                    enabled: explorerWindow.selectedIndices.length > 0
                    tip: "Нажмите, прокрутите к нужному слайду и кликните по нему — выделенные вставятся сразу за ним!"
                    onClicked: explorerWindow.anchorMoveMode = !explorerWindow.anchorMoveMode
                }

                IconButton {
                    side: 34
                    iconSize: 16
                    iconName: "arrow-up"
                    enabled: explorerWindow.selectedIndices.length > 0
                    tip: "Переместить выделенные медиа в начало списка"
                    onClicked: {
                        if (explorerWindow.backend && explorerWindow.slideIndex >= 0) {
                            explorerWindow.isProcessing = true
                            explorerWindow.backend.moveLibrarySlideMediaBatch(explorerWindow.slideIndex, explorerWindow.selectedIndices, 0)
                            explorerWindow.clearSelection()
                            explorerWindow.refreshMediaList()
                            explorerWindow.isProcessing = false
                        }
                    }
                }

                IconButton {
                    side: 34
                    iconSize: 16
                    iconName: "arrow-down"
                    enabled: explorerWindow.selectedIndices.length > 0
                    tip: "Переместить выделенные медиа в конец списка"
                    onClicked: {
                        if (explorerWindow.backend && explorerWindow.slideIndex >= 0) {
                            explorerWindow.isProcessing = true
                            explorerWindow.backend.moveLibrarySlideMediaBatch(explorerWindow.slideIndex, explorerWindow.selectedIndices, explorerWindow.mediaList.length)
                            explorerWindow.clearSelection()
                            explorerWindow.refreshMediaList()
                            explorerWindow.isProcessing = false
                        }
                    }
                }

                IconButton {
                    side: 34
                    iconSize: 16
                    iconName: "trash"
                    dangerFill: true
                    enabled: explorerWindow.selectedIndices.length > 0
                    tip: "Удалить выделенные файлы (" + explorerWindow.selectedIndices.length + ")"
                    onClicked: {
                        if (explorerWindow.backend && explorerWindow.slideIndex >= 0) {
                            explorerWindow.isProcessing = true
                            explorerWindow.backend.deleteLibrarySlideMediaBatch(explorerWindow.slideIndex, explorerWindow.selectedIndices)
                            explorerWindow.clearSelection()
                            explorerWindow.refreshMediaList()
                            explorerWindow.isProcessing = false
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Busy Indicator & Selection Info Badge
                RowLayout {
                    spacing: 6

                    BusyIndicator {
                        running: explorerWindow.isProcessing
                        visible: explorerWindow.isProcessing
                        implicitWidth: 22
                        implicitHeight: 22
                    }

                    Rectangle {
                        height: 28
                        implicitWidth: infoText.implicitWidth + 20
                        radius: 6
                        color: AppTheme.surfaceSoft
                        border.color: AppTheme.border
                        border.width: 1

                        Text {
                            id: infoText
                            anchors.centerIn: parent
                            text: "Всего: " + explorerWindow.mediaList.length + " | Выбрано: " + explorerWindow.selectedIndices.length
                            color: AppTheme.text
                            font.family: AppTheme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // Info & Status Banner
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 6
                color: explorerWindow.isProcessing
                    ? AppTheme.tilePressed
                    : (explorerWindow.anchorMoveMode ? AppTheme.primary : AppTheme.surfaceSoft)
                border.color: explorerWindow.anchorMoveMode || explorerWindow.isProcessing ? AppTheme.accent : AppTheme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    AppIcon {
                        width: 14
                        height: 14
                        name: explorerWindow.isProcessing ? "timer" : (explorerWindow.anchorMoveMode ? "menu" : "help")
                        lineColor: explorerWindow.anchorMoveMode ? AppTheme.text : AppTheme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: explorerWindow.isProcessing
                            ? "⏳ Обработка и сохранение изменений..."
                            : (explorerWindow.anchorMoveMode
                                ? ("📌 Режим вставки: Прокрутите колесиком и КЛИКНИТЕ по слайду, ПОСЛЕ которого вставить " + explorerWindow.selectedIndices.length + " выделенных файлов!")
                                : "Клик — выбор | Ctrl+Клик — добавить/убрать | Shift+Клик — диапазон | 📌 Вставить после — точный перенос | ПКМ — настройки")
                        color: AppTheme.text
                        font.family: AppTheme.fontFamily
                        font.pixelSize: 11
                        font.weight: (explorerWindow.anchorMoveMode || explorerWindow.isProcessing) ? Font.Bold : Font.Normal
                        elide: Text.ElideRight
                    }
                }
            }

            // Main Media Grid View
            ScrollView {
                id: mediaScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                WheelHandler {
                    target: gridView
                    onWheel: (event) => {
                        gridView.flick(0, event.angleDelta.y * 14)
                    }
                }

                GridView {
                    id: gridView
                    width: mediaScrollView.width
                    height: mediaScrollView.height
                    cellWidth: 180
                    cellHeight: 135
                    boundsBehavior: Flickable.StopAtBounds
                    model: explorerWindow.mediaList

                    delegate: Rectangle {
                        id: tile

                        required property int index
                        required property string modelData

                        readonly property bool isSelected: explorerWindow.isSelected(tile.index)
                        readonly property bool isVideo: explorerWindow.backend ? explorerWindow.backend.isVideoPath(tile.modelData) : false
                        readonly property bool repeats: explorerWindow.backend ? explorerWindow.backend.librarySlideMediaRepeats(explorerWindow.slideIndex, tile.index) : false
                        readonly property bool hasCue: explorerWindow.backend ? explorerWindow.backend.librarySlideMediaHasCue(explorerWindow.slideIndex, tile.index) : false
                        readonly property string cueName: explorerWindow.backend ? explorerWindow.backend.librarySlideMediaCueName(explorerWindow.slideIndex, tile.index) : ""
                        readonly property bool hasBackground: explorerWindow.backend ? explorerWindow.backend.librarySlideMediaHasBackground(explorerWindow.slideIndex, tile.index) : false
                        readonly property bool backgroundRepeats: explorerWindow.backend ? explorerWindow.backend.librarySlideMediaBackgroundRepeats(explorerWindow.slideIndex, tile.index) : false
                        readonly property bool available: explorerWindow.backend ? explorerWindow.backend.slideMediaAvailable(explorerWindow.slideIndex, tile.index) : true
                        readonly property bool isAnchorHover: explorerWindow.anchorMoveMode && tileMouse.containsMouse

                        readonly property string fileName: {
                            var p = tile.modelData.replace(/\\/g, "/")
                            var parts = p.split("/")
                            return parts.length > 0 ? parts[parts.length - 1] : p
                        }

                        width: 170
                        height: 125
                        radius: 8
                        color: tile.isAnchorHover
                            ? AppTheme.primary
                            : (tile.isSelected ? AppTheme.surfacePressed : (tileMouse.containsMouse ? AppTheme.tileHover : AppTheme.inputBackground))
                        border.width: (tile.isSelected || tile.isAnchorHover) ? 2 : 1
                        border.color: tile.isAnchorHover
                            ? AppTheme.success
                            : (tile.isSelected ? AppTheme.accent : (tileMouse.containsMouse ? AppTheme.accent : (tile.repeats ? AppTheme.success : (tile.hasCue ? AppTheme.accent : AppTheme.border))))
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            // Media Thumbnail Container
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: AppTheme.surfaceSoft
                                border.color: AppTheme.border
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: explorerWindow.backend ? explorerWindow.backend.thumbnailUrl(tile.modelData) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    visible: status === Image.Ready
                                }

                                AppIcon {
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 28
                                    name: tile.isVideo ? "play" : "image"
                                    lineColor: AppTheme.muted
                                }

                                // Index badge
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 4
                                    width: 26
                                    height: 18
                                    radius: 4
                                    color: "#D0000000"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "#" + (tile.index + 1)
                                        color: AppTheme.text
                                        font.family: AppTheme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }

                                // Selection Checkmark Badge
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 4
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: AppTheme.accent
                                    visible: tile.isSelected

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: AppTheme.text
                                        font.family: AppTheme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                // Anchor Insert Hover Overlay
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#E010B981"
                                    visible: tile.isAnchorHover

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "📌 Вставить сюда"
                                            color: "#ffffff"
                                            font.family: AppTheme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "после #" + (tile.index + 1)
                                            color: "#ffffff"
                                            font.family: AppTheme.fontFamily
                                            font.pixelSize: 9
                                        }
                                    }
                                }
                            }

                            // Filename Label
                            Text {
                                Layout.fillWidth: true
                                text: tile.fileName + (tile.hasBackground ? " [+фон]" : "")
                                color: tile.isSelected ? AppTheme.accent : AppTheme.text
                                font.family: AppTheme.fontFamily
                                font.pixelSize: 10
                                font.weight: tile.isSelected ? Font.Bold : Font.Normal
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Exact Media Menu Popup matching SlideLibrary strip
                        Menu {
                            id: mediaMenu

                            MenuItem {
                                text: "Сместить назад"
                                enabled: tile.available && tile.index > 0
                                onTriggered: {
                                    explorerWindow.backend.moveLibrarySlideMedia(explorerWindow.slideIndex, tile.index, tile.index - 1)
                                    explorerWindow.clearSelection()
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuItem {
                                text: "Сместить вперёд"
                                enabled: tile.available && tile.index + 1 < explorerWindow.mediaList.length
                                onTriggered: {
                                    explorerWindow.backend.moveLibrarySlideMedia(explorerWindow.slideIndex, tile.index, tile.index + 1)
                                    explorerWindow.clearSelection()
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuItem {
                                text: tile.repeats ? "Выключить цикл" : "Цикл"
                                enabled: tile.available && tile.isVideo
                                onTriggered: {
                                    explorerWindow.backend.setLibrarySlideMediaRepeats(explorerWindow.slideIndex, tile.index, !tile.repeats)
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuItem {
                                text: tile.hasCue ? "Изменить звук" : "Добавить звук"
                                enabled: tile.available
                                onTriggered: {
                                    explorerWindow.backend.addSampleToLibrarySlideMedia(explorerWindow.slideIndex, tile.index)
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuItem {
                                text: "Убрать звук"
                                enabled: tile.available && tile.hasCue
                                visible: tile.hasCue
                                onTriggered: {
                                    explorerWindow.backend.clearSampleFromLibrarySlideMedia(explorerWindow.slideIndex, tile.index)
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuItem {
                                text: "Добавить фон"
                                enabled: tile.available
                                onTriggered: {
                                    explorerWindow.backend.setLibrarySlideMediaBackground(explorerWindow.slideIndex, tile.index)
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuItem {
                                text: "Убрать фон"
                                visible: tile.hasBackground
                                enabled: tile.available
                                onTriggered: {
                                    explorerWindow.backend.clearLibrarySlideMediaBackground(explorerWindow.slideIndex, tile.index)
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuItem {
                                text: tile.backgroundRepeats ? "Выключить цикл фона" : "Цикл фона"
                                visible: tile.hasBackground
                                enabled: tile.available
                                onTriggered: {
                                    explorerWindow.backend.setLibrarySlideMediaBackgroundRepeats(explorerWindow.slideIndex, tile.index, !tile.backgroundRepeats)
                                    explorerWindow.refreshMediaList()
                                }
                            }
                            MenuSeparator {}
                            MenuItem {
                                text: "Удалить"
                                enabled: tile.available
                                onTriggered: {
                                    explorerWindow.backend.deleteLibrarySlideMedia(explorerWindow.slideIndex, tile.index)
                                    explorerWindow.clearSelection()
                                    explorerWindow.refreshMediaList()
                                }
                            }
                        }

                        // Mouse Area for Left Click / Anchor Insert / Context Menu
                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    mediaMenu.popup()
                                } else {
                                    explorerWindow.handleTileClick(tile.index, mouse)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Window Edge Resize Handles for border dragging
        WindowResizeHandle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 16
            height: 16
            edge: Qt.RightEdge | Qt.BottomEdge
        }

        WindowResizeHandle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 8
            edge: Qt.RightEdge
        }

        WindowResizeHandle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 8
            edge: Qt.BottomEdge
        }
    }
}
