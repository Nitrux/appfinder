/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import org.mauikit.controls as Maui

Item {
    id: control

    property list<Action> actions: []
    property int rows: 2
    property bool draggable: true
    property Item dragTarget: parent

    readonly property int visibleActionCount: {
        let count = 0
        for (const action of actions) {
            if (action && (typeof action.actionVisible === "undefined" || action.actionVisible))
                ++count
        }
        return count
    }

    readonly property int actionColumns: Math.max(1, Math.ceil(visibleActionCount / Math.max(1, rows)))

    implicitWidth: pane.implicitWidth
    implicitHeight: pane.implicitHeight

    Pane {
        id: pane

        visible: control.actions.length > 0
        x: control.dragTarget ? control.dragTarget.width - width - Maui.Style.space.big : 0
        y: control.dragTarget ? control.dragTarget.height - height - Maui.Style.space.big : 0

        Maui.Theme.colorSet: Maui.Theme.Complementary
        Maui.Theme.inherit: false

        background: Rectangle {
            radius: Maui.Style.radiusV
            color: Maui.Theme.alternateBackgroundColor
            border.color: Maui.Theme.alternateBackgroundColor
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "#000000"
            }
        }

        ScaleAnimator on scale {
            from: 0
            to: 1
            duration: Maui.Style.units.longDuration
            running: pane.visible
            easing.type: Easing.OutInQuad
        }

        OpacityAnimator on opacity {
            from: 0
            to: 1
            duration: Maui.Style.units.longDuration
            running: pane.visible
        }

        contentItem: Row {
            spacing: Maui.Style.defaultSpacing

            Item {
                id: dragHandle

                width: Maui.Style.space.big
                height: actionsGrid.implicitHeight

                Row {
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: 2

                        Column {
                            spacing: 3

                            Repeater {
                                model: 4

                                Rectangle {
                                    width: 2
                                    height: width
                                    radius: width / 2
                                    color: Maui.Theme.textColor
                                    opacity: dragHandler.active ? 0.9 : 0.55
                                }
                            }
                        }
                    }
                }

                DragHandler {
                    id: dragHandler

                    enabled: control.draggable
                    target: pane
                    xAxis.maximum: control.dragTarget ? control.dragTarget.width - pane.width : 0
                    xAxis.minimum: 0
                    yAxis.enabled: false

                    onActiveChanged: {
                        if (!active && control.dragTarget) {
                            const position = centroid.velocity.x
                            pane.x = Qt.binding(function() {
                                return position < 0 ? Maui.Style.space.big : control.dragTarget.width - pane.width - Maui.Style.space.big
                            })
                            pane.y = Qt.binding(function() {
                                return control.dragTarget.height - pane.height - Maui.Style.space.big
                            })
                        }
                    }
                }

                HoverHandler {
                    enabled: control.draggable
                    cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                }
            }

            Grid {
                id: actionsGrid

                columns: control.actionColumns
                spacing: Maui.Style.space.tiny

                Repeater {
                    model: control.actions

                    ToolButton {
                        id: actionButton
                        visible: modelData && (typeof modelData.actionVisible === "undefined" || modelData.actionVisible)

                        readonly property bool destructive: modelData && modelData.Maui.Controls.status === Maui.Controls.Negative

                        Maui.Theme.colorSet: Maui.Theme.Complementary
                        Maui.Controls.status: modelData && modelData.Maui.Controls.status ? modelData.Maui.Controls.status : Maui.Controls.Normal

                        action: modelData
                        display: ToolButton.IconOnly
                        autoExclusive: modelData && modelData.checkable
                        flat: false
                        icon.color: destructive ? "#fafafa" : actionButton.color

                        background: Rectangle {
                            radius: Maui.Style.radiusV
                            color: actionButton.destructive
                                ? (actionButton.pressed || actionButton.down || actionButton.checked
                                   ? Qt.darker(Maui.Theme.negativeBackgroundColor, 1.12)
                                   : (actionButton.hovered
                                      ? Qt.lighter(Maui.Theme.negativeBackgroundColor, 1.05)
                                      : Maui.Theme.negativeBackgroundColor))
                                : (actionButton.pressed || actionButton.down || actionButton.checked
                                   ? actionButton.Maui.Theme.highlightColor
                                   : (actionButton.highlighted || actionButton.hovered
                                      ? actionButton.Maui.Theme.hoverColor
                                      : actionButton.Maui.Theme.backgroundColor))

                            function statusBorderColor() {
                                switch (actionButton.Maui.Controls.status) {
                                case Maui.Controls.Positive:
                                    return actionButton.Maui.Theme.positiveBackgroundColor
                                case Maui.Controls.Negative:
                                    return actionButton.Maui.Theme.negativeBackgroundColor
                                case Maui.Controls.Neutral:
                                    return actionButton.Maui.Theme.neutralBackgroundColor
                                case Maui.Controls.Normal:
                                default:
                                    return "transparent"
                                }
                            }

                            border.color: actionButton.destructive
                                ? "transparent"
                                : (actionButton.Maui.Controls.status ? statusBorderColor() : "transparent")
                        }
                    }
                }
            }
        }
    }
}
