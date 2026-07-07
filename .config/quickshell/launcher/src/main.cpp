#include "AppDiscovery.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QTextStream>

namespace {
struct Options {
    QString command = "list";
    QString cachePath;
};

Options parseOptions(const QStringList &arguments) {
    Options options;

    for (int i = 1; i < arguments.size(); ++i) {
        const QString &argument = arguments.at(i);
        if (argument == "--cache" && i + 1 < arguments.size()) {
            options.cachePath = arguments.at(++i);
        } else if (!argument.startsWith("-")) {
            options.command = argument;
        }
    }

    return options;
}

void printStdout(const QString &value) {
    QTextStream(stdout) << value << Qt::endl;
}

void printStderr(const QString &value) {
    QTextStream(stderr) << value << Qt::endl;
}
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QCoreApplication::setOrganizationName("Reimagined");
    QCoreApplication::setApplicationName("ReimaginedLauncherCtl");

    const Options options = parseOptions(app.arguments());
    AppDiscovery discovery;

    if (options.command == "fingerprint") {
        printStdout(discovery.fingerprint());
        return 0;
    }

    if (options.command != "list") {
        printStderr(QString("Unknown launcher command: %1").arg(options.command));
        return 2;
    }

    const QJsonArray apps = discovery.applications();
    QString cacheError;
    if (!discovery.writeCache(options.cachePath, apps, &cacheError)) {
        printStderr(QString("Could not update app cache: %1").arg(cacheError));
    }

    printStdout(QString::fromUtf8(QJsonDocument(apps).toJson(QJsonDocument::Compact)));
    return 0;
}
