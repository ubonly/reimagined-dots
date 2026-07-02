#pragma once

#include <QJsonObject>
#include <QString>

struct ProviderState {
    QString provider = "google";
    QString status = "not_connected";
    QString displayName;
    QString email;
    QString avatar;
    QString message;
    QString error;
    bool configured = false;
    bool loggedIn = false;
    bool busy = false;

    QJsonObject toJson() const {
        return {
            {"provider", provider},
            {"status", status},
            {"displayName", displayName},
            {"email", email},
            {"avatar", avatar},
            {"message", message},
            {"error", error},
            {"configured", configured},
            {"loggedIn", loggedIn},
            {"busy", busy},
        };
    }
};
