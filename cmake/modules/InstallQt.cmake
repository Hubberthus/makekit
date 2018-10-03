#
#    MIT License
#
#    Copyright (c) 2018 Celestin de Villa
#
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.
#

#
# Qt
# Precondition: The MK_QT_DIR environmental variable must be set to a valid Qt path.
# http://doc.qt.io/qt-5/qtmodules.html
# http://doc.qt.io/qt-5/cmake-manual.html#imported-targets
#

include(BundleUtilities)
include(GetPrerequisites)
#include($ENV{MK_DIR}/cmake/mk.cmake)

cmake_minimum_required(VERSION 3.12 FATAL_ERROR)

if (WIN32)
    set(CMAKE_SHARED_LIBRARY_SUFFIX .dll)
    set(BUNDLE_DIR "${CMAKE_INSTALL_PREFIX}")
    set(BUNDLE_CONF_DIR ".")
    set(BUNDLE_PLUGINS_DIR ".")
elseif (APPLE)
    set(CMAKE_SHARED_LIBRARY_SUFFIX .dylib)
    set(BUNDLE_DIR "${CMAKE_INSTALL_PREFIX}/${TARGET_NAME}.app/Contents")
    set(BUNDLE_CONF_DIR "Resources")
    set(BUNDLE_PLUGINS_DIR "PlugIns")
elseif (UNIX)
    set(CMAKE_SHARED_LIBRARY_SUFFIX .so)
    set(BUNDLE_DIR "${CMAKE_INSTALL_PREFIX}")
    set(BUNDLE_CONF_DIR ".")
    set(BUNDLE_PLUGINS_DIR "plugins")
else ()
    message(FATAL_ERROR "Unsupported OS")
endif ()

function(mk_install_Qt_conf TARGET_NAME)

    set(CONF ${ARGV1})

    message(STATUS "Install Qt conf file: ${BUNDLE_DIR}/${BUNDLE_CONF_DIR}/qt.conf")

    if (MK_OS_WINDOWS)
        set(CONF_DIR ${CMAKE_INSTALL_PREFIX}/.)
    elseif (MK_OS_MACOS)
        set(CONF_DIR ${CMAKE_INSTALL_PREFIX}/${TARGET_NAME}.app/Contents/Resources)
    elseif (MK_OS_LINUX)
        set(CONF_DIR ${CMAKE_INSTALL_PREFIX}/.)
    endif ()

    if (EXISTS "${CONF}")
        file(COPY ${CONF} DESTINATION ${BUNDLE_DIR}/${BUNDLE_CONF_DIR})
    else () # Write default qt.conf file
        if (MK_OS_WINDOWS)
            set(CONF "[Paths]\nPlugins = ${BUNDLE_CONF_DIR}\nImports = qml\nQml2Imports = qml")
        elseif(MK_OS_MACOS)
            set(CONF "[Paths]\nPlugins = ${BUNDLE_CONF_DIR}\nImports = Resources/qml\nQml2Imports = Resources/qml")
        elseif(MK_OS_LINUX)
            set(CONF "[Paths]\nPlugins = ${BUNDLE_CONF_DIR}\nImports = qml\nQml2Imports = qml\nPrefix = ../")
        endif()

        file(WRITE ${BUNDLE_DIR}/${BUNDLE_CONF_DIR}/qt.conf "${CONF}")
    endif ()

endfunction()

macro(mk_collect_plugins VAR GROUP)

    file(GLOB_RECURSE ${VAR} "$ENV{MK_QT_DIR}/plugins/${GROUP}/*${CMAKE_SHARED_LIBRARY_SUFFIX}")
    list(APPEND QT_PLUGINS "${BEARER_PLUGINS}")

    # EXCLUDE PATTERN
    if (NOT ${ARGV2} STREQUAL "")
        list(FILTER ${VAR} EXCLUDE REGEX ${ARGV2})
    endif ()

endmacro()

function(mk_install_Qt_plugin)

endfunction()

macro(mk_append_unique LIST VALUE)

    if (NOT ${VALUE} IN_LIST ${LIST})
        set(${LIST} ${LIST} ${VALUE} ${ARGV2})
    endif ()

endmacro()

function(mk_install_Qt_plugin_module TARGET_NAME PLUGIN_MODULE)

    set(MODULES_SRC_DIR "$ENV{MK_QT_DIR}/lib")
    set(PLUGINS_SRC_DIR "$ENV{MK_QT_DIR}/plugins")

    set(TARGET_EXECUTABLE_FILE ${CMAKE_INSTALL_PREFIX}/${TARGET_NAME}.app/Contents/MacOS/${TARGET_NAME})

    #get_bundle_and_exeutable(<app> <bundle_var> <executable_var> TARGET_IS_VALID)

    # Collect all libraries in the module directory
    file(GLOB ${PLUGIN_MODULE}_FILES FOLLOW_SYMLINKS "${PLUGINS_SRC_DIR}/${PLUGIN_MODULE}/*${CMAKE_SHARED_LIBRARY_SUFFIX}")

    # Filter plugin libraries

    # TODO handle debug/release configs
    set(IS_DEBUG 0)

    if (0)
        set(FILTER_MODE INCLUDE)
    else ()
        set(FILTER_MODE EXCLUDE)
    endif ()

    # Include shared (runtime) library files only
    list(FILTER ${PLUGIN_MODULE}_FILES INCLUDE REGEX "^.*\\${CMAKE_SHARED_LIBRARY_SUFFIX}$")
    # Include/exclude debug libraries
    list(FILTER ${PLUGIN_MODULE}_FILES ${FILTER_MODE} REGEX "^.*_debug\\${CMAKE_SHARED_LIBRARY_SUFFIX}$")

    if ("${${PLUGIN_MODULE}_FILES}" STREQUAL "")
        return()
    endif ()

    #message(STATUS "${PLUGIN_MODULE}")

    # Get and accumulate dependencies of plugin files

    foreach(PLUGIN IN LISTS ${PLUGIN_MODULE}_FILES)

        get_prerequisites(${PLUGIN} PLUGIN_DEPENDENCIES 1 0 "" ${MODULES_SRC_DIR})

        #message(STATUS "Dependencies of ${PLUGIN}: ${PLUGIN_DEPENDENCIES}")

        foreach(PLUGIN_DEPENDENCY IN LISTS PLUGIN_DEPENDENCIES)

            get_item_key(${PLUGIN_DEPENDENCY} PLUGIN_DEPENDENCY_KEY)

            # Resolve item (gp_resolve_item) and set key values
            #gp_resolve_item(${PLUGIN} ${PLUGIN_DEPENDENCY} "" ${MODULES_SRC_DIR} RESOLVED_PLUGIN_DEPENDENCY)
            get_filename_component(TARGET_EXECUTABLE_DIR "${TARGET_EXECUTABLE_FILE}" DIRECTORY)
            set_bundle_key_values(MODULE_DEPENDENCY_KEYS ${PLUGIN_DEPENDENCY} ${PLUGIN_DEPENDENCY} ${TARGET_EXECUTABLE_DIR} ${MODULES_SRC_DIR} 1)

        endforeach()

        # Install plugin module files

        get_filename_component(PLUGIN_NAME ${PLUGIN} NAME)
        copy_resolved_item_into_bundle(${PLUGIN} "${BUNDLE_DIR}/${BUNDLE_PLUGINS_DIR}/${PLUGIN_MODULE}/${PLUGIN_NAME}")
        #file(COPY ${${PLUGIN_MODULE}_FILES} DESTINATION "${BUNDLE_DIR}/${BUNDLE_PLUGINS_DIR}/${PLUGIN_MODULE}/.")

    endforeach()

    # Copy accumulated dependecies of the plugin module

    foreach(KEY IN LISTS MODULE_DEPENDENCY_KEYS)

        if (NOT ${KEY} IN_LIST BUNDLE_QT_MODULES)
        set(BUNDLE_QT_MODULES ${BUNDLE_QT_MODULES} ${KEY} CACHE INTERNAL "" FORCE)
        endif()

    endforeach()

    if (NOT ${PLUGIN_MODULE} IN_LIST BUNDLE_QT_PLUGIN_MODULES)
        set(BUNDLE_QT_PLUGIN_MODULES ${BUNDLE_QT_PLUGIN_MODULES} ${PLUGIN_MODULE} CACHE INTERNAL "" FORCE)
    endif ()

    file(GLOB_RECURSE EMBEDDED_PLUGINS "${BUNDLE_DIR}/${BUNDLE_PLUGINS_DIR}/${PLUGIN_MODULE}/*${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(BUNDLE_QT_PLUGINS ${BUNDLE_QT_PLUGINS} ${EMBEDDED_PLUGINS} CACHE INTERNAL "" FORCE)

endfunction()

function(mk_install_Qt_plugins TARGET_NAME)

    set(MODULES_SRC_DIR "$ENV{MK_QT_DIR}/lib")
    set(TARGET_EXECUTABLE_FILE ${CMAKE_INSTALL_PREFIX}/${TARGET_NAME}.app/Contents/MacOS/${TARGET_NAME})

    set(BUNDLE_QT_MODULES "" CACHE INTERNAL "" FORCE)
    set(BUNDLE_QT_PLUGINS "" CACHE INTERNAL "" FORCE)
    set(BUNDLE_QT_PLUGIN_MODULES "" CACHE INTERNAL "" FORCE)

    # Get list of unresolved prerequisites of the target executable

    get_prerequisites(${TARGET_EXECUTABLE_FILE} TARGET_DEPENDENCIES 1 0 "" ${MODULES_SRC_DIR})

    # Collect Qt prerequisites as list of module names

    foreach (TARGET_DEPENDENCY IN LISTS TARGET_DEPENDENCIES)
    get_filename_component(LIBRARY_NAME ${TARGET_DEPENDENCY} NAME_WE)

    if (${LIBRARY_NAME} MATCHES "^Qt.*")
    set(BUNDLE_QT_MODULES ${BUNDLE_QT_MODULES} ${LIBRARY_NAME} CACHE INTERNAL "" FORCE)
    endif ()
    endforeach ()

    message(STATUS "Install Qt plugins...")

    # Handle Qt prerequisites

    list(LENGTH BUNDLE_QT_MODULES BUNDLE_QT_MODULES_LENGTH)
    math(EXPR INDEX 0)

    while (INDEX LESS BUNDLE_QT_MODULES_LENGTH)

        list(GET BUNDLE_QT_MODULES ${INDEX} LIBRARY_NAME)

        #message(STATUS "Prerequisite plugins of ${LIBRARY_NAME}: ")

        set(PLUGIN_SRC_DIRS "")

        if (${LIBRARY_NAME} MATCHES "QtCore")
            list(APPEND PLUGIN_SRC_DIRS platforms)
        elseif (${LIBRARY_NAME} MATCHES "QtDeclarative")
            list(APPEND PLUGIN_SRC_DIRS qml1tooling)
        elseif (${LIBRARY_NAME} MATCHES "QtGamePad")
            list(APPEND PLUGIN_SRC_DIRS gamepads)
        elseif (${LIBRARY_NAME} MATCHES "QtGui")
            list(APPEND PLUGIN_SRC_DIRS accessible iconengines imageformats platforms platforminputcontexts)
        elseif (${LIBRARY_NAME} MATCHES "QtLocation")
            list(APPEND PLUGIN_SRC_DIRS geoservices)
        elseif (${LIBRARY_NAME} MATCHES "QtMultimedia")
            list(APPEND PLUGIN_SRC_DIRS audio mediaservice playlistformats)
        elseif (${LIBRARY_NAME} MATCHES "QtNetwork")
            list(APPEND PLUGIN_SRC_DIRS bearer)
        elseif (${LIBRARY_NAME} MATCHES "QtPositioning")
            list(APPEND PLUGIN_SRC_DIRS position)
        elseif (${LIBRARY_NAME} MATCHES "QtPrintSupport")
            list(APPEND PLUGIN_SRC_DIRS printsupport)
        elseif (${LIBRARY_NAME} MATCHES "QtQuick")
            list(APPEND PLUGIN_SRC_DIRS qmltooling scenegraph)
        elseif (${LIBRARY_NAME} MATCHES "QtQmlTooling")
            list(APPEND PLUGIN_SRC_DIRS scenegraph)
        elseif (${LIBRARY_NAME} MATCHES "QtSensors")
            list(APPEND PLUGIN_SRC_DIRS sensors sensorgestures)
        elseif (${LIBRARY_NAME} MATCHES "QtSerialBus")
            list(APPEND PLUGIN_SRC_DIRS canbus)
        elseif (${LIBRARY_NAME} MATCHES "QtSql")
            list(APPEND PLUGIN_SRC_DIRS sqldrivers)
        elseif (${LIBRARY_NAME} MATCHES "QtTextToSpeech")
            list(APPEND PLUGIN_SRC_DIRS texttospeech)
        elseif (${LIBRARY_NAME} MATCHES "QtWebEngine")
            list(APPEND PLUGIN_SRC_DIRS qtwebengine)
        elseif (${LIBRARY_NAME} MATCHES "QtWebEngineCore")
            list(APPEND PLUGIN_SRC_DIRS qtwebengine)
        elseif (${LIBRARY_NAME} MATCHES "QtWebEngineWidgets")
            list(APPEND PLUGIN_SRC_DIRS qtwebengine)
        elseif (${LIBRARY_NAME} MATCHES "QtQt5::WebView")
            list(APPEND PLUGIN_SRC_DIRS webview)
        elseif (${LIBRARY_NAME} MATCHES "QtWidgets")
            list(APPEND PLUGIN_SRC_DIRS styles)
        elseif (${LIBRARY_NAME} MATCHES "Qt3DRenderer")
            list(APPEND PLUGIN_SRC_DIRS geometryloaders renderplugins sceneparsers)
        endif ()

        # Install required Qt plugins for the current module
        foreach (PLUGIN_SRC_DIR IN LISTS PLUGIN_SRC_DIRS)

            if (NOT ${PLUGIN_SRC_DIR} IN_LIST BUNDLE_QT_PLUGIN_MODULES)
                mk_install_Qt_plugin_module(${TARGET_NAME} ${PLUGIN_SRC_DIR})
            endif ()

        endforeach ()

        # Update loop condition variables

        list(LENGTH BUNDLE_QT_MODULES BUNDLE_QT_MODULES_LENGTH)
        math(EXPR INDEX ${INDEX}+1)

    endwhile()

    # Print install info

    list(SORT BUNDLE_QT_PLUGIN_MODULES)
    list(SORT BUNDLE_QT_MODULES)

    message(STATUS "Installed Qt modules: ${BUNDLE_QT_MODULES}")
    message(STATUS "Installed Qt plugin modules: ${BUNDLE_QT_PLUGIN_MODULES}")

endfunction()

function(mk_install_Qt TARGET_NAME INSTALLED_QT_PLUGIN_FILES)

    mk_install_Qt_conf(${TARGET_NAME})
    mk_install_Qt_plugins(${TARGET_NAME} INSTALLED_QT_PLUGIN_FILES)

endfunction()
