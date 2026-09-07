/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
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
        model: control.sourceModel
        holder.visible: count === 0
        holder.title: control.emptyTitle
        holder.body: control.emptyBody

        delegate: Maui.ListBrowserDelegate {
            width: ListView.view.width
            height: Maui.Style.rowHeight * 1.35

            Maui.ListItemTemplate {
                anchors.fill: parent
                anchors.rightMargin: actionButton.visible ? actionButton.width + Maui.Style.space.big : 0
                iconSource: model.icon
                iconSizeHint: Maui.Style.iconSizes.medium
                label1.text: model.name
                label2.text: model.summary.length > 0 ? model.summary : model.identifier
                label2.elide: Text.ElideRight
            }

            Maui.ToolButton {
                id: actionButton
                visible: model.actionText.length > 0
                anchors.right: parent.right
                anchors.rightMargin: Maui.Style.contentMargins
                anchors.verticalCenter: parent.verticalCenter
                icon.name: model.actionIcon
                ToolTip.visible: hovered
                ToolTip.text: model.actionText

                onClicked: control.actionHandler(model.identifier, model.actionText)
            }
        }
    }
}
