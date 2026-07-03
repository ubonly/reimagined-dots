#pragma once

#include "AccountProvider.h"
#include "GoogleOAuthService.h"
#include "GoogleProfile.h"

class GoogleAccountProvider final : public AccountProvider {
public:
    GoogleAccountProvider();

    QString id() const override;
    ProviderState login(const ProgressCallback &progress) override;
    ProviderState logout() override;
    ProviderState state() override;
    ProviderState refreshProfile() override;

    bool isLoggedIn() override;
    QString displayName() override;
    QString avatar() override;
    QString email() override;

    ProviderState setClientId(const QString &clientId);
    ProviderState setClientSecret(const QString &clientSecret);

private:
    ProviderState disconnectedState(const QString &message = QString()) const;
    ProviderState profileState(const GoogleProfile &profile, const QString &message = QString()) const;

    bool loadTokens(OAuthTokenSet *tokens, QString *error) const;
    bool saveTokens(const OAuthTokenSet &tokens, QString *error);
    bool ensureAccessToken(OAuthTokenSet *tokens, QString *error);

    bool saveProfile(const GoogleProfile &profile, QString *error);
    bool loadProfile(GoogleProfile *profile) const;
    void clearProfile() const;

    QString statePath() const;
    QString avatarCachePath() const;

    GoogleOAuthService oauth_;
};
