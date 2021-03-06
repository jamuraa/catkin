#
# Creates forwarding Python :term:`pkgutil` infrastructure in
# buildspace that enables mixing :term:`generated code` in buildspace
# with :term:`static code` from sourcespace within a single Python
# package.
#
# In addition, this will interrogate the Python setup.py file in
# ``${${PROJECT_NAME}_SOURCE_DIR}`` and add the install command of
# distutils/setuputils to the install target.
# 
# .. note:: If the project also uses message generation via
#   ``generate_messages()`` this function must be called before.
#
#
# @public
#
function(catkin_python_setup)
  if(ARGN)
    message(FATAL_ERROR "catkin_python_setup() called with unused arguments: ${ARGN}")
  endif()

  assert(PROJECT_NAME)

  # mark that catkin_python_setup() was called in order to disable installation of gen/py stuff in generate_messages()
  set(${PROJECT_NAME}_CATKIN_PYTHON_SETUP TRUE PARENT_SCOPE)
  if(${PROJECT_NAME}_GENERATE_MESSAGES)
    message(FATAL_ERROR "generate_messages() must be called after catkin_python_setup() in project '${PROJECT_NAME}'")
  endif()

  if(NOT EXISTS ${${PROJECT_NAME}_SOURCE_DIR}/setup.py)
    message(FATAL_ERROR "catkin_python_setup() called without 'setup.py' in project folder ' ${${PROJECT_NAME}_SOURCE_DIR}'")
  endif()

  if(EXISTS ${${PROJECT_NAME}_SOURCE_DIR}/setup.py)
    assert(PYTHON_INSTALL_DIR)
    set(INSTALL_CMD_WORKING_DIRECTORY ${${PROJECT_NAME}_SOURCE_DIR})
    if(NOT MSVC)
      set(INSTALL_SCRIPT
        ${CMAKE_CURRENT_BINARY_DIR}/catkin_generated/python_distutils_install.sh)
      configure_file(${catkin_EXTRAS_DIR}/templates/python_distutils_install.sh.in
        ${INSTALL_SCRIPT}
        @ONLY)
    else()
      # need to convert install prefix to native path for python setuptools --prefix (its fussy about \'s)
      file(TO_NATIVE_PATH ${CMAKE_INSTALL_PREFIX} PYTHON_INSTALL_PREFIX)
      set(INSTALL_SCRIPT
        ${CMAKE_CURRENT_BINARY_DIR}/catkin_generated/python_distutils_install.bat)
      configure_file(${catkin_EXTRAS_DIR}/templates/python_distutils_install.bat.in
        ${INSTALL_SCRIPT}
        @ONLY)
    endif()

    # run generated python script
    configure_file(${catkin_EXTRAS_DIR}/templates/safe_execute_install.cmake.in
      ${CMAKE_CURRENT_BINARY_DIR}/catkin_generated/safe_execute_install.cmake)
    install(SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/catkin_generated/safe_execute_install.cmake)

    stamp(${${PROJECT_NAME}_SOURCE_DIR}/setup.py)

    assert(CATKIN_ENV)
    assert(PYTHON_EXECUTABLE)
    set(cmd
      ${CATKIN_ENV} ${PYTHON_EXECUTABLE}
      ${catkin_EXTRAS_DIR}/interrogate_setup_dot_py.py
      ${PROJECT_NAME}
      ${${PROJECT_NAME}_SOURCE_DIR}/setup.py
      ${${PROJECT_NAME}_BINARY_DIR}/catkin_generated/setup_py_interrogation.cmake
      )

    debug_message(10 "catkin_python_setup() in project '{PROJECT_NAME}' executes:  ${cmd}")
    safe_execute_process(COMMAND ${cmd})
    include(${${PROJECT_NAME}_BINARY_DIR}/catkin_generated/setup_py_interrogation.cmake)

    # generate relaying __init__.py for each python package
    if(${PROJECT_NAME}_PACKAGES)
      list(LENGTH ${PROJECT_NAME}_PACKAGES pkgs_count)
      math(EXPR pkgs_range "${pkgs_count} - 1")
      foreach(index RANGE ${pkgs_range})
        list(GET ${PROJECT_NAME}_PACKAGES ${index} pkg)
        list(GET ${PROJECT_NAME}_PACKAGE_DIRS ${index} pkg_dir)
        get_filename_component(name ${pkg_dir} NAME)
        if(NOT ("${pkg}" STREQUAL "${name}"))
          message(FATAL_ERROR "The package name '${pkg}' differs from the basename of the path '${pkg_dir}' in project '${PROJECT_NAME}'")
        endif()
        get_filename_component(path ${pkg_dir} PATH)
        set(PACKAGE_PYTHONPATH ${CMAKE_CURRENT_SOURCE_DIR}/${path})
        configure_file(${catkin_EXTRAS_DIR}/templates/__init__.py.in
          ${CATKIN_BUILD_PREFIX}/${PYTHON_INSTALL_DIR}/${pkg}/__init__.py
          @ONLY)
      endforeach()
    endif()

    # generate relay-script for each python script
    foreach(script ${${PROJECT_NAME}_SCRIPTS})
      get_filename_component(name ${script} NAME)
      if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${script})
        message(FATAL_ERROR "The script '${name}' as listed in 'setup.py' of '${PROJECT_NAME}' doesn't exist")
      endif()
      set(PYTHON_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/${script})
      configure_file(${catkin_EXTRAS_DIR}/templates/script.py.in
        ${CATKIN_BUILD_PREFIX}/${CATKIN_GLOBAL_BIN_DESTINATION}/${name}
        @ONLY)
    endforeach()
  endif()
endfunction()

stamp(${catkin_EXTRAS_DIR}/interrogate_setup_dot_py.py)
