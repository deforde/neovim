# BuildLuajit(TARGET targetname CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build luajit, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLuajit)
  cmake_parse_arguments(_luajit
    ""
    "TARGET"
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})
  if(NOT _luajit_CONFIGURE_COMMAND AND NOT _luajit_BUILD_COMMAND
        AND NOT _luajit_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
  endif()
  if(NOT _luajit_TARGET)
    set(_luajit_TARGET "luajit")
  endif()

  ExternalProject_Add(${_luajit_TARGET}
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LUAJIT_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luajit
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/luajit
      -DURL=${LUAJIT_URL}
      -DEXPECTED_SHA256=${LUAJIT_SHA256}
      -DTARGET=${_luajit_TARGET}
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND "${_luajit_CONFIGURE_COMMAND}"
    BUILD_IN_SOURCE 1
    BUILD_COMMAND "${_luajit_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luajit_INSTALL_COMMAND}")

  # Create symlink for development version manually.
  if(UNIX)
    add_custom_command(
      TARGET ${_luajit_TARGET}
      COMMAND ${CMAKE_COMMAND} -E create_symlink luajit-2.1.0-beta3 ${DEPS_BIN_DIR}/luajit)
  endif()
endfunction()

check_c_compiler_flag(-fno-stack-check HAS_NO_STACK_CHECK)
if(CMAKE_SYSTEM_NAME MATCHES "Darwin" AND HAS_NO_STACK_CHECK)
  set(NO_STACK_CHECK "CFLAGS+=-fno-stack-check")
else()
  set(NO_STACK_CHECK "")
endif()
if(CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
  set(AMD64_ABI "LDFLAGS=-lpthread -lc++abi")
else()
  set(AMD64_ABI "")
endif()
set(INSTALLCMD_UNIX ${MAKE_PRG} CFLAGS=-fPIC
                                CFLAGS+=-DLUA_USE_APICHECK
                                CFLAGS+=-funwind-tables
                                ${NO_STACK_CHECK}
                                ${AMD64_ABI}
                                CCDEBUG+=-g
                                Q=
                                install)

if(UNIX)
  if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    if(CMAKE_OSX_DEPLOYMENT_TARGET)
      set(DEPLOYMENT_TARGET "MACOSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
    else()
      # Use the same target as our nightly builds
      set(DEPLOYMENT_TARGET "MACOSX_DEPLOYMENT_TARGET=10.11")
    endif()
  else()
    set(DEPLOYMENT_TARGET "")
  endif()

  BuildLuaJit(INSTALL_COMMAND ${INSTALLCMD_UNIX}
    CC=${DEPS_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR}
    ${DEPLOYMENT_TARGET})

elseif(MSVC)

  BuildLuaJit(
    BUILD_COMMAND ${CMAKE_COMMAND} -E chdir ${DEPS_BUILD_DIR}/src/luajit/src ${DEPS_BUILD_DIR}/src/luajit/src/msvcbuild.bat
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/luajit.exe ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.dll ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/lib
      # Luarocks searches for lua51.lib
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.lib ${DEPS_INSTALL_DIR}/lib/lua51.lib
      # Luv searches for luajit.lib
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.lib ${DEPS_INSTALL_DIR}/lib/luajit.lib
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include/luajit-2.1
      COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/luajit/src/*.h -DTO=${DEPS_INSTALL_DIR}/include/luajit-2.1 -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin/lua/jit
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${DEPS_BUILD_DIR}/src/luajit/src/jit ${DEPS_INSTALL_DIR}/bin/lua/jit
      )
else()
  message(FATAL_ERROR "Trying to build luajit in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS luajit)
