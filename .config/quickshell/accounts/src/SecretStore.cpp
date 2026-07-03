#include "SecretStore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>

#ifdef signals
#undef signals
#endif

#include <libsecret/secret.h>

namespace {
const SecretSchema accountSchema = {
    "io.github.ubonly.reimagined.Account",
    SECRET_SCHEMA_NONE,
    {
        {"provider", SECRET_SCHEMA_ATTRIBUTE_STRING},
        {nullptr, static_cast<SecretSchemaAttributeType>(0)},
    },
};

QString fallbackTokenPath(const QString &provider) {
    const QString base = QStandardPaths::writableLocation(QStandardPaths::StateLocation);
    const QString stateDir = base.isEmpty()
        ? QDir::homePath() + "/.local/state/ReimaginedAccountCtl"
        : base;
    return stateDir + "/accounts/" + provider + "-tokens.json";
}

bool loadFallbackTokens(const QString &provider, QJsonObject *tokens, QString *error) {
    QFile file(fallbackTokenPath(provider));
    if (!file.exists())
        return false;

    if (!file.open(QIODevice::ReadOnly)) {
        if (error)
            *error = file.errorString();
        return false;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject()) {
        if (error)
            *error = "Stored account token fallback payload is invalid.";
        return false;
    }

    if (tokens)
        *tokens = doc.object();
    return true;
}

bool saveFallbackTokens(const QString &provider, const QJsonObject &tokens, QString *error) {
    const QString path = fallbackTokenPath(provider);
    QDir().mkpath(QFileInfo(path).absolutePath());

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error)
            *error = file.errorString();
        return false;
    }

    file.write(QJsonDocument(tokens).toJson(QJsonDocument::Compact));
    if (!file.commit()) {
        if (error)
            *error = file.errorString();
        return false;
    }

    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return true;
}
}

bool SecretStore::loadTokens(const QString &provider, QJsonObject *tokens, QString *error) {
    if (tokens)
        *tokens = {};
    if (error)
        error->clear();

    GError *gerror = nullptr;
    gchar *secret = secret_password_lookup_sync(
        &accountSchema,
        nullptr,
        &gerror,
        "provider", provider.toUtf8().constData(),
        nullptr);

    if (gerror) {
        g_error_free(gerror);
        if (loadFallbackTokens(provider, tokens, nullptr))
            return true;
        return false;
    }

    if (!secret)
        return loadFallbackTokens(provider, tokens, error);

    const QJsonDocument doc = QJsonDocument::fromJson(QByteArray(secret));
    secret_password_free(secret);

    if (!doc.isObject()) {
        if (error)
            *error = "Stored account token payload is invalid.";
        return false;
    }

    if (tokens)
        *tokens = doc.object();
    return true;
}

bool SecretStore::saveTokens(const QString &provider, const QJsonObject &tokens, QString *error) {
    if (error)
        error->clear();

    const QByteArray payload = QJsonDocument(tokens).toJson(QJsonDocument::Compact);
    GError *gerror = nullptr;

    const gboolean ok = secret_password_store_sync(
        &accountSchema,
        SECRET_COLLECTION_DEFAULT,
        "Reimagined Google Account",
        payload.constData(),
        nullptr,
        &gerror,
        "provider", provider.toUtf8().constData(),
        nullptr);

    if (gerror) {
        const QString secretError = QString::fromUtf8(gerror->message);
        g_error_free(gerror);
        if (saveFallbackTokens(provider, tokens, error))
            return true;
        if (error && !secretError.isEmpty() && !error->isEmpty())
            *error = secretError + "; fallback failed: " + *error;
        else if (error && !secretError.isEmpty())
            *error = secretError;
        return false;
    }

    if (ok)
        QFile::remove(fallbackTokenPath(provider));

    return ok || saveFallbackTokens(provider, tokens, error);
}

bool SecretStore::clearTokens(const QString &provider, QString *error) {
    if (error)
        error->clear();

    GError *gerror = nullptr;
    const gboolean ok = secret_password_clear_sync(
        &accountSchema,
        nullptr,
        &gerror,
        "provider", provider.toUtf8().constData(),
        nullptr);

    if (gerror) {
        g_error_free(gerror);
        QFile::remove(fallbackTokenPath(provider));
        return true;
    }

    QFile::remove(fallbackTokenPath(provider));
    return ok;
}
