set(APPFINDER_SOURCES
    main.cpp
    models/appmodel.cpp
    models/appmodel.h
    controllers/apphubbackend.cpp
    controllers/apphubbackend.h
)

qt_add_executable(${PROJECT_NAME}
    MANUAL_FINALIZATION
    ${APPFINDER_SOURCES}
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

qt_add_qml_module(${PROJECT_NAME}
    URI org.nitrux.appfinder
    NO_PLUGIN
    NO_IMPORT_SCAN
    RESOURCE_PREFIX /
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/SourcePage.qml
        qml/NavigationSidebar.qml
        qml/SettingsDialog.qml
        qml/FlathubPage.qml
        qml/AppHubPage.qml
        qml/DistroboxPage.qml
)

target_link_libraries(${PROJECT_NAME}
    PRIVATE
        MauiKit4
        KF6::CoreAddons
        KF6::I18n
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Qml
        Qt6::Quick
        Qt6::Widgets
)

install(TARGETS ${PROJECT_NAME} ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})

qt_finalize_executable(${PROJECT_NAME})
