#pragma once

#include "AccountProvider.h"
#include "GoogleAccountProvider.h"

#include <QStringList>

class AccountManager {
public:
    ProviderState dispatch(const QStringList &arguments, const AccountProvider::ProgressCallback &progress);

private:
    GoogleAccountProvider google_;
};
