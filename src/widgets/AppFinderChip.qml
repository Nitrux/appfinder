import QtQuick
import QtQuick.Controls

import org.mauikit.controls as Maui

Maui.Chip {
    id: control

    Maui.Theme.colorSet: Maui.Theme.View

    hoverEnabled: false
    focusPolicy: Qt.NoFocus
    opacity: 1
    property real textOpacity: 0.6
    padding: Maui.Style.space.small
    color: "black"
    font.family: "Monospace"
    font.pointSize: Maui.Style.fontSizes.tiny
    implicitWidth: chipValue.implicitWidth + padding * 2
    implicitHeight: chipValue.implicitHeight + padding * 2

    background: Rectangle {
        color: control.color
        opacity: 0.5
        radius: Maui.Style.radiusV
    }

    contentItem: Label {
        id: chipValue
        text: control.text
        font: control.font
        opacity: control.textOpacity
        color: Maui.Theme.textColor
        horizontalAlignment: Text.AlignLeft
        elide: Text.ElideRight
    }
}
