#pragma once

#include "DesktopEntry.h"
#include "IconResolver.h"

#include <QJsonArray>
#include <QString>
#include <QStringList>

class AppDiscovery {
public:
    AppDiscovery();

    QJsonArray applications();
    QString fingerprint() const;
    bool writeCache(const QString &cachePath, const QJsonArray &apps, QString *error) const;

private:
    QStringList desktopDirectories() const;
    QStringList desktopFiles() const;
    DesktopEntry readDesktopEntry(const QString &path);
    void readDesktopField(DesktopEntry &entry, const QString &key, const QString &value) const;
    QString cleanExec(QString value) const;

    IconResolver m_iconResolver;
};
