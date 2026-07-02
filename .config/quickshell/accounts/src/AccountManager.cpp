#include "AccountManager.h"

ProviderState AccountManager::dispatch(const QStringList &arguments, const AccountProvider::ProgressCallback &progress) {
    const QString command = arguments.size() > 1 ? arguments.at(1) : "status";

    if (command == "status")
        return google_.state();
    if (command == "login")
        return google_.login(progress);
    if (command == "logout")
        return google_.logout();
    if (command == "refresh")
        return google_.refreshProfile();
    if (command == "set-client-id")
        return google_.setClientId(arguments.size() > 2 ? arguments.at(2) : QString());

    ProviderState state;
    state.provider = "google";
    state.status = "error";
    state.error = "Unknown account command: " + command;
    return state;
}
