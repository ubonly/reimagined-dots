#include "GoogleProvider.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QTextStream>

namespace {
void printJson(const ProviderState &state) {
    QTextStream(stdout) << QString::fromUtf8(QJsonDocument(state.toJson()).toJson(QJsonDocument::Compact)) << Qt::endl;
}
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QCoreApplication::setOrganizationName("Reimagined");
    QCoreApplication::setApplicationName("ReimaginedAccountCtl");

    const QStringList args = app.arguments();
    const QString command = args.size() > 1 ? args.at(1) : "status";

    GoogleProvider google;
    ProviderState result;

    if (command == "status") {
        result = google.state();
    } else if (command == "login") {
        result = google.login([](const ProviderState &progress) {
            printJson(progress);
        });
    } else if (command == "logout") {
        result = google.logout();
    } else if (command == "refresh") {
        result = google.refreshProfile();
    } else if (command == "set-client-id") {
        result = google.setClientId(args.size() > 2 ? args.at(2) : QString());
    } else {
        result.provider = "google";
        result.status = "error";
        result.error = "Unknown account command: " + command;
    }

    printJson(result);
    return result.error.isEmpty() ? 0 : 1;
}
