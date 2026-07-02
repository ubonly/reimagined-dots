#pragma once

#include <QJsonObject>
#include <QString>

class GoogleProfile {
public:
    QString displayName;
    QString email;
    QString avatar;
    QString updatedAt;

    bool isValid() const;

    QJsonObject toJson() const;
    static GoogleProfile fromJson(const QJsonObject &object);
};
