#include "DesktopEntry.h"

bool DesktopEntry::isValid() const {
    return !name.isEmpty() && !exec.isEmpty();
}

QJsonObject DesktopEntry::toJson() const {
    QJsonObject object;
    object.insert("name", name);
    object.insert("exec", exec);
    object.insert("icon", icon);
    object.insert("iconPath", iconPath);
    object.insert("desktopId", desktopId);

    if (!genericName.isEmpty()) {
        object.insert("genericName", genericName);
    }
    if (!comment.isEmpty()) {
        object.insert("comment", comment);
    }
    if (!categories.isEmpty()) {
        object.insert("categories", categories);
    }
    if (!keywords.isEmpty()) {
        object.insert("keywords", keywords);
    }

    return object;
}
