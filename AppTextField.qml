import QtQuick
import QtQuick.Controls

TextField {
    id: field

    color: AppTheme.text
    placeholderTextColor: AppTheme.muted
    selectionColor: AppTheme.primary
    selectedTextColor: AppTheme.text
    font.family: AppTheme.fontFamily
    font.pixelSize: 13
    leftPadding: 12
    rightPadding: 12

    background: Rectangle {
        radius: AppTheme.controlRadius
        color: AppTheme.inputBackground
        border.color: field.activeFocus ? AppTheme.accent : AppTheme.inputBorder
        border.width: 1
    }
}
