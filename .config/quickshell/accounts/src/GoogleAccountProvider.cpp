#include "GoogleAccountProvider.h"

#include "SecretStore.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>

namespace {
constexpr qint64 tokenRefreshSkewSeconds = 120;

bool writeJsonFile(const QString &path, const QJsonObject &data, QString *error) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path + ".tmp");
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error)
            *error = file.errorString();
        return false;
    }
    file.write(QJsonDocument(data).toJson(QJsonDocument::Indented));
    file.close();
    QFile::remove(path);
    if (!file.rename(path)) {
        if (error)
            *error = file.errorString();
        return false;
    }
    return true;
}
}

GoogleAccountProvider::GoogleAccountProvider() = default;

QString GoogleAccountProvider::id() const {
    return QStringLiteral("google");
}

ProviderState GoogleAccountProvider::disconnectedState(const QString &message) const {
    ProviderState state;
    state.provider = id();
    state.configured = oauth_.isConfigured();
    state.loggedIn = false;
    state.status = "not_connected";
    state.message = message;
    return state;
}

ProviderState GoogleAccountProvider::profileState(const GoogleProfile &profile, const QString &message) const {
    ProviderState state;
    state.provider = id();
    state.configured = oauth_.isConfigured();
    state.loggedIn = true;
    state.status = "connected";
    state.displayName = profile.displayName;
    state.email = profile.email;
    state.avatar = profile.avatar;
    state.message = message;
    return state;
}

ProviderState GoogleAccountProvider::login(const ProgressCallback &progress) {
    if (!oauth_.isConfigured())
        return disconnectedState("Google OAuth client is not configured for this build.");

    OAuthResult result = oauth_.login([&](const QString &message) {
        if (!progress)
            return;

        ProviderState connecting;
        connecting.provider = id();
        connecting.configured = true;
        connecting.status = "connecting";
        connecting.busy = true;
        connecting.message = message;
        progress(connecting);
    });

    if (!result.success)
        return disconnectedState(result.error);

    OAuthTokenSet existingTokens;
    loadTokens(&existingTokens, nullptr);
    if (result.tokens.refreshToken.isEmpty())
        result.tokens.refreshToken = existingTokens.refreshToken;

    QString secretError;
    if (!saveTokens(result.tokens, &secretError))
        return disconnectedState("Could not store Google tokens in Secret Service: " + secretError);

    return refreshProfile();
}

ProviderState GoogleAccountProvider::logout() {
    QString error;
    SecretStore::clearTokens(id(), &error);
    clearProfile();
    if (!error.isEmpty())
        return disconnectedState("Signed out locally, but Secret Service returned: " + error);
    return disconnectedState();
}

ProviderState GoogleAccountProvider::setClientId(const QString &clientId) {
    QString error;
    if (!oauth_.saveClientId(clientId, &error))
        return disconnectedState("Could not save Google OAuth client ID: " + error);
    return disconnectedState("Google OAuth client ID saved. You can connect now.");
}

ProviderState GoogleAccountProvider::setClientSecret(const QString &clientSecret) {
    QString error;
    if (!oauth_.saveClientSecret(clientSecret, &error))
        return disconnectedState("Could not save Google OAuth client secret: " + error);
    return disconnectedState(clientSecret.trimmed().isEmpty()
        ? "Google OAuth client secret removed."
        : "Google OAuth client secret saved. You can connect now.");
}

ProviderState GoogleAccountProvider::state() {
    if (!oauth_.isConfigured())
        return disconnectedState("Google OAuth client is not configured for this build.");

    OAuthTokenSet tokens;
    QString tokenError;
    if (!loadTokens(&tokens, &tokenError)) {
        QString message;
        if (!tokenError.isEmpty())
            message = "Secret Service unavailable: " + tokenError;
        return disconnectedState(message);
    }

    GoogleProfile profile;
    if (loadProfile(&profile) && profile.isValid())
        return profileState(profile);

    return refreshProfile();
}

ProviderState GoogleAccountProvider::refreshProfile() {
    if (!oauth_.isConfigured())
        return disconnectedState("Google OAuth client is not configured for this build.");

    OAuthTokenSet tokens;
    QString error;
    if (!loadTokens(&tokens, &error))
        return disconnectedState(error.isEmpty() ? QString() : "Secret Service unavailable: " + error);

    if (!ensureAccessToken(&tokens, &error))
        return disconnectedState("Could not refresh Google session: " + error);

    GoogleProfile profile;
    if (!oauth_.fetchProfile(tokens.accessToken, &profile, &error))
        return disconnectedState("Could not fetch Google profile: " + error);

    if (!saveProfile(profile, &error))
        return disconnectedState("Could not save Google profile cache: " + error);

    return profileState(profile);
}

bool GoogleAccountProvider::isLoggedIn() {
    return state().loggedIn;
}

QString GoogleAccountProvider::displayName() {
    return state().displayName;
}

QString GoogleAccountProvider::avatar() {
    return state().avatar;
}

QString GoogleAccountProvider::email() {
    return state().email;
}

bool GoogleAccountProvider::loadTokens(OAuthTokenSet *tokens, QString *error) const {
    QJsonObject object;
    if (!SecretStore::loadTokens(id(), &object, error))
        return false;

    OAuthTokenSet loaded = OAuthTokenSet::fromJson(object);
    if (!loaded.hasRefreshToken()) {
        if (error)
            *error = "Missing refresh token.";
        return false;
    }

    if (tokens)
        *tokens = loaded;
    return true;
}

bool GoogleAccountProvider::saveTokens(const OAuthTokenSet &tokens, QString *error) {
    return SecretStore::saveTokens(id(), tokens.toJson(), error);
}

bool GoogleAccountProvider::ensureAccessToken(OAuthTokenSet *tokens, QString *error) {
    if (tokens->hasUsableAccessToken(tokenRefreshSkewSeconds))
        return true;

    if (!oauth_.refreshAccessToken(tokens, error))
        return false;

    return saveTokens(*tokens, error);
}

bool GoogleAccountProvider::saveProfile(const GoogleProfile &profile, QString *error) {
    return writeJsonFile(statePath(), profile.toJson(), error);
}

bool GoogleAccountProvider::loadProfile(GoogleProfile *profile) const {
    QFile file(statePath());
    if (!file.open(QIODevice::ReadOnly))
        return false;

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject())
        return false;

    if (profile)
        *profile = GoogleProfile::fromJson(doc.object());
    return true;
}

void GoogleAccountProvider::clearProfile() const {
    QFile::remove(statePath());
    QFile::remove(avatarCachePath());
}

QString GoogleAccountProvider::statePath() const {
    return QDir::homePath() + "/.local/state/reimagined/accounts/google-profile.json";
}

QString GoogleAccountProvider::avatarCachePath() const {
    return QDir::homePath() + "/.cache/reimagined/accounts/google-avatar.jpg";
}
