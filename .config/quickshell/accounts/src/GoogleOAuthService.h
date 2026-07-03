#pragma once

#include "GoogleProfile.h"

#include <QDateTime>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QUrl>
#include <QString>
#include <QVariantMap>

#include <functional>

struct OAuthTokenSet {
    QString accessToken;
    QString refreshToken;
    QString tokenType;
    QString idToken;
    QDateTime expiresAt;

    bool hasRefreshToken() const;
    bool hasUsableAccessToken(qint64 refreshSkewSeconds) const;

    QJsonObject toJson() const;
    static OAuthTokenSet fromJson(const QJsonObject &object);
};

struct OAuthResult {
    bool success = false;
    OAuthTokenSet tokens;
    QString message;
    QString error;
};

class GoogleOAuthService {
public:
    using ProgressCallback = std::function<void(const QString &)>;

    GoogleOAuthService();

    bool isConfigured() const;
    QString clientId() const;
    bool saveClientId(const QString &clientId, QString *error);
    QString clientSecret() const;
    bool saveClientSecret(const QString &clientSecret, QString *error);

    OAuthResult login(const ProgressCallback &progress);
    bool refreshAccessToken(OAuthTokenSet *tokens, QString *error);
    bool fetchProfile(const QString &accessToken, GoogleProfile *profile, QString *error);

private:
    QString configDir() const;
    QString clientIdPath() const;
    QString clientSecretPath() const;
    QString avatarCachePath() const;
    QString cacheAvatar(const QString &avatarUrl, QString *error);
    QJsonObject postForm(const QUrl &url, const QVariantMap &form, QString *error);
    QByteArray getBytes(const QUrl &url, QString *error);

    QNetworkAccessManager network_;
};
