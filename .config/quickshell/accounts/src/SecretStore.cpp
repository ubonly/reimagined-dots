#include "SecretStore.h"

#include <QJsonDocument>

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

void setError(QString *target, GError *error) {
    if (!target)
        return;
    *target = error ? QString::fromUtf8(error->message) : QString();
}
}

bool SecretStore::loadTokens(const QString &provider, QJsonObject *tokens, QString *error) {
    if (tokens)
        *tokens = {};

    GError *gerror = nullptr;
    gchar *secret = secret_password_lookup_sync(
        &accountSchema,
        nullptr,
        &gerror,
        "provider", provider.toUtf8().constData(),
        nullptr);

    if (gerror) {
        setError(error, gerror);
        g_error_free(gerror);
        return false;
    }

    if (!secret)
        return false;

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
        setError(error, gerror);
        g_error_free(gerror);
        return false;
    }

    return ok;
}

bool SecretStore::clearTokens(const QString &provider, QString *error) {
    GError *gerror = nullptr;
    const gboolean ok = secret_password_clear_sync(
        &accountSchema,
        nullptr,
        &gerror,
        "provider", provider.toUtf8().constData(),
        nullptr);

    if (gerror) {
        setError(error, gerror);
        g_error_free(gerror);
        return false;
    }

    return ok;
}
