#include "IconResolver.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>

namespace {
QString homePath(const QString &relativePath) {
    return QDir::home().filePath(relativePath);
}

const QStringList iconThemes = {
    "hicolor",
    "Adwaita",
    "Papirus",
    "Tela-circle-green",
    "Tela-circle",
};

const QStringList iconDirs = {
    "/usr/share/icons",
    homePath(".local/share/icons"),
    "/usr/local/share/icons",
    "/var/lib/flatpak/exports/share/icons",
    homePath(".local/share/flatpak/exports/share/icons"),
};

const QStringList pixmapDirs = {
    "/usr/share/pixmaps",
    "/usr/local/share/pixmaps",
};

const QStringList iconSizes = {
    "scalable",
    "256x256",
    "128x128",
    "64x64",
    "48x48",
    "32x32",
    "24x24",
    "22x22",
};

const QStringList iconCategories = {
    "apps",
    "actions",
    "devices",
    "places",
    "status",
    "mimetypes",
};

const QStringList iconExtensions = {
    ".svg",
    ".png",
    ".xpm",
};

bool isSupportedIcon(const QString &fileName) {
    for (const QString &extension : iconExtensions) {
        if (fileName.endsWith(extension)) {
            return true;
        }
    }
    return false;
}
}

QString IconResolver::resolve(const QString &iconName) {
    if (iconName.isEmpty()) {
        return {};
    }

    const QFileInfo explicitPath(iconName);
    if (explicitPath.isAbsolute() && explicitPath.isFile()) {
        return explicitPath.absoluteFilePath();
    }

    const QString directPath = findInKnownLocations(iconName);
    if (!directPath.isEmpty()) {
        return directPath;
    }

    buildIndex();
    return m_iconIndex.value(iconName);
}

QString IconResolver::findInKnownLocations(const QString &iconName) const {
    for (const QString &theme : iconThemes) {
        for (const QString &baseDir : iconDirs) {
            const QDir themeDir(QDir(baseDir).filePath(theme));
            if (!themeDir.exists()) {
                continue;
            }

            for (const QString &size : iconSizes) {
                for (const QString &category : iconCategories) {
                    const QDir iconDir(themeDir.filePath(size + "/" + category));
                    for (const QString &extension : iconExtensions) {
                        const QString path = iconDir.filePath(iconName + extension);
                        if (QFileInfo::exists(path)) {
                            return path;
                        }
                    }
                }
            }
        }
    }

    for (const QString &baseDir : pixmapDirs) {
        const QDir dir(baseDir);
        for (const QString &extension : iconExtensions) {
            const QString path = dir.filePath(iconName + extension);
            if (QFileInfo::exists(path)) {
                return path;
            }
        }
    }

    return {};
}

void IconResolver::buildIndex() {
    if (m_indexBuilt) {
        return;
    }

    for (const QString &baseDir : iconDirs) {
        if (!QDir(baseDir).exists()) {
            continue;
        }

        QDirIterator iterator(baseDir, QDir::Files, QDirIterator::Subdirectories);
        while (iterator.hasNext()) {
            const QString path = iterator.next();
            const QFileInfo fileInfo(path);
            if (!isSupportedIcon(fileInfo.fileName())) {
                continue;
            }

            const QString stem = fileInfo.completeBaseName();
            if (!m_iconIndex.contains(stem)) {
                m_iconIndex.insert(stem, fileInfo.absoluteFilePath());
            }
        }
    }

    m_indexBuilt = true;
}
