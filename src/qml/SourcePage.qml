/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.Page {
    id: control

    property var sourceModel
    property string emptyTitle
    property string emptyBody
    property var actionHandler

    background: null;
    headBar.visible: false

    Maui.ListBrowser {
        id: browser
        anchors.fill: parent
        padding: Maui.Style.contentMargins
        spacing: Maui.Style.space.small
        model: control.sourceModel
        holder.visible: count === 0
        holder.title: control.emptyTitle
        holder.body: control.emptyBody

        delegate: Maui.ListBrowserDelegate {
            width: ListView.view.width
            height: Maui.Style.rowHeight * 1.35

            Maui.ListItemTemplate {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.rightMargin: actionButton.visible ? Maui.Style.space.big : 0
                iconSource: model.icon
                iconSizeHint: Maui.Style.iconSizes.medium
                label1.text: model.name
                label2.text: model.summary.length > 0 ? model.summary : model.identifier
                label2.elide: Text.ElideRight
            }

            ToolButton {
                id: actionButton
                visible: model.actionText.length > 0
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth
                Layout.rightMargin: Maui.Style.contentMargins
                icon.name: model.actionIcon
                ToolTip.visible: hovered
                ToolTip.text: model.actionText

                onClicked: control.actionHandler(model.identifier, model.actionText)
            }
        }
    }
}
