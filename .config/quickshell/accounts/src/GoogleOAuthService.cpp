#include "GoogleOAuthService.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QHostAddress>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QTimeZone>
#include <QUrl>
#include <QUrlQuery>

#ifndef REIMAGINED_GOOGLE_CLIENT_ID
#define REIMAGINED_GOOGLE_CLIENT_ID ""
#endif

#ifndef REIMAGINED_GOOGLE_CLIENT_SECRET
#define REIMAGINED_GOOGLE_CLIENT_SECRET ""
#endif

namespace {
constexpr int loginTimeoutMs = 300000;
constexpr int networkTimeoutMs = 30000;
constexpr qint64 defaultTokenLifetimeSeconds = 3600;

const QUrl googleAuthorizationUrl("https://accounts.google.com/o/oauth2/v2/auth");
const QUrl googleTokenUrl("https://oauth2.googleapis.com/token");
const QUrl googleUserInfoUrl("https://www.googleapis.com/oauth2/v3/userinfo");

QDateTime fallbackExpiration(const QDateTime &expiresAt) {
    return expiresAt.isValid()
        ? expiresAt
        : QDateTime::currentDateTimeUtc().addSecs(defaultTokenLifetimeSeconds);
}

QString base64Url(const QByteArray &data) {
    return QString::fromLatin1(data.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

QString randomToken(int bytes = 32) {
    QByteArray raw;
    raw.resize(bytes);
    for (int i = 0; i < raw.size(); ++i)
        raw[i] = static_cast<char>(QRandomGenerator::global()->generate() & 0xff);
    return base64Url(raw);
}

QString callbackHtml() {
    return QStringLiteral(
        "<!doctype html><meta charset='utf-8'>"
        "<title>Reimagined Google Account</title>"
        "<style>body{font-family:sans-serif;background:#111;color:#eee;"
        "display:grid;place-items:center;height:100vh;margin:0}"
        "main{max-width:420px;padding:24px;border-radius:18px;background:#202124}"
        "</style><main><h2>Google account connected</h2>"
        "<p>You can close this tab and return to Reimagined Settings.</p></main>");
}

bool saveTextFile(const QString &path, const QString &value, bool privateFile, QString *error) {
    if (error)
        error->clear();

    const QString trimmed = value.trimmed();
    if (trimmed.isEmpty()) {
        if (error)
            *error = "Value is empty.";
        return false;
    }

    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
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

    if (privateFile)
        QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);

    return true;
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

    return saveTextFile(clientIdPath(), trimmed, false, error);
}

QString GoogleOAuthService::clientSecret() const {
    const QString envSecret = QString::fromLocal8Bit(qgetenv("REIMAGINED_GOOGLE_CLIENT_SECRET")).trimmed();
    if (!envSecret.isEmpty())
        return envSecret;

    const QString compiledSecret = QStringLiteral(REIMAGINED_GOOGLE_CLIENT_SECRET).trimmed();
    if (!compiledSecret.isEmpty())
        return compiledSecret;

    QFile file(clientSecretPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString::fromUtf8(file.readAll()).trimmed();

    return {};
}

bool GoogleOAuthService::saveClientSecret(const QString &secret, QString *error) {
    if (secret.trimmed().isEmpty()) {
        QFile::remove(clientSecretPath());
        if (error)
            error->clear();
        return true;
    }

    return saveTextFile(clientSecretPath(), secret, true, error);
}

OAuthResult GoogleOAuthService::login(const ProgressCallback &progress) {
    OAuthResult result;
    const QString cid = clientId();
    if (cid.isEmpty()) {
        result.error = "Google OAuth client is not configured for this build.";
        return result;
    }

    const QString verifier = randomToken(64);
    const QString challenge = base64Url(QCryptographicHash::hash(verifier.toUtf8(), QCryptographicHash::Sha256));
    const QString expectedState = randomToken(32);
    QString callbackCode;
    QString callbackError;

    QTcpServer server;
    if (!server.listen(QHostAddress::LocalHost, 0)) {
        result.error = "Could not start local OAuth callback server: " + server.errorString();
        return result;
    }

    const QString redirectUri = QStringLiteral("http://127.0.0.1:%1/").arg(server.serverPort());

    QUrl authUrl(googleAuthorizationUrl);
    QUrlQuery query;
    query.addQueryItem("client_id", cid);
    query.addQueryItem("redirect_uri", redirectUri);
    query.addQueryItem("response_type", "code");
    query.addQueryItem("scope", "openid email profile");
    query.addQueryItem("state", expectedState);
    query.addQueryItem("access_type", "offline");
    query.addQueryItem("prompt", "consent");
    query.addQueryItem("code_challenge", challenge);
    query.addQueryItem("code_challenge_method", "S256");
    authUrl.setQuery(query);

    QEventLoop callbackLoop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&timeout, &QTimer::timeout, [&]() {
        callbackLoop.quit();
    });
    QObject::connect(&server, &QTcpServer::newConnection, [&]() {
        QTcpSocket *socket = server.nextPendingConnection();
        if (!socket)
            return;

        QObject::connect(socket, &QTcpSocket::readyRead, [&, socket]() {
            const QByteArray request = socket->readAll();
            const QList<QByteArray> parts = request.split(' ');
            if (parts.size() >= 2) {
                const QUrl requestUrl(QString::fromLatin1("http://127.0.0.1") + QString::fromLatin1(parts.at(1)));
                const QUrlQuery responseQuery(requestUrl);
                const QString responseState = responseQuery.queryItemValue("state");
                callbackError = responseQuery.queryItemValue("error");
                callbackCode = responseQuery.queryItemValue("code");

                if (responseState != expectedState)
                    callbackError = "OAuth state mismatch.";
                if (callbackCode.isEmpty() && callbackError.isEmpty())
                    callbackError = "OAuth callback did not include an authorization code.";
            }

            const QByteArray html = callbackHtml().toUtf8();
            socket->write("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: ");
            socket->write(QByteArray::number(html.size()));
            socket->write("\r\nConnection: close\r\n\r\n");
            socket->write(html);
            socket->disconnectFromHost();
            callbackLoop.quit();
        });
    });

    if (progress)
        progress("Complete Google sign-in in the browser.");
    if (!QProcess::startDetached("xdg-open", {authUrl.toString(QUrl::FullyEncoded)})) {
        server.close();
        result.error = "Could not open the default browser for Google sign-in.";
        return result;
    }

    timeout.start(loginTimeoutMs);
    callbackLoop.exec();
    server.close();

    if (callbackCode.isEmpty()) {
        result.error = callbackError.isEmpty()
            ? "Google sign-in timed out."
            : "Google sign-in failed: " + callbackError;
        return result;
    }

    QVariantMap tokenForm {
        {"client_id", cid},
        {"code", callbackCode},
        {"code_verifier", verifier},
        {"grant_type", "authorization_code"},
        {"redirect_uri", redirectUri},
    };
    const QString secret = clientSecret();
    if (!secret.isEmpty())
        tokenForm.insert("client_secret", secret);

    QString error;
    const QJsonObject token = postForm(googleTokenUrl, tokenForm, &error);

    if (!error.isEmpty()) {
        result.error = "Google token exchange failed: " + error;
        return result;
    }

    result.tokens.accessToken = token.value("access_token").toString();
    result.tokens.refreshToken = token.value("refresh_token").toString();
    result.tokens.tokenType = token.value("token_type").toString();
    result.tokens.idToken = token.value("id_token").toString();
    result.tokens.expiresAt = QDateTime::currentDateTimeUtc().addSecs(qMax<qint64>(0, token.value("expires_in").toInteger(defaultTokenLifetimeSeconds)));
    result.success = !result.tokens.accessToken.isEmpty();
    if (result.success)
        return result;

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

    QVariantMap refreshForm {
        {"client_id", cid},
        {"refresh_token", tokens->refreshToken},
        {"grant_type", "refresh_token"},
    };
    const QString secret = clientSecret();
    if (!secret.isEmpty())
        refreshForm.insert("client_secret", secret);

    const QJsonObject refreshed = postForm(googleTokenUrl, refreshForm, error);

    if (error && !error->isEmpty())
        return false;

    const QString accessToken = refreshed.value("access_token").toString();
    if (accessToken.isEmpty()) {
        if (error)
            *error = "Google token refresh finished without an access token.";
        return false;
    }

    tokens->accessToken = accessToken;
    tokens->tokenType = refreshed.value("token_type").toString(tokens->tokenType);
    tokens->idToken = refreshed.value("id_token").toString(tokens->idToken);
    tokens->expiresAt = QDateTime::currentDateTimeUtc().addSecs(qMax<qint64>(0, refreshed.value("expires_in").toInteger(defaultTokenLifetimeSeconds)));
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

QString GoogleOAuthService::clientSecretPath() const {
    return configDir() + "/accounts/google_client_secret";
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

QJsonObject GoogleOAuthService::postForm(const QUrl &url, const QVariantMap &form, QString *error) {
    if (error)
        error->clear();

    QUrlQuery query;
    for (auto it = form.constBegin(); it != form.constEnd(); ++it)
        query.addQueryItem(it.key(), it.value().toString());

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
    QNetworkReply *reply = network_.post(request, query.toString(QUrl::FullyEncoded).toUtf8());

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    QObject::connect(&timeout, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    timeout.start(networkTimeoutMs);
    loop.exec();

    const QByteArray payload = reply->readAll();
    const QJsonDocument doc = QJsonDocument::fromJson(payload);

    if (reply->error() != QNetworkReply::NoError) {
        if (error) {
            const QJsonObject object = doc.object();
            const QString googleError = object.value("error_description").toString(object.value("error").toString());
            *error = googleError.isEmpty() ? reply->errorString() : googleError;
        }
        reply->deleteLater();
        return {};
    }

    reply->deleteLater();
    if (!doc.isObject()) {
        if (error)
            *error = "Google token response is not valid JSON.";
        return {};
    }

    return doc.object();
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
