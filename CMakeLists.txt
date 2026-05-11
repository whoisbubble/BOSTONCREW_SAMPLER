cmake_minimum_required(VERSION 3.16)

project(CPlusEventSampler VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC_COMPILER_PREDEFINES OFF)

set(MACOS_APP_ICON "" CACHE FILEPATH "Path to a macOS .icns bundle icon")
set(APP_DISPLAY_NAME "BOSTONCREW SAMPLER")
set(APP_EXECUTABLE_NAME "BOSTONCREW-SAMPLER")
set(APP_BUNDLE_ID "ru.bostoncrew.sampler")
set(APP_COPYRIGHT "Copyright (c) 2026 BOSTONCREW")

if(APPLE AND NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS deployment target" FORCE)
endif()

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Multimedia Network Widgets Test)

qt_standard_project_setup(REQUIRES 6.10)

set(APP_ICON_RESOURCE_WINDOWS "")
if(WIN32)
    set(APP_ICON_RESOURCE_WINDOWS "${CMAKE_CURRENT_SOURCE_DIR}/app_icon.rc")
endif()

set(APP_ICON_RESOURCE_MACOS "")
if(APPLE AND MACOS_APP_ICON AND EXISTS "${MACOS_APP_ICON}")
    set(APP_ICON_RESOURCE_MACOS "${MACOS_APP_ICON}")
    set_source_files_properties("${APP_ICON_RESOURCE_MACOS}" PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources"
    )
endif()

if(APPLE)
    configure_file(cmake/Info.plist.in "${CMAKE_CURRENT_BINARY_DIR}/Info.plist" @ONLY)
endif()

qt_add_executable(appCPlusEventSampler
    main.cpp
    LicenseManager.h
    LicenseManager.cpp
    SamplerBackend.h
    SamplerBackend.cpp
    ${APP_ICON_RESOURCE_WINDOWS}
    ${APP_ICON_RESOURCE_MACOS}
)

set_source_files_properties(AppTheme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(appCPlusEventSampler
    URI CPlusEventSampler
    QML_FILES
        AppCheckBox.qml
        AppIcon.qml
        AppModalOverlay.qml
        AppPanel.qml
        AppSwitch.qml
        AppTextField.qml
        AppTheme.qml
        AssignSlidePopup.qml
        ChromeButton.qml
        DashboardView.qml
        EditWorkspace.qml
        HostInfoWindow.qml
        HostPopup.qml
        HelpPopup.qml
        IconButton.qml
        LicenseGate.qml
        Main.qml
        PreviewWorkspace.qml
        PreviewSelectWindow.qml
        QuickSlotsPanel.qml
        RemoteWindow.qml
        SampleDialog.qml
        SampleManager.qml
        SamplesConsole.qml
        SamplesStrip.qml
        SlideDialog.qml
        SlideLibrary.qml
        SlideManagerWindow.qml
        StagePanel.qml
        StageWindow.qml
        TextButton.qml
        TimerWindow.qml
        TitleBar.qml
        WindowResizeHandle.qml
)

qt_add_resources(appCPlusEventSampler app_resources
    PREFIX "/"
    FILES
        assets/app_icon.png
        assets/icons/cue.svg
        assets/icons/host.svg
        assets/icons/next.svg
        assets/icons/pause.svg
        assets/icons/play.svg
        assets/icons/plus.svg
        assets/icons/prev.svg
        assets/icons/remote.svg
        assets/icons/settings.svg
        assets/icons/slides.svg
        assets/icons/stop.svg
        assets/icons/thumb-down.svg
        assets/icons/thumb-up.svg
        assets/icons/timer.svg
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appCPlusEventSampler PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER ${APP_BUNDLE_ID}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

if(APPLE)
    set_target_properties(appCPlusEventSampler PROPERTIES
        OUTPUT_NAME ${APP_EXECUTABLE_NAME}
        MACOSX_BUNDLE_BUNDLE_NAME ${APP_DISPLAY_NAME}
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
    )
    if(APP_ICON_RESOURCE_MACOS)
        set_target_properties(appCPlusEventSampler PROPERTIES
            MACOSX_BUNDLE_ICON_FILE "app_icon.icns"
        )
    endif()
endif()

target_link_libraries(appCPlusEventSampler
    PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Multimedia Qt6::Network Qt6::Widgets
)

if(WIN32)
    target_link_libraries(appCPlusEventSampler PRIVATE shell32)
endif()

install(TARGETS appCPlusEventSampler
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

enable_testing()

qt_add_executable(license_manager_tests
    tests/LicenseManagerTests.cpp
    LicenseManager.h
    LicenseManager.cpp
)

target_link_libraries(license_manager_tests
    PRIVATE Qt6::Core Qt6::Network Qt6::Test
)

set_target_properties(license_manager_tests PROPERTIES
    WIN32_EXECUTABLE FALSE
)

add_test(NAME license_manager_tests COMMAND license_manager_tests)
