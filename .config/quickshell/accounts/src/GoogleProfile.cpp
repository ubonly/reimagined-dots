#include "GoogleProfile.h"

bool GoogleProfile::isValid() const {
    return !displayName.trimmed().isEmpty() || !email.trimmed().isEmpty();
}

QJsonObject GoogleProfile::toJson() const {
    return {
        {"displayName", displayName},
        {"email", email},
        {"avatar", avatar},
        {"updatedAt", updatedAt},
    };
}

GoogleProfile GoogleProfile::fromJson(const QJsonObject &object) {
    GoogleProfile profile;
    profile.displayName = object.value("displayName").toString();
    profile.email = object.value("email").toString();
    profile.avatar = object.value("avatar").toString();
    profile.updatedAt = object.value("updatedAt").toString();
    return profile;
}
