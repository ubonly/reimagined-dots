cmake_minimum_required(VERSION 3.20)

project(ReimaginedAccounts LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS Core Network)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBSECRET REQUIRED IMPORTED_TARGET libsecret-1)

add_executable(accountctl
    src/main.cpp
    src/GoogleProvider.cpp
    src/SecretStore.cpp
)

target_include_directories(accountctl PRIVATE src)
target_link_libraries(accountctl PRIVATE Qt6::Core Qt6::Network PkgConfig::LIBSECRET)

if(DEFINED REIMAGINED_GOOGLE_CLIENT_ID)
    target_compile_definitions(accountctl PRIVATE REIMAGINED_GOOGLE_CLIENT_ID="${REIMAGINED_GOOGLE_CLIENT_ID}")
endif()
