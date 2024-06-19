
add_definitions(-DDMAP -D__DOOM_DLL__)

# MC_ for MAP COMPILER
set(MC_INCLUDES
	#TypeInfoGen.h
	)
set(MC_SOURCES
	#TypeInfoGen.cpp
	#main.cpp
	precompiled.cpp
	)

file(GLOB MC_DMAP_INCLUDES dmap/*.h)
file(GLOB MC_DMAP_SOURCES dmap/*.cpp)

if(WIN32)
	list(APPEND MC_SOURCES main.cpp)
else()
	list(APPEND MC_SOURCES main_posix.cpp)
endif()

file(GLOB MC_AAS_INCLUDES ../../aas/*.h)
file(GLOB MC_AAS_SOURCES ../../aas/*.cpp)

file(GLOB MC_AASBUILD_INCLUDES aas/*.h)
file(GLOB MC_AASBUILD_SOURCES aas/*.cpp)

file(GLOB MC_CM_INCLUDES ../../cm/*.h)
file(GLOB MC_CM_SOURCES ../../cm/*.cpp)

set(MC_FRAMEWORK_INCLUDES 
	../../framework/CmdSystem.h
	../../framework/CVarSystem.h
	../../framework/File.h
	../../framework/File_Manifest.h
	../../framework/File_Resource.h
	../../framework/FileSystem.h
	../../framework/Licensee.h
	../../framework/DeclManager.h
	../../framework/DeclEntityDef.h
	../../framework/DeclSkin.h
	../../framework/DeclTable.h
	../../idlib/precompiled.h
	)
set(MC_FRAMEWORK_SOURCES
	../../framework/CmdSystem.cpp
	../../framework/CVarSystem.cpp
	../../framework/File.cpp
	../../framework/File_Manifest.cpp
	../../framework/File_Resource.cpp
	../../framework/FileSystem.cpp
	../../framework/DeclManager.cpp
	../../framework/DeclEntityDef.cpp
	../../framework/DeclSkin.cpp
	../../framework/DeclTable.cpp
	)

set(MC_RENDERER_INCLUDES 
	../../renderer/BinaryImage.h
	../../renderer/Color/ColorSpace.h
	../../renderer/Image.h
	../../renderer/Material.h
	#../../renderer/VertexCache.h
	../../renderer/ModelManager.h
	../../renderer/Model.h
	../../renderer/Model_gltf.h
	../../renderer/Model_ase.h
	../../renderer/Model_lwo.h
	../../renderer/Model_ma.h
	../../renderer/Model_obj.h
	)
set(MC_RENDERER_SOURCES
	../../renderer/BinaryImage.cpp
	../../renderer/Color/ColorSpace.cpp
	../../renderer/DXT/DXTEncoder.cpp
	../../renderer/DXT/DXTEncoder_SSE2.cpp
	../../renderer/GLMatrix.cpp
	../../renderer/ImageManager.cpp
	../../renderer/Image_files.cpp
	#../../renderer/Image_intrinsic.cpp TODO
	../../renderer/Image_load.cpp
	../../renderer/Image_process.cpp
	../../renderer/Image_program.cpp
	../../stub/Image_stub.cpp
	../../renderer/Material.cpp
	../../renderer/tr_trisurf.cpp
	#../../renderer/VertexCache.cpp
	../../renderer/ModelManager.cpp
	../../renderer/Model.cpp
	../../renderer/Model_gltf.cpp
	#../../renderer/Model_md5.cpp
	../../renderer/Model_ase.cpp
	../../renderer/Model_lwo.cpp
	../../renderer/Model_ma.cpp
	../../renderer/Model_obj.cpp
	)

set(MC_GAME_INCLUDES 
	../../d3xp/anim/Anim.h
	)
set(MC_GAME_SOURCES
	../../d3xp/anim/Anim.cpp
	../../d3xp/anim/Anim_Blend.cpp
	)
	
file(GLOB MC_MIKKTSPACE_INCLUDES ../../libs/mikktspace/*.h)
file(GLOB MC_MIKKTSPACE_SOURCES ../../libs/mikktspace/*.c)

set(MC_INCLUDES_ALL
			${MC_INCLUDES}
			${MC_FRAMEWORK_INCLUDES}
			${MC_RENDERER_INCLUDES}
			${MC_DMAP_INCLUDES}
			${MC_AAS_INCLUDES}
			${MC_AASBUILD_INCLUDES}
			${MC_CM_INCLUDES}
			${MC_MIKKTSPACE_INCLUDES}
			${MC_GAME_INCLUDES}
			)
			
set(MC_SOURCES_ALL
			${MC_SOURCES}
			${MC_FRAMEWORK_SOURCES}
			${MC_RENDERER_SOURCES}
			${MC_DMAP_SOURCES}
			${MC_AAS_SOURCES}
			${MC_AASBUILD_SOURCES}
			${MC_CM_SOURCES}
			${MC_MIKKTSPACE_SOURCES}
			${MC_GAME_SOURCES}
			)

source_group("main" FILES ${MC_INCLUDES})
source_group("main" FILES ${MC_SOURCES})
source_group("dmap" FILES ${MC_DMAP_INCLUDES})
source_group("dmap" FILES ${MC_DMAP_SOURCES})
source_group("framework" FILES ${MC_FRAMEWORK_INCLUDES})
source_group("framework" FILES ${MC_FRAMEWORK_SOURCES})
source_group("renderer" FILES ${MC_RENDERER_INCLUDES})
source_group("renderer" FILES ${MC_RENDERER_SOURCES})
source_group("aas" FILES ${MC_AAS_INCLUDES})
source_group("aas" FILES ${MC_AAS_SOURCES})
source_group("aasbuild" FILES ${MC_AASBUILD_INCLUDES})
source_group("aasbuild" FILES ${MC_AASBUILD_SOURCES})
source_group("cm" FILES ${MC_CM_INCLUDES})
source_group("cm" FILES ${MC_CM_SOURCES})
source_group("libs\\mikktspace" FILES ${MC_MIKKTSPACE_INCLUDES})
source_group("libs\\mikktspace" FILES ${MC_MIKKTSPACE_SOURCES})

source_group("anim" FILES ${MC_GAME_INCLUDES})
source_group("anim" FILES ${MC_GAME_SOURCES})

set(MC_PRECOMPILED_SOURCES ${MC_SOURCES_ALL})
list(REMOVE_ITEM MC_PRECOMPILED_SOURCES ${MC_MIKKTSPACE_SOURCES})

include_directories(
	.
	../../idlib
	)

if(MSVC)

	list(REMOVE_ITEM MC_PRECOMPILED_SOURCES precompiled.cpp) 

	#foreach( src_file ${MC_PRECOMPILED_SOURCES} )
	#	message(STATUS "-include precompiled.h for ${src_file}")
	#endforeach()

    #set_target_properties(idlib PROPERTIES COMPILE_FLAGS "/Yuprecompiled.h")
    set_source_files_properties(precompiled.cpp
        PROPERTIES
        COMPILE_FLAGS "/Ycprecompiled.h"
        OBJECT_OUTPUTS "precompiled.pch"
        )
		
	set_source_files_properties(
		${MC_PRECOMPILED_SOURCES}
		PROPERTIES
		COMPILE_FLAGS "/Yuprecompiled.h"
		OBJECT_DEPENDS "precompiled.pch"
		)

    add_executable(rbdmap ${MC_SOURCES_ALL} ${MC_INCLUDES_ALL})
	add_dependencies(rbdmap idlib)
	target_link_libraries(rbdmap idlib winmm)

	# set MSVC default debug directory on executable	
	if(CMAKE_MAJOR_VERSION EQUAL 3 AND CMAKE_MINOR_VERSION GREATER_EQUAL 8)
		set_target_properties(rbdmap PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/..")
	endif()
	
else()
	if (USE_PRECOMPILED_HEADERS)
	foreach( src_file ${MC_PRECOMPILED_SOURCES} )
		#message(STATUS "-include precompiled.h for ${src_file}")
		set_source_files_properties(
			${src_file}
			PROPERTIES
			COMPILE_FLAGS "-include ${CMAKE_CURRENT_SOURCE_DIR}/precompiled.h"
			)
	endforeach()
	endif()

	include_directories(.)
	
	if (USE_PRECOMPILED_HEADERS)
	# precompiled magic for GCC/clang, adapted from https://gist.github.com/573926
	STRING(TOUPPER "CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}" _flags_var_name)
	SET(_compiler_FLAGS "${${_flags_var_name}} -std=c++${CMAKE_CXX_STANDARD}")
	GET_DIRECTORY_PROPERTY(_directory_flags INCLUDE_DIRECTORIES)
	FOREACH(item ${_directory_flags})
		LIST(APPEND _compiler_FLAGS " -I${item}")
	ENDFOREACH(item)
	endif()

	GET_DIRECTORY_PROPERTY(_directory_flags DEFINITIONS)
	LIST(APPEND _compiler_FLAGS ${_directory_flags})
	
	SEPARATE_ARGUMENTS(_compiler_FLAGS)
	
	if (USE_PRECOMPILED_HEADERS)
	add_custom_target(precomp_header_rbdmap ALL
	                  COMMAND ${CMAKE_CXX_COMPILER} ${_compiler_FLAGS} -x c++-header precompiled.h -o precompiled.h.gch
	                  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	                  COMMENT "Creating tools/compilers/precompiled.h.gch for rbdmap"
	                  )
	endif()
	
	add_executable(rbdmap ${MC_SOURCES_ALL} ${MC_INCLUDES_ALL})
	add_dependencies(rbdmap idlib)
	if (USE_PRECOMPILED_HEADERS)
	add_dependencies(rbdmap precomp_header_rbdmap)
	endif()
	target_link_libraries(rbdmap idlib)
	
endif()
	

