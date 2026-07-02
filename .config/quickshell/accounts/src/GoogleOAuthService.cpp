#include "GoogleOAuthService.h"

#include <QAbstractOAuth>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QOAuth2AuthorizationCodeFlow>
#include <QOAuthHttpServerReplyHandler>
#include <QProcess>
#include <QSaveFile>
#include <QTimer>
#include <QTimeZone>
#include <QUrlQuery>

#ifndef REIMAGINED_GOOGLE_CLIENT_ID
#define REIMAGINED_GOOGLE_CLIENT_ID ""
#endif

namespace {
constexpr int loginTimeoutMs = 300000;
constexpr int networkTimeoutMs = 30000;
constexpr int refreshTimeoutMs = 60000;
constexpr qint64 defaultTokenLifetimeSeconds = 3600;

const QUrl googleAuthorizationUrl("https://accounts.google.com/o/oauth2/v2/auth");
const QUrl googleTokenUrl("https://oauth2.googleapis.com/token");
const QUrl googleUserInfoUrl("https://www.googleapis.com/oauth2/v3/userinfo");

QString oauthErrorToString(QAbstractOAuth::Error error) {
    switch (error) {
    case QAbstractOAuth::Error::NoError:
        return {};
    case QAbstractOAuth::Error::NetworkError:
        return "Network error.";
    case QAbstractOAuth::Error::ServerError:
        return "OAuth server error.";
    case QAbstractOAuth::Error::OAuthTokenNotFoundError:
        return "OAuth token was not returned.";
    case QAbstractOAuth::Error::OAuthTokenSecretNotFoundError:
        return "OAuth token secret was not returned.";
    case QAbstractOAuth::Error::OAuthCallbackNotVerified:
        return "OAuth callback verification failed.";
    case QAbstractOAuth::Error::ClientError:
        return "OAuth client error.";
    case QAbstractOAuth::Error::ExpiredError:
        return "OAuth token expired.";
    }
    return "Unknown OAuth error.";
}

QDateTime fallbackExpiration(const QDateTime &expiresAt) {
    return expiresAt.isValid()
        ? expiresAt
        : QDateTime::currentDateTimeUtc().addSecs(defaultTokenLifetimeSeconds);
}

void configureGoogleFlow(QOAuth2AuthorizationCodeFlow *flow, const QString &clientId) {
    flow->setAuthorizationUrl(googleAuthorizationUrl);
    flow->setTokenUrl(googleTokenUrl);
    flow->setClientIdentifier(clientId);
    flow->setRequestedScopeTokens({QByteArray("openid"), QByteArray("email"), QByteArray("profile")});
    flow->setPkceMethod(QOAuth2AuthorizationCodeFlow::PkceMethod::S256, 64);
    flow->setContentType(QAbstractOAuth::ContentType::WwwFormUrlEncoded);
    flow->setModifyParametersFunction([](QAbstractOAuth::Stage stage, QMultiMap<QString, QVariant> *parameters) {
        if (stage != QAbstractOAuth::Stage::RequestingAuthorization)
            return;

        parameters->replace("access_type", "offline");
        parameters->replace("prompt", "consent");
    });
}
}

bool OAuthTokenSet::hasRefreshToken() const {
    return !refreshToken.trimmed().isEmpty();
}

bool OAuthTokenSet::hasUsableAccessToken(qint64 refreshSkewSeconds) const {
    return !accessToken.trimmed().isEmpty()
        && expiresAt.isValid()
        && expiresAt > QDateTime::currentDateTimeUtc().addSecs(refreshSkewSeconds);
}

QJsonObject OAuthTokenSet::toJson() const {
    return {
        {"access_token", accessToken},
        {"refresh_token", refreshToken},
        {"token_type", tokenType},
        {"id_token", idToken},
        {"expires_at", expiresAt.toSecsSinceEpoch()},
    };
}

OAuthTokenSet OAuthTokenSet::fromJson(const QJsonObject &object) {
    OAuthTokenSet tokens;
    tokens.accessToken = object.value("access_token").toString();
    tokens.refreshToken = object.value("refresh_token").toString();
    tokens.tokenType = object.value("token_type").toString();
    tokens.idToken = object.value("id_token").toString();

    const qint64 expiresAt = object.value("expires_at").toInteger();
    if (expiresAt > 0)
        tokens.expiresAt = QDateTime::fromSecsSinceEpoch(expiresAt, QTimeZone::UTC);

    return tokens;
}

GoogleOAuthService::GoogleOAuthService() = default;

bool GoogleOAuthService::isConfigured() const {
    return !clientId().isEmpty();
}

QString GoogleOAuthService::clientId() const {
    const QString envClient = QString::fromLocal8Bit(qgetenv("REIMAGINED_GOOGLE_CLIENT_ID")).trimmed();
    if (!envClient.isEmpty())
        return envClient;

    const QString compiledClient = QStringLiteral(REIMAGINED_GOOGLE_CLIENT_ID).trimmed();
    if (!compiledClient.isEmpty())
        return compiledClient;

    QFile file(clientIdPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString::fromUtf8(file.readAll()).trimmed();

    return {};
}

bool GoogleOAuthService::saveClientId(const QString &clientId, QString *error) {
    if (error)
        error->clear();

    const QString trimmed = clientId.trimmed();
    if (trimmed.isEmpty()) {
        if (error)
            *error = "Google OAuth client ID is empty.";
        return false;
    }

    QDir().mkpath(QFileInfo(clientIdPath()).absolutePath());
    QSaveFile file(clientIdPath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        if (error)
            *error = file.errorString();
        return false;
    }

    file.write(trimmed.toUtf8());
    file.write("\n");
    if (!file.commit()) {
        if (error)
            *error = file.errorString();
        return false;
    }

    return true;
}

OAuthResult GoogleOAuthService::login(const ProgressCallback &progress) {
    OAuthResult result;
    const QString cid = clientId();
    if (cid.isEmpty()) {
        result.error = "Google OAuth client is not configured for this build.";
        return result;
    }

    QOAuth2AuthorizationCodeFlow oauth(&network_);
    configureGoogleFlow(&oauth, cid);

    QOAuthHttpServerReplyHandler replyHandler;
    replyHandler.setCallbackText(QStringLiteral(
        "<!doctype html><meta charset='utf-8'>"
        "<title>Reimagined Google Account</title>"
        "<style>body{font-family:sans-serif;background:#111;color:#eee;"
        "display:grid;place-items:center;height:100vh;margin:0}"
        "main{max-width:420px;padding:24px;border-radius:18px;background:#202124}"
        "</style><main><h2>Google account connected</h2>"
        "<p>You can close this tab and return to Reimagined Settings.</p></main>"));

    if (!replyHandler.isListening() && !replyHandler.listen(QHostAddress::LocalHost, 0)) {
        result.error = "Could not start local OAuth callback server.";
        return result;
    }

    oauth.setReplyHandler(&replyHandler);

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    bool finished = false;
    QString error;

    QObject::connect(&timeout, &QTimer::timeout, [&]() {
        if (finished)
            return;
        finished = true;
        error = "Google sign-in timed out.";
        loop.quit();
    });

    QObject::connect(&oauth, &QAbstractOAuth::authorizeWithBrowser, [&](const QUrl &url) {
        if (progress)
            progress("Complete Google sign-in in the browser.");
        if (!QProcess::startDetached("xdg-open", {url.toString(QUrl::FullyEncoded)})) {
            finished = true;
            error = "Could not open the default browser for Google sign-in.";
            loop.quit();
        }
    });

    QObject::connect(&oauth, &QAbstractOAuth::granted, [&]() {
        if (finished)
            return;

        finished = true;
        result.success = true;
        result.tokens.accessToken = oauth.token();
        result.tokens.refreshToken = oauth.refreshToken();
        result.tokens.tokenType = oauth.extraTokens().value("token_type").toString();
        result.tokens.idToken = oauth.idToken();
        result.tokens.expiresAt = fallbackExpiration(oauth.expirationAt());
        loop.quit();
    });

    QObject::connect(&oauth, &QAbstractOAuth::requestFailed, [&](QAbstractOAuth::Error oauthError) {
        if (finished)
            return;
        finished = true;
        error = oauthErrorToString(oauthError);
        loop.quit();
    });

    QObject::connect(&oauth, &QAbstractOAuth2::serverReportedErrorOccurred,
                     [&](const QString &oauthError, const QString &description, const QUrl &) {
        if (finished)
            return;
        finished = true;
        error = description.isEmpty() ? oauthError : description;
        loop.quit();
    });

    timeout.start(loginTimeoutMs);
    oauth.grant();

    if (!finished)
        loop.exec();

    replyHandler.close();

    if (!error.isEmpty()) {
        result.success = false;
        result.error = error;
        return result;
    }

    if (!result.tokens.accessToken.isEmpty())
        return result;

    result.success = false;
    result.error = "Google OAuth finished without an access token.";
    return result;
}

bool GoogleOAuthService::refreshAccessToken(OAuthTokenSet *tokens, QString *error) {
    if (error)
        error->clear();
    if (!tokens || !tokens->hasRefreshToken()) {
        if (error)
            *error = "Missing refresh token.";
        return false;
    }

    const QString cid = clientId();
    if (cid.isEmpty()) {
        if (error)
            *error = "Google OAuth client is not configured for this build.";
        return false;
    }

    QOAuth2AuthorizationCodeFlow oauth(&network_);
    configureGoogleFlow(&oauth, cid);
    oauth.setRefreshToken(tokens->refreshToken);

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    bool finished = false;
    QString refreshError;

    QObject::connect(&timeout, &QTimer::timeout, [&]() {
        if (finished)
            return;
        finished = true;
        refreshError = "Google token refresh timed out.";
        loop.quit();
    });

    QObject::connect(&oauth, &QAbstractOAuth::tokenChanged, [&](const QString &accessToken) {
        if (finished || accessToken.isEmpty())
            return;
        finished = true;
        loop.quit();
    });

    QObject::connect(&oauth, &QAbstractOAuth::requestFailed, [&](QAbstractOAuth::Error oauthError) {
        if (finished)
            return;
        finished = true;
        refreshError = oauthErrorToString(oauthError);
        loop.quit();
    });

    QObject::connect(&oauth, &QAbstractOAuth2::serverReportedErrorOccurred,
                     [&](const QString &oauthError, const QString &description, const QUrl &) {
        if (finished)
            return;
        finished = true;
        refreshError = description.isEmpty() ? oauthError : description;
        loop.quit();
    });

    timeout.start(refreshTimeoutMs);
    oauth.refreshTokens();

    if (!finished)
        loop.exec();

    if (!refreshError.isEmpty()) {
        if (error)
            *error = refreshError;
        return false;
    }

    if (oauth.token().isEmpty()) {
        if (error)
            *error = "Google token refresh finished without an access token.";
        return false;
    }

    tokens->accessToken = oauth.token();
    if (!oauth.refreshToken().isEmpty())
        tokens->refreshToken = oauth.refreshToken();
    const QString refreshedTokenType = oauth.extraTokens().value("token_type").toString();
    if (!refreshedTokenType.isEmpty())
        tokens->tokenType = refreshedTokenType;
    tokens->idToken = oauth.idToken().isEmpty() ? tokens->idToken : oauth.idToken();
    tokens->expiresAt = fallbackExpiration(oauth.expirationAt());
    return true;
}

bool GoogleOAuthService::fetchProfile(const QString &accessToken, GoogleProfile *profile, QString *error) {
    if (error)
        error->clear();
    if (accessToken.trimmed().isEmpty()) {
        if (error)
            *error = "Missing access token.";
        return false;
    }

    QNetworkRequest request(googleUserInfoUrl);
    request.setRawHeader("Authorization", QByteArray("Bearer ") + accessToken.toUtf8());
    QNetworkReply *reply = network_.get(request);

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    QObject::connect(&timeout, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    timeout.start(networkTimeoutMs);
    loop.exec();

    const QByteArray payload = reply->readAll();
    if (reply->error() != QNetworkReply::NoError) {
        if (error)
            *error = reply->errorString();
        reply->deleteLater();
        return false;
    }
    reply->deleteLater();

    const QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) {
        if (error)
            *error = "Google profile response is not valid JSON.";
        return false;
    }

    const QJsonObject userInfo = doc.object();
    GoogleProfile normalized;
    normalized.displayName = userInfo.value("name").toString();
    normalized.email = userInfo.value("email").toString();
    normalized.updatedAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QString avatarError;
    normalized.avatar = cacheAvatar(userInfo.value("picture").toString(), &avatarError);

    if (!normalized.isValid()) {
        if (error)
            *error = "Google profile response did not include display name or email.";
        return false;
    }

    if (profile)
        *profile = normalized;
    return true;
}

QString GoogleOAuthService::configDir() const {
    return QDir::homePath() + "/.config/quickshell";
}

QString GoogleOAuthService::clientIdPath() const {
    return configDir() + "/accounts/google_client_id";
}

QString GoogleOAuthService::avatarCachePath() const {
    return QDir::homePath() + "/.cache/reimagined/accounts/google-avatar.jpg";
}

QString GoogleOAuthService::cacheAvatar(const QString &avatarUrl, QString *error) {
    if (error)
        error->clear();
    if (avatarUrl.trimmed().isEmpty())
        return {};

    const QByteArray bytes = getBytes(QUrl(avatarUrl), error);
    if (error && !error->isEmpty())
        return {};

    QDir().mkpath(QFileInfo(avatarCachePath()).absolutePath());
    QFile file(avatarCachePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error)
            *error = file.errorString();
        return {};
    }

    file.write(bytes);
    return avatarCachePath();
}

QByteArray GoogleOAuthService::getBytes(const QUrl &url, QString *error) {
    if (error)
        error->clear();

    QNetworkReply *reply = network_.get(QNetworkRequest(url));
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    QObject::connect(&timeout, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    timeout.start(networkTimeoutMs);
    loop.exec();

    const QByteArray payload = reply->readAll();
    if (reply->error() != QNetworkReply::NoError && error)
        *error = reply->errorString();
    reply->deleteLater();
    return payload;
}
