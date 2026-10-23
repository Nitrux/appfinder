/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import org.mauikit.controls as Maui

Item {
    id: control

    property string text: ""
    property bool busy: false
    property font textFont: Qt.application.font
    property color textColor: Maui.Theme.textColor
    readonly property real operationSpacing: Maui.Style.space.small

    implicitWidth: label.implicitWidth + (control.busy ? indicator.width + operationSpacing : 0)
    implicitHeight: Math.max(label.implicitHeight, indicator.height)

    Label {
        id: label
        width: implicitWidth
        height: implicitHeight
        x: Math.max(0, (control.width - label.implicitWidth
                        - (control.busy ? indicator.width + control.operationSpacing : 0)) / 2)
        y: (control.height - height) / 2
        text: control.text
        font: control.textFont
        color: control.textColor
    }

    ActionBusyIndicator {
        id: indicator
        x: label.x + label.width + control.operationSpacing
        y: (control.height - height) / 2
        running: control.busy
    }
}
