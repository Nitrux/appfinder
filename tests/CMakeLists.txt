qt_add_executable(userbundlestoretest
    userbundlestoretest.cpp
    ../src/controllers/userbundlestore.cpp
    ../src/controllers/userbundlestore.h
    ../src/controllers/apphubbackend.cpp
    ../src/controllers/apphubbackend.h
    ../src/models/appmodel.cpp
    ../src/models/appmodel.h
)

target_link_libraries(userbundlestoretest
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Test
        ${APPFINDER_YAML_TARGET}
)

add_test(NAME userbundlestoretest COMMAND userbundlestoretest)
