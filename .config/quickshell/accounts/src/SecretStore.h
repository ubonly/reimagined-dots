#pragma once

#include <QJsonObject>
#include <QString>

class SecretStore {
public:
    static bool loadTokens(const QString &provider, QJsonObject *tokens, QString *error);
    static bool saveTokens(const QString &provider, const QJsonObject &tokens, QString *error);
    static bool clearTokens(const QString &provider, QString *error);
};
