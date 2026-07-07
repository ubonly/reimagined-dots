#include "AppDiscovery.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QSaveFile>
#include <QSet>
#include <QTextStream>

namespace {
QString homePath(const QString &relativePath) {
    return QDir::home().filePath(relativePath);
}

const QStringList execFieldCodes = {
    "%u",
    "%U",
    "%f",
    "%F",
    "%d",
    "%D",
    "%n",
    "%N",
    "%i",
    "%c",
    "%k",
    "%v",
    "%m",
};
}

AppDiscovery::AppDiscovery() = default;

QJsonArray AppDiscovery::applications() {
    QJsonArray result;
    QSet<QString> seen;

    for (const QString &path : desktopFiles()) {
        DesktopEntry entry = readDesktopEntry(path);
        if (!entry.isValid()) {
            continue;
        }

        const QString dedupKey = entry.name + "\n" + entry.exec;
        if (seen.contains(dedupKey)) {
            continue;
        }

        seen.insert(dedupKey);
        result.append(entry.toJson());
    }

    return result;
}

QString AppDiscovery::fingerprint() const {
    QStringList items;
    for (const QString &path : desktopFiles()) {
        const QFileInfo fileInfo(path);
        if (fileInfo.exists()) {
            items.append(QString("%1:%2:%3")
                             .arg(path)
                             .arg(fileInfo.lastModified().toMSecsSinceEpoch())
                             .arg(fileInfo.size()));
        } else {
            items.append(path + ":missing");
        }
    }
    return items.join("|");
}

bool AppDiscovery::writeCache(const QString &cachePath, const QJsonArray &apps, QString *error) const {
    if (cachePath.isEmpty()) {
        return true;
    }

    QSaveFile file(cachePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error) {
            *error = file.errorString();
        }
        return false;
    }

    file.write(QJsonDocument(apps).toJson(QJsonDocument::Compact));
    if (!file.commit()) {
        if (error) {
            *error = file.errorString();
        }
        return false;
    }

    return true;
}

QStringList AppDiscovery::desktopDirectories() const {
    return {
        "/usr/share/applications",
        homePath(".local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        homePath(".local/share/flatpak/exports/share/applications"),
        "/var/lib/snapd/desktop/applications",
        "/usr/local/share/applications",
    };
}

QStringList AppDiscovery::desktopFiles() const {
    QStringList files;

    for (const QString &directoryPath : desktopDirectories()) {
        const QDir directory(directoryPath);
        if (!directory.exists()) {
            continue;
        }

        const QFileInfoList entries = directory.entryInfoList({"*.desktop"}, QDir::Files, QDir::Name);
        for (const QFileInfo &entry : entries) {
            files.append(entry.absoluteFilePath());
        }
    }

    return files;
}

DesktopEntry AppDiscovery::readDesktopEntry(const QString &path) {
    DesktopEntry entry;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return entry;
    }

    QTextStream stream(&file);
    bool inDesktopEntry = false;

    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        if (line.isEmpty() || line.startsWith("#")) {
            continue;
        }

        if (line.startsWith("[")) {
            inDesktopEntry = line == "[Desktop Entry]";
            continue;
        }

        if (!inDesktopEntry) {
            continue;
        }

        const qsizetype separator = line.indexOf("=");
        if (separator <= 0) {
            continue;
        }

        const QString key = line.left(separator).trimmed();
        const QString value = line.mid(separator + 1).trimmed();

        if (key == "Type" && value != "Application") {
            return {};
        }
        if ((key == "NoDisplay" || key == "Hidden") && value.compare("true", Qt::CaseInsensitive) == 0) {
            return {};
        }

        readDesktopField(entry, key, value);
    }

    if (!entry.isValid()) {
        return {};
    }

    if (entry.icon.isEmpty()) {
        entry.icon = "application-x-executable";
    }
    entry.iconPath = m_iconResolver.resolve(entry.icon);
    entry.desktopId = QFileInfo(path).fileName();
    return entry;
}

void AppDiscovery::readDesktopField(DesktopEntry &entry, const QString &key, const QString &value) const {
    if (key == "Name" && entry.name.isEmpty()) {
        entry.name = value;
    } else if (key == "GenericName" && entry.genericName.isEmpty()) {
        entry.genericName = value;
    } else if (key == "Comment" && entry.comment.isEmpty()) {
        entry.comment = value;
    } else if (key == "Keywords" && entry.keywords.isEmpty()) {
        entry.keywords = QString(value).replace(";", " ");
    } else if (key == "Categories" && entry.categories.isEmpty()) {
        entry.categories = QString(value).replace(";", " ");
    } else if (key == "Icon" && entry.icon.isEmpty()) {
        entry.icon = value;
    } else if (key == "Exec" && entry.exec.isEmpty()) {
        entry.exec = cleanExec(value);
    }
}

QString AppDiscovery::cleanExec(QString value) const {
    for (const QString &fieldCode : execFieldCodes) {
        value.replace(fieldCode, "");
    }
    return value.trimmed();
}
