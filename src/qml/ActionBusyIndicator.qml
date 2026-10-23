/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import org.mauikit.controls as Maui

Canvas {
    id: control

    property bool running: false
    implicitWidth: running ? Maui.Style.units.gridUnit : 0
    implicitHeight: implicitWidth
    width: implicitWidth
    height: implicitHeight
    visible: running
    property real arcStart: -Math.PI / 2
    property real arcSpan: Math.PI * 0.35

    onPaint: {
        if (!control.running || width <= 0 || height <= 0)
            return

        const context = getContext("2d")
        const center = width / 2
        const lineWidth = Math.max(1.5, width / 12)
        const outlineWidth = lineWidth + 2.5
        const radius = center - outlineWidth / 2

        context.reset()
        context.lineCap = "round"
        context.beginPath()
        context.lineWidth = outlineWidth
        context.strokeStyle = Qt.alpha(Maui.Theme.backgroundColor, 0.30)
        context.arc(center, center, radius, control.arcStart, control.arcStart + control.arcSpan)
        context.stroke()

        context.beginPath()
        context.lineWidth = lineWidth
        context.strokeStyle = Maui.Theme.textColor
        context.arc(center, center, radius, control.arcStart, control.arcStart + control.arcSpan)
        context.stroke()
    }

    Connections {
        target: control
        function onArcStartChanged() { control.requestPaint() }
        function onArcSpanChanged() { control.requestPaint() }
    }

    NumberAnimation on arcStart {
        from: -Math.PI / 2
        to: Math.PI * 3 / 2
        duration: 900
        loops: Animation.Infinite
        running: control.running
    }

    SequentialAnimation on arcSpan {
        loops: Animation.Infinite
        running: control.running

        NumberAnimation {
            from: Math.PI * 0.35
            to: Math.PI * 1.75
            duration: 520
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            from: Math.PI * 1.75
            to: Math.PI * 0.35
            duration: 420
            easing.type: Easing.InOutCubic
        }
    }
}
