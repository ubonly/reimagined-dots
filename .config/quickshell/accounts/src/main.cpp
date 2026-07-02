#include "AccountManager.h"

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

    AccountManager manager;
    const ProviderState result = manager.dispatch(app.arguments(), [](const ProviderState &progress) {
        printJson(progress);
    });

    printJson(result);
    return result.error.isEmpty() ? 0 : 1;
}
