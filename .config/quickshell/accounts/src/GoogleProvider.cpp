#include "GoogleProvider.h"

#include "SecretStore.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QStandardPaths>
#include <QVariantMap>

#ifndef REIMAGINED_GOOGLE_CLIENT_ID
#define REIMAGINED_GOOGLE_CLIENT_ID ""
#endif

namespace {
constexpr int loginTimeoutMs = 300000;
constexpr qint64 tokenRefreshSkewSeconds = 120;

QString base64Url(const QByteArray &data) {
    QByteArray encoded = data.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    return QString::fromLatin1(encoded);
}

QString randomToken(int bytes = 32) {
    QByteArray raw;
    raw.resize(bytes);
    for (int i = 0; i < raw.size(); ++i)
        raw[i] = static_cast<char>(QRandomGenerator::global()->generate() & 0xff);
    return base64Url(raw);
}

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
}

GoogleProvider::GoogleProvider() = default;

QString GoogleProvider::id() const {
    return QStringLiteral("google");
}

QString GoogleProvider::clientId() const {
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

ProviderState GoogleProvider::disconnectedState(const QString &message) const {
    ProviderState state;
    state.provider = id();
    state.configured = !clientId().isEmpty();
    state.loggedIn = false;
    state.status = "not_connected";
    state.message = message;
    return state;
}

ProviderState GoogleProvider::profileState(const QJsonObject &profile, const QString &message) const {
    ProviderState state;
    state.provider = id();
    state.configured = !clientId().isEmpty();
    state.loggedIn = true;
    state.status = "connected";
    state.displayName = profile.value("displayName").toString();
    state.email = profile.value("email").toString();
    state.avatar = profile.value("avatar").toString();
    state.message = message;
    return state;
}

ProviderState GoogleProvider::login(const ProgressCallback &progress) {
    const QString cid = clientId();
    if (cid.isEmpty())
        return disconnectedState("Google OAuth client is not configured for this build.");

    const QString verifier = randomToken(64);
    const QString challenge = base64Url(QCryptographicHash::hash(verifier.toUtf8(), QCryptographicHash::Sha256));
    const QString expectedState = randomToken(32);
    QString callbackCode;
    QString callbackError;

    QTcpServer server;
    if (!server.listen(QHostAddress::LocalHost, 0))
        return disconnectedState("Could not start local OAuth callback server: " + server.errorString());

    const QString redirectUri = QStringLiteral("http://127.0.0.1:%1/oauth2callback").arg(server.serverPort());

    ProviderState connecting;
    connecting.provider = id();
    connecting.configured = true;
    connecting.status = "connecting";
    connecting.busy = true;
    connecting.message = "Complete Google sign-in in the browser.";
    if (progress)
        progress(connecting);

    QUrl authUrl("https://accounts.google.com/o/oauth2/v2/auth");
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

    if (!QProcess::startDetached("xdg-open", {authUrl.toString(QUrl::FullyEncoded)}))
        return disconnectedState("Could not open the default browser for Google sign-in.");

    QEventLoop callbackLoop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&timeout, &QTimer::timeout, &callbackLoop, &QEventLoop::quit);
    QObject::connect(&server, &QTcpServer::newConnection, [&]() {
        QTcpSocket *socket = server.nextPendingConnection();
        if (!socket)
            return;

        QObject::connect(socket, &QTcpSocket::readyRead, [&]() {
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

    timeout.start(loginTimeoutMs);
    callbackLoop.exec();
    server.close();

    if (callbackCode.isEmpty()) {
        return disconnectedState(callbackError.isEmpty()
            ? "Google sign-in timed out."
            : "Google sign-in failed: " + callbackError);
    }

    QString error;
    QJsonObject token = postForm("https://oauth2.googleapis.com/token", {
        {"client_id", cid},
        {"code", callbackCode},
        {"code_verifier", verifier},
        {"grant_type", "authorization_code"},
        {"redirect_uri", redirectUri},
    }, &error);

    if (!error.isEmpty())
        return disconnectedState("Google token exchange failed: " + error);

    const qint64 expiresIn = qMax<qint64>(0, token.value("expires_in").toInteger());
    token.insert("expires_at", nowSeconds() + expiresIn);

    QString secretError;
    QJsonObject existingTokens;
    SecretStore::loadTokens(id(), &existingTokens, nullptr);
    if (!token.contains("refresh_token") && existingTokens.contains("refresh_token"))
        token.insert("refresh_token", existingTokens.value("refresh_token"));

    if (!SecretStore::saveTokens(id(), token, &secretError))
        return disconnectedState("Could not store Google tokens in Secret Service: " + secretError);

    return refreshProfile();
}

ProviderState GoogleProvider::logout() {
    QString error;
    SecretStore::clearTokens(id(), &error);
    clearProfile();
    if (!error.isEmpty())
        return disconnectedState("Signed out locally, but Secret Service returned: " + error);
    return disconnectedState();
}

ProviderState GoogleProvider::setClientId(const QString &clientId) {
    const QString trimmed = clientId.trimmed();
    if (trimmed.isEmpty())
        return disconnectedState("Google OAuth client ID is empty.");

    QDir().mkpath(QFileInfo(clientIdPath()).absolutePath());
    QSaveFile file(clientIdPath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return disconnectedState("Could not open Google OAuth client ID file: " + file.errorString());

    file.write(trimmed.toUtf8());
    file.write("\n");
    if (!file.commit())
        return disconnectedState("Could not save Google OAuth client ID: " + file.errorString());

    return disconnectedState("Google OAuth client ID saved. You can connect now.");
}

ProviderState GoogleProvider::state() {
    if (clientId().isEmpty())
        return disconnectedState("Google OAuth client is not configured for this build.");

    QJsonObject tokens;
    QString tokenError;
    const bool hasToken = hasRefreshToken(&tokens, &tokenError);
    if (!hasToken) {
        QString message;
        if (!clientId().isEmpty() && !tokenError.isEmpty())
            message = "Secret Service unavailable: " + tokenError;
        return disconnectedState(message);
    }

    QJsonObject profile;
    if (loadProfile(&profile) && !profile.value("displayName").toString().isEmpty())
        return profileState(profile);

    return refreshProfile();
}

ProviderState GoogleProvider::refreshProfile() {
    if (clientId().isEmpty())
        return disconnectedState("Google OAuth client is not configured for this build.");

    QJsonObject tokens;
    QString error;
    if (!hasRefreshToken(&tokens, &error))
        return disconnectedState(error.isEmpty() ? QString() : "Secret Service unavailable: " + error);

    if (!ensureAccessToken(&tokens, &error))
        return disconnectedState("Could not refresh Google session: " + error);

    QJsonObject profile;
    if (!fetchProfile(tokens.value("access_token").toString(), &profile, &error))
        return disconnectedState("Could not fetch Google profile: " + error);

    if (!saveProfile(profile, &error))
        return disconnectedState("Could not save Google profile cache: " + error);

    return profileState(profile);
}

bool GoogleProvider::isLoggedIn() {
    return state().loggedIn;
}

QString GoogleProvider::displayName() {
    return state().displayName;
}

QString GoogleProvider::avatar() {
    return state().avatar;
}

QString GoogleProvider::email() {
    return state().email;
}

bool GoogleProvider::hasRefreshToken(QJsonObject *tokens, QString *error) const {
    QJsonObject loaded;
    if (!SecretStore::loadTokens(id(), &loaded, error))
        return false;

    if (tokens)
        *tokens = loaded;
    return !loaded.value("refresh_token").toString().isEmpty();
}

bool GoogleProvider::refreshAccessToken(QJsonObject *tokens, QString *error) {
    const QString refreshToken = tokens->value("refresh_token").toString();
    if (refreshToken.isEmpty()) {
        if (error)
            *error = "Missing refresh token.";
        return false;
    }

    const QJsonObject refreshed = postForm("https://oauth2.googleapis.com/token", {
        {"client_id", clientId()},
        {"refresh_token", refreshToken},
        {"grant_type", "refresh_token"},
    }, error);

    if (error && !error->isEmpty())
        return false;

    tokens->insert("access_token", refreshed.value("access_token"));
    tokens->insert("token_type", refreshed.value("token_type"));
    tokens->insert("expires_at", nowSeconds() + qMax<qint64>(0, refreshed.value("expires_in").toInteger()));
    return SecretStore::saveTokens(id(), *tokens, error);
}

bool GoogleProvider::ensureAccessToken(QJsonObject *tokens, QString *error) {
    const QString accessToken = tokens->value("access_token").toString();
    const qint64 expiresAt = tokens->value("expires_at").toInteger();
    if (!accessToken.isEmpty() && expiresAt > nowSeconds() + tokenRefreshSkewSeconds)
        return true;
    return refreshAccessToken(tokens, error);
}

bool GoogleProvider::fetchProfile(const QString &accessToken, QJsonObject *profile, QString *error) {
    const QJsonObject userInfo = getJson("https://www.googleapis.com/oauth2/v3/userinfo", accessToken, error);
    if (error && !error->isEmpty())
        return false;

    QJsonObject normalized;
    normalized.insert("displayName", userInfo.value("name").toString());
    normalized.insert("email", userInfo.value("email").toString());
    normalized.insert("avatar", cacheAvatar(userInfo.value("picture").toString(), error));
    normalized.insert("updatedAt", QDateTime::currentDateTime().toString(Qt::ISODate));
    if (error && !error->isEmpty())
        return false;

    if (profile)
        *profile = normalized;
    return true;
}

bool GoogleProvider::saveProfile(const QJsonObject &profile, QString *error) {
    return writeJsonFile(statePath(), profile, error);
}

bool GoogleProvider::loadProfile(QJsonObject *profile) const {
    QFile file(statePath());
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject())
        return false;
    if (profile)
        *profile = doc.object();
    return true;
}

void GoogleProvider::clearProfile() const {
    QFile::remove(statePath());
    QFile::remove(avatarCachePath());
}

QString GoogleProvider::cacheAvatar(const QString &avatarUrl, QString *error) {
    if (avatarUrl.isEmpty())
        return {};

    const QByteArray bytes = getBytes(avatarUrl, error);
    if (!error->isEmpty())
        return {};

    QDir().mkpath(QFileInfo(avatarCachePath()).absolutePath());
    QFile file(avatarCachePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        *error = file.errorString();
        return {};
    }
    file.write(bytes);
    return avatarCachePath();
}

QJsonObject GoogleProvider::postForm(const QString &url, const QVariantMap &form, QString *error) {
    if (error)
        error->clear();

    QUrlQuery query;
    for (auto it = form.constBegin(); it != form.constEnd(); ++it)
        query.addQueryItem(it.key(), it.value().toString());

    QNetworkRequest request{QUrl(url)};
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
    QNetworkReply *reply = network_.post(request, query.toString(QUrl::FullyEncoded).toUtf8());

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const QByteArray payload = reply->readAll();
    if (reply->error() != QNetworkReply::NoError) {
        const QJsonDocument errDoc = QJsonDocument::fromJson(payload);
        if (error) {
            const QJsonObject obj = errDoc.object();
            *error = obj.value("error_description").toString(obj.value("error").toString(reply->errorString()));
        }
        reply->deleteLater();
        return {};
    }
    reply->deleteLater();
    return QJsonDocument::fromJson(payload).object();
}

QJsonObject GoogleProvider::getJson(const QString &url, const QString &accessToken, QString *error) {
    if (error)
        error->clear();

    QNetworkRequest request{QUrl(url)};
    request.setRawHeader("Authorization", QByteArray("Bearer ") + accessToken.toUtf8());
    QNetworkReply *reply = network_.get(request);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const QByteArray payload = reply->readAll();
    if (reply->error() != QNetworkReply::NoError) {
        if (error)
            *error = reply->errorString();
        reply->deleteLater();
        return {};
    }
    reply->deleteLater();
    return QJsonDocument::fromJson(payload).object();
}

QByteArray GoogleProvider::getBytes(const QString &url, QString *error) {
    if (error)
        error->clear();

    QNetworkReply *reply = network_.get(QNetworkRequest(QUrl(url)));
    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const QByteArray payload = reply->readAll();
    if (reply->error() != QNetworkReply::NoError && error)
        *error = reply->errorString();
    reply->deleteLater();
    return payload;
}

QString GoogleProvider::configDir() const {
    return QDir::homePath() + "/.config/quickshell";
}

QString GoogleProvider::clientIdPath() const {
    return configDir() + "/accounts/google_client_id";
}

QString GoogleProvider::statePath() const {
    return QDir::homePath() + "/.local/state/reimagined/accounts/google-profile.json";
}

QString GoogleProvider::avatarCachePath() const {
    return QDir::homePath() + "/.cache/reimagined/accounts/google-avatar.jpg";
}

qint64 GoogleProvider::nowSeconds() const {
    return QDateTime::currentSecsSinceEpoch();
}
