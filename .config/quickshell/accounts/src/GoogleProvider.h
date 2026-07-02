#pragma once

#include "AccountProvider.h"

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QString>

class GoogleProvider final : public AccountProvider {
public:
    GoogleProvider();

    QString id() const override;
    ProviderState login(const ProgressCallback &progress) override;
    ProviderState logout() override;
    ProviderState state() override;
    ProviderState refreshProfile() override;

    bool isLoggedIn() override;
    QString displayName() override;
    QString avatar() override;
    QString email() override;

private:
    QString clientId() const;
    ProviderState disconnectedState(const QString &message = QString()) const;
    ProviderState profileState(const QJsonObject &profile, const QString &message = QString()) const;

    bool hasRefreshToken(QJsonObject *tokens = nullptr, QString *error = nullptr) const;
    bool refreshAccessToken(QJsonObject *tokens, QString *error);
    bool ensureAccessToken(QJsonObject *tokens, QString *error);
    bool fetchProfile(const QString &accessToken, QJsonObject *profile, QString *error);
    bool saveProfile(const QJsonObject &profile, QString *error);
    bool loadProfile(QJsonObject *profile) const;
    void clearProfile() const;
    QString cacheAvatar(const QString &avatarUrl, QString *error);

    QJsonObject postForm(const QString &url, const QVariantMap &form, QString *error);
    QJsonObject getJson(const QString &url, const QString &accessToken, QString *error);
    QByteArray getBytes(const QString &url, QString *error);

    QString configDir() const;
    QString statePath() const;
    QString avatarCachePath() const;
    qint64 nowSeconds() const;

    QNetworkAccessManager network_;
};
