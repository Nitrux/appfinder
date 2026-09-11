/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#pragma once

#include <QList>
#include <QString>
#include <QVariantMap>

#include "../models/appmodel.h"

class UserBundleStore final
{
public:
    explicit UserBundleStore(const QString &rootPath = {});

    QString rootPath() const;
    QString projectPath(const QString &projectId) const;
    QString outputPath(const QString &projectId, const QVariantMap &recipe) const;
    QString hostPackageArchitecture() const;

    bool ensureRoot(QString *error = nullptr) const;
    bool isValidProjectId(const QString &projectId) const;
    bool projectExists(const QString &projectId) const;
    QList<AppModel::Item> projects() const;

    QVariantMap load(const QString &projectId) const;
    bool create(const QString &projectId,
                const QVariantMap &recipe,
                const QVariantMap &metadata,
                QString *error = nullptr) const;
    bool save(const QString &projectId,
              const QVariantMap &recipe,
              const QVariantMap &metadata,
              QString *error = nullptr) const;
    QString preflight(const QVariantMap &recipe) const;

private:
    QString checkedProjectPath(const QString &projectId, bool mustExist, QString *error = nullptr) const;

    QString m_rootPath;
};
