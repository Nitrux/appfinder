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

install(FILES org.nitrux.appfinder.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES org.nitrux.appfinder.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})

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
set(CPACK_DEBIAN_PACKAGE_DEPENDS " distrobox, libyaml-cpp0.9, mauikit (>= 4.0.4), nx-apphub-cli, qml6-module-qtcore, qml6-module-qtquick-controls, qml6-module-qtquick-layouts,flatpak")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
include(CPack)
