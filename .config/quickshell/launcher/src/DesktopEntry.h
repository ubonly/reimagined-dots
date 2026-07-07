#pragma once

#include <QJsonObject>
#include <QString>

struct DesktopEntry {
    QString name;
    QString genericName;
    QString comment;
    QString exec;
    QString icon;
    QString categories;
    QString keywords;
    QString iconPath;
    QString desktopId;

    bool isValid() const;
    QJsonObject toJson() const;
};
