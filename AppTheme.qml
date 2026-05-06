pragma Singleton

import QtQuick

QtObject {
    readonly property color primary: "#8b1e2d"
    readonly property color secondary: "#3a0f16"
    readonly property color accent: "#d1495b"
    readonly property color background: "#14090b"
    readonly property color surface: "#211014"
    readonly property color text: "#f5e9eb"
    readonly property color muted: "#a98b91"
    readonly property color border: "#4a1f27"
    readonly property color primaryHover: "#a32638"
    readonly property color accentHover: "#e15b6c"
    readonly property color danger: "#ff4d5e"
    readonly property color success: "#2f9e73"
    readonly property color warning: "#d69e2e"
    readonly property color inputBackground: "#1a0c0f"
    readonly property color inputBorder: "#5a2630"
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)

    readonly property color surfaceRaised: "#2a1519"
    readonly property color surfaceSoft: "#2f171d"
    readonly property color surfacePressed: "#180b0e"
    readonly property color tile: "#2a1318"
    readonly property color tileHover: "#351821"
    readonly property color tilePressed: "#1a0c0f"
    readonly property color overlay: Qt.rgba(0.02, 0.0, 0.01, 0.66)

    readonly property int outerMargin: 6
    readonly property int shellRadius: 14
    readonly property int panelRadius: 10
    readonly property int tileRadius: 8
    readonly property int controlRadius: 9
    readonly property int denseSpacing: 8
    readonly property int spacing: 12

    readonly property string fontFamily: "Segoe UI"

    function alpha(colorValue, opacity) {
        return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, opacity)
    }
}
