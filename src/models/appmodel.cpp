/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include "appmodel.h"

AppModel::AppModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int AppModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;

    return m_items.count();
}

int AppModel::count() const
{
    return m_items.count();
}

QVariant AppModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.count())
        return {};

    const auto &item = m_items.at(index.row());

    switch (role) {
    case NameRole:
        return item.name;
    case SummaryRole:
        return item.summary;
    case VersionRole:
        return item.version;
    case ArchitectureRole:
        return item.architecture;
    case IdentifierRole:
        return item.identifier;
    case CategoryRole:
        return item.category;
    case ActionTextRole:
        return item.actionText;
    case ActionIconRole:
        return item.actionIcon;
    case IconRole:
        return item.icon;
    case StatusRole:
        return item.status;
    case BaseImageRole:
        return item.baseImage;
    case CreatedRole:
        return item.created;
    case IntegratedAppsRole:
        return item.integratedApps;
    case DescriptionRole:
        return item.description;
    case IntegrationRole:
        return item.integration;
    case TypeRole:
        return item.type;
    case SizeRole:
        return item.size;
    case IconUrlRole:
        return item.iconUrl;
    case ScreenshotRole:
        return item.screenshot;
    case ScreenshotCaptionRole:
        return item.screenshotCaption;
    case AccentColorRole:
        return item.accentColor;
    default:
        return {};
    }
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {SummaryRole, "summary"},
        {VersionRole, "version"},
        {ArchitectureRole, "architecture"},
        {IdentifierRole, "identifier"},
        {CategoryRole, "category"},
        {ActionTextRole, "actionText"},
        {ActionIconRole, "actionIcon"},
        {IconRole, "icon"},
        {StatusRole, "status"},
        {BaseImageRole, "baseImage"},
        {CreatedRole, "created"},
        {IntegratedAppsRole, "integratedApps"},
        {DescriptionRole, "description"},
        {IntegrationRole, "integration"},
        {TypeRole, "type"},
        {SizeRole, "size"},
        {IconUrlRole, "iconUrl"},
        {ScreenshotRole, "screenshot"},
        {ScreenshotCaptionRole, "screenshotCaption"},
        {AccentColorRole, "accentColor"},
    };
}

void AppModel::setItems(const QList<Item> &items)
{
    beginResetModel();
    m_items = items;
    endResetModel();
    emit countChanged();
}

const QList<AppModel::Item> &AppModel::items() const
{
    return m_items;
}
