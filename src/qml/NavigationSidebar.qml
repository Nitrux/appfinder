/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Loader {
    id: control
    asynchronous: true
    active: (control.enabled && control.visible) || item
    Keys.enabled: false
    focus: false

    property int currentSection: 0
    property var groups: [
        {
            title: qsTr("Sources"),
            items: [
                { label: qsTr("Flathub"), icon: "get-hot-new-stuff", section: 0 },
                { label: qsTr("NX AppHub"), icon: "package", section: 1 }
            ]
        },
        {
            title: qsTr("Containers"),
            items: [
                { label: qsTr("Distrobox"), icon: "system-run", section: 2 }
            ]
        },
        {
            title: qsTr("Management"),
            items: [
                { label: qsTr("Updates"), icon: "view-refresh", section: 3 }
            ]
        }
    ]

    signal sectionSelected(int section)

    OpacityAnimator on opacity {
        from: 0
        to: 1
        duration: Maui.Style.units.longDuration
        running: control.status === Loader.Ready
    }

    sourceComponent: Item {
        anchors.fill: parent

        Pane {
            id: sideBarPane
            anchors.fill: parent
            padding: 0
            focus: false
            clip: true
            Maui.Theme.colorSet: Maui.Theme.Window
            Maui.Theme.inherit: false

            background: Rectangle {
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
            }

            contentItem: ColumnLayout {
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                ScrollView {
                    id: scrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    focus: false
                    padding: 0
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: scrollView.availableWidth
                        spacing: Maui.Style.space.medium

                        Repeater {
                            model: control.groups

                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Maui.Style.space.small

                                Maui.SectionHeader {
                                    Layout.fillWidth: true
                                    text1: modelData.title
                                    label1.font.weight: Font.Bold
                                    label1.font.pixelSize: 14
                                    label2.visible: false
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Maui.Style.space.small

                                    Repeater {
                                        model: modelData.items

                                        delegate: Maui.ListDelegate {
                                            id: sidebarDelegate
                                            required property var modelData
                                            Layout.fillWidth: true
                                            iconSize: Maui.Style.iconSizes.small
                                            iconVisible: true
                                            label: modelData.label
                                            iconName: modelData.icon
                                            isCurrentItem: modelData.section === control.currentSection

                                            Binding {
                                                target: sidebarDelegate.template.iconItem
                                                property: "color"
                                                value: sidebarDelegate.selected || sidebarDelegate.containsPress
                                                       ? (Maui.ColorUtils.brightnessForColor(sidebarDelegate.effectiveBackgroundColor) === Maui.ColorUtils.Light
                                                          ? "#333333"
                                                          : "#fafafa")
                                                       : sidebarDelegate.effectiveForegroundColor
                                                when: sidebarDelegate.template.iconItem !== null
                                            }

                                            onClicked: control.sectionSelected(modelData.section)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
