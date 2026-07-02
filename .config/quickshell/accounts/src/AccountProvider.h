#pragma once

#include "ProviderState.h"

#include <functional>

class AccountProvider {
public:
    using ProgressCallback = std::function<void(const ProviderState &)>;

    virtual ~AccountProvider() = default;

    virtual QString id() const = 0;
    virtual ProviderState login(const ProgressCallback &progress) = 0;
    virtual ProviderState logout() = 0;
    virtual ProviderState state() = 0;
    virtual ProviderState refreshProfile() = 0;

    virtual bool isLoggedIn() = 0;
    virtual QString displayName() = 0;
    virtual QString avatar() = 0;
    virtual QString email() = 0;
};
