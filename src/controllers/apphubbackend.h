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
    Q_PROPERTY(AppModel *flathubFeaturedModel READ flathubFeaturedModel CONSTANT)
    Q_PROPERTY(AppModel *flathubCollectionModel READ flathubCollectionModel CONSTANT)
    Q_PROPERTY(AppModel *appHubModel READ appHubModel CONSTANT)
    Q_PROPERTY(AppModel *distroboxModel READ distroboxModel CONSTANT)
    Q_PROPERTY(int flathubCollection READ flathubCollection WRITE setFlathubCollection NOTIFY flathubCollectionChanged)
    Q_PROPERTY(bool flathubCollectionLoading READ flathubCollectionLoading NOTIFY flathubCollectionLoadingChanged)
    Q_PROPERTY(bool flathubCollectionHasMore READ flathubCollectionHasMore NOTIFY flathubCollectionHasMoreChanged)
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
    AppModel *flathubFeaturedModel();
    AppModel *flathubCollectionModel();
    AppModel *appHubModel();
    AppModel *distroboxModel();

    int flathubCollection() const;
    void setFlathubCollection(int collection);
    bool flathubCollectionLoading() const;
    bool flathubCollectionHasMore() const;

    int currentSection() const;
    void setCurrentSection(int section);

    bool busy() const;
    QString statusMessage() const;
    QString operationLog() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void loadMoreFlathubCollection();
    Q_INVOKABLE void refreshAppHubRepository();
    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void installFlatpak(const QString &identifier);
    Q_INVOKABLE void removeFlatpak(const QString &identifier);
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
        FlatpakRemove,
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
    void refreshAppHubCatalog();
    void refreshDistrobox();
    void parseFlatpakSearch(const QByteArray &output);

    QList<AppModel::Item> filterItems(const QList<AppModel::Item> &items) const;
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

    void setBusy(bool busy);
    void setStatusMessage(const QString &message);

    AppModel *m_flathubModel;
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
    QList<AppModel::Item> m_allDistroboxItems;
    QSet<QString> m_installedFlatpaks;
    QString m_query;
    QString m_operationIdentifier;
    Operation m_operation = Operation::None;
    int m_currentSection = Flathub;
    int m_flathubCollection = TrendingCollection;
    bool m_flathubCollectionLoading = false;
    bool m_busy = false;
    QString m_statusMessage;
    QString m_operationLog;
};
