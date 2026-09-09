/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QHash>
#include <QString>
#include <QVariant>

class AppModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    struct Item
    {
        QString name;
        QString summary;
        QString version;
        QString architecture;
        QString identifier;
        QString category;
        QString actionText;
        QString actionIcon;
        QString icon;
        QString status;
        QString baseImage;
        QString created;
        QString integratedApps;
        QString description;
        QString integration;
        QString type;
        QString size;
        QString iconUrl;
        QString screenshot;
        QString screenshotCaption;
        QString accentColor {};
    };

    enum Role
    {
        NameRole = Qt::UserRole + 1,
        SummaryRole,
        VersionRole,
        ArchitectureRole,
        IdentifierRole,
        CategoryRole,
        ActionTextRole,
        ActionIconRole,
        IconRole,
        StatusRole,
        BaseImageRole,
        CreatedRole,
        IntegratedAppsRole,
        DescriptionRole,
        IntegrationRole,
        TypeRole,
        SizeRole,
        IconUrlRole,
        ScreenshotRole,
        ScreenshotCaptionRole,
        AccentColorRole
    };
    Q_ENUM(Role)

    explicit AppModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int count() const;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setItems(const QList<Item> &items);
    const QList<Item> &items() const;

signals:
    void countChanged();

private:
    QList<Item> m_items;
};
