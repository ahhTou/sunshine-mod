# macos specific target definitions

if (SUNSHINE_BUILD_HOMEBREW)
    target_link_options(sunshine PRIVATE LINKER:-sectcreate,__TEXT,__info_plist,${APPLE_PLIST_FILE})
else()
    # .app build
    set_target_properties(sunshine PROPERTIES
            OUTPUT_NAME "${CMAKE_PROJECT_NAME}"
            MACOSX_BUNDLE_BUNDLE_NAME "${CMAKE_PROJECT_NAME}"
            MACOSX_BUNDLE_GUI_IDENTIFIER "${PROJECT_FQDN}"
            MACOSX_BUNDLE_INFO_PLIST "${APPLE_PLIST_FILE}"
            MACOSX_BUNDLE_ICON_FILE "SunshineMod.icns"
            MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
            MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}")

    # 分层图标由 Apple 资产编译器处理，保留动态材质与多种外观。
    file(GLOB_RECURSE SUNSHINE_MOD_ICON_INPUTS CONFIGURE_DEPENDS
            "${PROJECT_SOURCE_DIR}/src_assets/macos/SunshineMod.icon/*")
    set(SUNSHINE_MOD_ICON_OUTPUT "${CMAKE_BINARY_DIR}/icon-compiled")
    add_custom_command(
            OUTPUT "${SUNSHINE_MOD_ICON_OUTPUT}/Assets.car"
                   "${SUNSHINE_MOD_ICON_OUTPUT}/SunshineMod.icns"
            COMMAND sh "${PROJECT_SOURCE_DIR}/sunshine-mod/build-icon.sh" "${CMAKE_BINARY_DIR}"
            DEPENDS ${SUNSHINE_MOD_ICON_INPUTS} "${PROJECT_SOURCE_DIR}/sunshine-mod/build-icon.sh"
            VERBATIM)
    add_custom_target(sunshine-mod-icon DEPENDS
            "${SUNSHINE_MOD_ICON_OUTPUT}/Assets.car"
            "${SUNSHINE_MOD_ICON_OUTPUT}/SunshineMod.icns")
    add_dependencies(sunshine sunshine-mod-icon)
    set_source_files_properties(
            "${SUNSHINE_MOD_ICON_OUTPUT}/Assets.car"
            "${SUNSHINE_MOD_ICON_OUTPUT}/SunshineMod.icns"
            PROPERTIES GENERATED TRUE MACOSX_PACKAGE_LOCATION Resources)
    target_sources(sunshine PRIVATE
            "${SUNSHINE_MOD_ICON_OUTPUT}/Assets.car"
            "${SUNSHINE_MOD_ICON_OUTPUT}/SunshineMod.icns")

    # Populate bundle resources in the build tree for local runs.
    set(_bundle_resources_dir "$<TARGET_FILE_DIR:sunshine>/../Resources")
    add_custom_command(TARGET sunshine POST_BUILD
            COMMENT "Copying bundle resources to build tree"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${_bundle_resources_dir}"
            COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_BINARY_DIR}/assets" "${_bundle_resources_dir}/assets"
            # 开发构建也需要 macOS 默认应用列表。
            COMMAND "${CMAKE_COMMAND}" -E copy_directory "${SUNSHINE_SOURCE_ASSETS_DIR}/macos/assets" "${_bundle_resources_dir}/assets"
            VERBATIM)
endif()

# Tell linker to dynamically load these symbols at runtime, in case they're unavailable:
target_link_options(sunshine PRIVATE -Wl,-U,_CGPreflightScreenCaptureAccess -Wl,-U,_CGRequestScreenCaptureAccess)
