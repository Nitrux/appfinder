/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#pragma once

#include <QObject>
#include <QByteArray>
#include <QHash>
#include <QList>
#include <QProcess>
#include <QSet>
#include <QString>
#include <QStringList>

#include "../models/appmodel.h"

class QNetworkAccessManager;
class QNetworkReply;

class AppHubBackend final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(AppModel *flathubModel READ flathubModel CONSTANT)
    Q_PROPERTY(AppModel *flathubUpdatesModel READ flathubUpdatesModel CONSTANT)
    Q_PROPERTY(AppModel *flatpakAddonsModel READ flatpakAddonsModel CONSTANT)
    Q_PROPERTY(AppModel *flathubFeaturedModel READ flathubFeaturedModel CONSTANT)
    Q_PROPERTY(AppModel *flathubCollectionModel READ flathubCollectionModel CONSTANT)
    Q_PROPERTY(QString flatpakSortMode READ flatpakSortMode WRITE setFlatpakSortMode NOTIFY flatpakSortModeChanged)
    Q_PROPERTY(QString flatpakUpdateIdentifier READ flatpakUpdateIdentifier NOTIFY flatpakUpdateStateChanged)
    Q_PROPERTY(int flatpakUpdateProgress READ flatpakUpdateProgress NOTIFY flatpakUpdateStateChanged)
    Q_PROPERTY(AppModel *appHubModel READ appHubModel CONSTANT)
    Q_PROPERTY(QStringList appHubCategories READ appHubCategories NOTIFY appHubCategoriesChanged)
    Q_PROPERTY(QString appHubCategory READ appHubCategory WRITE setAppHubCategory NOTIFY appHubCategoryChanged)
    Q_PROPERTY(bool appHubInstalledOnly READ appHubInstalledOnly WRITE setAppHubInstalledOnly NOTIFY appHubInstalledOnlyChanged)
    Q_PROPERTY(AppModel *distroboxModel READ distroboxModel CONSTANT)
    Q_PROPERTY(int flathubCollection READ flathubCollection WRITE setFlathubCollection NOTIFY flathubCollectionChanged)
    Q_PROPERTY(bool flathubCollectionLoading READ flathubCollectionLoading NOTIFY flathubCollectionLoadingChanged)
    Q_PROPERTY(bool flathubCollectionHasMore READ flathubCollectionHasMore NOTIFY flathubCollectionHasMoreChanged)
    Q_PROPERTY(int flathubCategoryRevision READ flathubCategoryRevision NOTIFY flathubCategoryRevisionChanged)
    Q_PROPERTY(int currentSection READ currentSection WRITE setCurrentSection NOTIFY currentSectionChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString operationLog READ operationLog NOTIFY operationLogChanged)

public:
    enum Section
    {
        Flathub = 0,
        AppHub = 1,
        Distrobox = 2
    };
    Q_ENUM(Section)

    enum FlathubCollection
    {
        TrendingCollection = 0,
        PopularCollection,
        RecentlyAddedCollection,
        RecentlyUpdatedCollection
    };
    Q_ENUM(FlathubCollection)

    explicit AppHubBackend(QObject *parent = nullptr);

    AppModel *flathubModel();
    AppModel *flathubUpdatesModel();
    AppModel *flatpakAddonsModel();
    AppModel *flathubFeaturedModel();
    AppModel *flathubCollectionModel();
    AppModel *appHubModel();
    AppModel *distroboxModel();

    int flathubCollection() const;
    void setFlathubCollection(int collection);
    bool flathubCollectionLoading() const;
    bool flathubCollectionHasMore() const;
    int flathubCategoryRevision() const;
    QString flatpakSortMode() const;
    void setFlatpakSortMode(const QString &mode);
    QString flatpakUpdateIdentifier() const;
    int flatpakUpdateProgress() const;

    QStringList appHubCategories() const;
    QString appHubCategory() const;
    void setAppHubCategory(const QString &category);
    bool appHubInstalledOnly() const;
    void setAppHubInstalledOnly(bool installedOnly);

    int currentSection() const;
    void setCurrentSection(int section);

    bool busy() const;
    QString statusMessage() const;
    QString operationLog() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void loadMoreFlathubCollection();
    Q_INVOKABLE AppModel *flathubCategoryModel(const QString &category) const;
    Q_INVOKABLE bool flathubCategoryLoading(const QString &category) const;
    Q_INVOKABLE bool flathubCategoryHasMore(const QString &category) const;
    Q_INVOKABLE void loadMoreFlathubCategory(const QString &category);
    Q_INVOKABLE void refreshAppHubRepository();
    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void installFlatpak(const QString &identifier);
    Q_INVOKABLE void updateFlatpak(const QString &identifier);
    Q_INVOKABLE void removeFlatpak(const QString &identifier);
    Q_INVOKABLE void loadFlatpakAddons(const QString &identifier);
    Q_INVOKABLE void installFlatpakAddon(const QString &ref);
    Q_INVOKABLE void removeFlatpakAddon(const QString &ref);
    Q_INVOKABLE void appHubAction(const QString &identifier);
    Q_INVOKABLE void rebuildAppHub(const QString &identifier);
    Q_INVOKABLE void enterDistrobox(const QString &name);
    Q_INVOKABLE void createDistrobox(const QString &name, const QString &image, const QString &home = {});
    Q_INVOKABLE void startDistrobox(const QString &name);
    Q_INVOKABLE void stopDistrobox(const QString &name);
    Q_INVOKABLE void cloneDistrobox(const QString &source, const QString &name);
    Q_INVOKABLE void removeDistrobox(const QString &name);
    Q_INVOKABLE bool isFlatpakInstalled(const QString &identifier) const;

signals:
    void currentSectionChanged();
    void flathubCollectionChanged();
    void flathubCollectionLoadingChanged();
    void flathubCollectionHasMoreChanged();
    void flathubCategoryRevisionChanged();
    void flatpakSortModeChanged();
    void flatpakUpdateStateChanged();
    void appHubCategoriesChanged();
    void appHubCategoryChanged();
    void appHubInstalledOnlyChanged();
    void busyChanged();
    void statusMessageChanged();
    void operationLogChanged();

private slots:
    void processFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void processErrorOccurred(QProcess::ProcessError error);
    void processOutputReady();

private:
    enum class Operation
    {
        None,
        FlatpakSearch,
        AppHubSync,
        FlatpakInstall,
        FlatpakUpdate,
        FlatpakRemove,
        FlatpakAddonInstall,
        FlatpakAddonRemove,
        AppHubInstall,
        AppHubRemove,
        DistroboxCreate,
        DistroboxStart,
        DistroboxStop,
        DistroboxClone,
        DistroboxRemove
    };

    QByteArray runCommand(const QString &program, const QStringList &arguments, int timeout = 10000) const;
    bool startOperation(const QString &program,
                        const QStringList &arguments,
                        Operation operation,
                        const QString &identifier = {});

    void refreshFlatpakInstalled();
    void refreshFlatpakUpdates();
    void refreshFlatpakAddons();
    void refreshFlathubFeatured();
    void cancelFlathubFeaturedRequests();
    void parseFlathubFeaturedCollection(const QByteArray &output);
    void parseFlathubFeaturedAppstream(const QByteArray &output, int index);
    void finalizeFlathubFeatured();
    void refreshFlathubCollection();
    void requestFlathubCollectionPage(int page);
    void cancelFlathubCollectionRequest();
    void parseFlathubCollection(const QByteArray &output, int collection, int page);
    void setFlathubCollectionLoading(bool loading);
    void refreshFlathubCategories();
    void requestFlathubCategoryPage(const QString &category, int page);
    void cancelFlathubCategoryRequests();
    void parseFlathubCategory(const QByteArray &output, const QString &category, int page);
    void refreshAppHubCatalog();
    void refreshDistrobox();
    void parseFlatpakSearch(const QByteArray &output);

    QList<AppModel::Item> filterItems(const QList<AppModel::Item> &items) const;
    QList<AppModel::Item> sortedInstalledFlatpaks(const QList<AppModel::Item> &items) const;
    QList<AppModel::Item> filterAppHubItems(const QList<AppModel::Item> &items) const;
    QString normalizedAppHubCategory(const AppModel::Item &item) const;
    void refreshAppHubCategories();
    QList<AppModel::Item> loadAppHubItems() const;
    QList<AppModel::Item> loadDistroboxItems(const QByteArray &output) const;

    QString appHubRepositoryPath() const;
    QString architecture() const;
    QString appHubValue(const QString &yaml, const QString &key) const;
    QString integrationType(const QString &yaml) const;
    QString markdownSection(const QString &markdown, const QString &heading) const;
    bool appHubItemInstalled(const QString &name) const;
    bool matches(const AppModel::Item &item) const;
    QString findExecutable(const QString &program) const;
    QString containerEngine() const;
    void appendOperationLog(const QByteArray &output);
    void clearFlatpakUpdateState();

    void setBusy(bool busy);
    void setStatusMessage(const QString &message);

    AppModel *m_flathubModel;
    AppModel *m_flathubUpdatesModel;
    AppModel *m_flatpakAddonsModel;
    AppModel *m_flathubFeaturedModel;
    AppModel *m_flathubCollectionModel;
    AppModel *m_appHubModel;
    AppModel *m_distroboxModel;
    QProcess *m_process;
    QNetworkAccessManager *m_network;
    QNetworkReply *m_featuredCollectionReply = nullptr;
    QHash<QNetworkReply *, int> m_featuredDetailReplies;
    QHash<QNetworkReply *, int> m_featuredIconReplies;
    QNetworkReply *m_flathubCollectionReply = nullptr;
    QByteArray m_processOutput;
    QByteArray m_processErrorOutput;
    bool m_processOutputTooLarge = false;

    QList<AppModel::Item> m_allAppHubItems;
    QList<AppModel::Item> m_featuredItems;
    QHash<int, QList<AppModel::Item>> m_flathubCollectionCache;
    QHash<int, int> m_flathubCollectionNextPage;
    QHash<int, int> m_flathubCollectionTotalPages;
    QHash<QString, AppModel *> m_flathubCategoryModels;
    QHash<QString, QNetworkReply *> m_flathubCategoryReplies;
    QHash<QString, int> m_flathubCategoryNextPage;
    QHash<QString, int> m_flathubCategoryTotalPages;
    QList<AppModel::Item> m_allDistroboxItems;
    QSet<QString> m_installedFlatpaks;
    QString m_query;
    QString m_operationIdentifier;
    QString m_flatpakAddonsApplication;
    QString m_flatpakUpdateIdentifier;
    int m_flatpakUpdateProgress = -1;
    Operation m_operation = Operation::None;
    int m_currentSection = Flathub;
    int m_flathubCollection = TrendingCollection;
    QString m_flatpakSortMode = QStringLiteral("name");
    QStringList m_appHubCategories;
    QString m_appHubCategory;
    bool m_appHubInstalledOnly = false;
    int m_flathubCategoryRevision = 0;
    bool m_flathubCollectionLoading = false;
    bool m_busy = false;
    QString m_statusMessage;
    QString m_operationLog;
};
