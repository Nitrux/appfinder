cmake_minimum_required(VERSION 3.20)

project(appfinder VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CheckCXXCompilerFlag)
if(NOT CMAKE_CROSSCOMPILING)
    string(TOLOWER "${CMAKE_HOST_SYSTEM_PROCESSOR}" _host_processor)
    if(_host_processor MATCHES "^(x86_64|amd64)$")
        check_cxx_compiler_flag("-march=x86-64-v3" APPFINDER_HAS_X86_64_V3)
        if(APPFINDER_HAS_X86_64_V3)
            add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-march=x86-64-v3>)
        endif()
    endif()
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
kde_enable_exceptions()
include(FeatureSummary)
include(CTest)
include(ECMSourceVersionControl)

if(ECM_SOURCE_UNDER_VERSION_CONTROL)
    execute_process(
        COMMAND git rev-parse --abbrev-ref HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_BRANCH
        OUTPUT_STRIP_TRAILING_WHITESPACE)

    execute_process(
        COMMAND git rev-parse --short HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE)

    if(NOT "$ENV{GITHUB_HEAD_REF}" STREQUAL "")
        set(GIT_BRANCH "$ENV{GITHUB_HEAD_REF}")
    elseif(NOT "$ENV{GITHUB_REF_NAME}" STREQUAL "")
        set(GIT_BRANCH "$ENV{GITHUB_REF_NAME}")
    endif()
elseif(NOT "$ENV{GITHUB_REF_NAME}" STREQUAL "" AND NOT "$ENV{GITHUB_SHA}" STREQUAL "")
    if(NOT "$ENV{GITHUB_HEAD_REF}" STREQUAL "")
        set(GIT_BRANCH "$ENV{GITHUB_HEAD_REF}")
    else()
        set(GIT_BRANCH "$ENV{GITHUB_REF_NAME}")
    endif()
    string(SUBSTRING "$ENV{GITHUB_SHA}" 0 7 GIT_COMMIT_HASH)
else()
    set(GIT_BRANCH "Stable")
    set(GIT_COMMIT_HASH "0.1.0")
endif()

if(GIT_COMMIT_HASH STREQUAL "" AND NOT "$ENV{GITHUB_SHA}" STREQUAL "")
    string(SUBSTRING "$ENV{GITHUB_SHA}" 0 7 GIT_COMMIT_HASH)
endif()

add_definitions(-DGIT_COMMIT_HASH="${GIT_COMMIT_HASH}")
add_definitions(-DGIT_BRANCH="${GIT_BRANCH}")

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Network Qml Quick Widgets)
find_package(KF6 6.13.0 REQUIRED COMPONENTS CoreAddons I18n)
find_package(MauiKit4 4.0.4 REQUIRED)
find_package(yaml-cpp REQUIRED)
if(BUILD_TESTING)
    find_package(Qt6 6.9 REQUIRED COMPONENTS Test)
endif()
if(TARGET yaml-cpp::yaml-cpp)
    set(APPFINDER_YAML_TARGET yaml-cpp::yaml-cpp)
else()
    set(APPFINDER_YAML_TARGET yaml-cpp)
endif()

qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

add_subdirectory(src)
if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

set(APPFINDER_DISTROBOX_HELPER_PATH "${CMAKE_INSTALL_FULL_LIBEXECDIR}/appfinder-distrobox-helper")
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/org.nitrux.appfinder.distrobox.policy.in"
    "${CMAKE_CURRENT_BINARY_DIR}/org.nitrux.appfinder.distrobox.policy"
    @ONLY)

install(FILES org.nitrux.appfinder.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES org.nitrux.appfinder.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/org.nitrux.appfinder.distrobox.policy"
        DESTINATION ${KDE_INSTALL_DATADIR}/polkit-1/actions)

if(NOT TARGET uninstall)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
        IMMEDIATE
        @ONLY)

    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake")
endif()

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)

set(CPACK_PACKAGE_NAME "appfinder")
set(CPACK_DEBIAN_PACKAGE_NAME "appfinder")
set(CPACK_PACKAGE_VENDOR "Nitrux Latinoamericana S.C.")
set(CPACK_PACKAGE_CONTACT "hello@nxos.org")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Software management for Nitrux")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "uri_herrera@nxos.org")
set(CPACK_DEBIAN_PACKAGE_SECTION "utils")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_DEPENDS " distrobox, libnotify-bin, libyaml-cpp0.9, mauikit (>= 4.0.4), flatpak, libpolkit-agent-1-0")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
include(CPack)
