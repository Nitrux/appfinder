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
include(FeatureSummary)

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Qml Quick Widgets)
find_package(MauiKit4 4.0.4 REQUIRED)

add_subdirectory(src)

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
