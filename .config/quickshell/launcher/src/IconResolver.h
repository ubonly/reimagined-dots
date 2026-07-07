#pragma once

#include <QHash>
#include <QString>
#include <QStringList>

class IconResolver {
public:
    QString resolve(const QString &iconName);

private:
    QString findInKnownLocations(const QString &iconName) const;
    void buildIndex();

    bool m_indexBuilt = false;
    QHash<QString, QString> m_iconIndex;
};
