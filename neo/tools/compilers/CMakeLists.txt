
add_definitions(-DDMAP -D__DOOM_DLL__)

set(BSPT_INCLUDES
	#TypeInfoGen.h
	)
set(BSPT_SOURCES
	#TypeInfoGen.cpp
	#main.cpp
	precompiled.cpp
	)

file(GLOB DMAP_INCLUDES dmap/*.h)
file(GLOB DMAP_SOURCES dmap/*.cpp)

if(WIN32)
	list(APPEND BSPT_SOURCES main.cpp)
else()
	list(APPEND BSPT_SOURCES ../../stub/EngineStubPosix.cpp)
endif()

set(BSPT_FRAMEWORK_INCLUDES 
	../../framework/CmdSystem.h
	../../framework/CVarSystem.h
	../../framework/File.h
	../../framework/File_Manifest.h
	../../framework/File_Resource.h
	../../framework/FileSystem.h
	../../framework/Licensee.h
	../../framework/DeclManager.h
	../../framework/DeclTable.h
	../../idlib/precompiled.h
	)
set(BSPT_FRAMEWORK_SOURCES
	../../framework/CmdSystem.cpp
	../../framework/CVarSystem.cpp
	../../framework/File.cpp
	../../framework/File_Manifest.cpp
	../../framework/File_Resource.cpp
	../../framework/FileSystem.cpp
	../../framework/DeclManager.cpp
	../../framework/DeclTable.cpp
	)

set(BSPT_RENDERER_INCLUDES 
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
set(BSPT_RENDERER_SOURCES
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
	
file(GLOB MIKKTSPACE_INCLUDES ../../libs/mikktspace/*.h)
file(GLOB MIKKTSPACE_SOURCES ../../libs/mikktspace/*.c)

if (NOT JPEG_FOUND)
    set(JPEG_INCLUDES
        ../../libs/jpeg-6/jchuff.h
        ../../libs/jpeg-6/jconfig.h
        ../../libs/jpeg-6/jdct.h
        ../../libs/jpeg-6/jdhuff.h
        ../../libs/jpeg-6/jerror.h
        ../../libs/jpeg-6/jinclude.h
        ../../libs/jpeg-6/jmemsys.h
        ../../libs/jpeg-6/jmorecfg.h
        ../../libs/jpeg-6/jpegint.h
        ../../libs/jpeg-6/jpeglib.h
        ../../libs/jpeg-6/jversion.h)

    set(JPEG_SOURCES
        ../../libs/jpeg-6/jcapimin.cpp
        ../../libs/jpeg-6/jcapistd.cpp
        ../../libs/jpeg-6/jccoefct.cpp
        ../../libs/jpeg-6/jccolor.cpp
        ../../libs/jpeg-6/jcdctmgr.cpp
        ../../libs/jpeg-6/jchuff.cpp
        ../../libs/jpeg-6/jcinit.cpp
        ../../libs/jpeg-6/jcmainct.cpp
        ../../libs/jpeg-6/jcmarker.cpp
        ../../libs/jpeg-6/jcmaster.cpp
        ../../libs/jpeg-6/jcomapi.cpp
        ../../libs/jpeg-6/jcparam.cpp
        ../../libs/jpeg-6/jcphuff.cpp
        ../../libs/jpeg-6/jcprepct.cpp
        ../../libs/jpeg-6/jcsample.cpp
        ../../libs/jpeg-6/jctrans.cpp
        ../../libs/jpeg-6/jdapimin.cpp
        ../../libs/jpeg-6/jdapistd.cpp
        ../../libs/jpeg-6/jdatadst.cpp
        ../../libs/jpeg-6/jdatasrc.cpp
        ../../libs/jpeg-6/jdcoefct.cpp
        ../../libs/jpeg-6/jdcolor.cpp
        ../../libs/jpeg-6/jddctmgr.cpp
        ../../libs/jpeg-6/jdhuff.cpp
        ../../libs/jpeg-6/jdinput.cpp
        ../../libs/jpeg-6/jdmainct.cpp
        ../../libs/jpeg-6/jdmarker.cpp
        ../../libs/jpeg-6/jdmaster.cpp
        ../../libs/jpeg-6/jdmerge.cpp
        ../../libs/jpeg-6/jdphuff.cpp
        ../../libs/jpeg-6/jdpostct.cpp
        ../../libs/jpeg-6/jdsample.cpp
        ../../libs/jpeg-6/jdtrans.cpp
        ../../libs/jpeg-6/jerror.cpp
        ../../libs/jpeg-6/jfdctflt.cpp
        ../../libs/jpeg-6/jfdctfst.cpp
        ../../libs/jpeg-6/jfdctint.cpp
        ../../libs/jpeg-6/jidctflt.cpp
        ../../libs/jpeg-6/jidctfst.cpp
        ../../libs/jpeg-6/jidctint.cpp
        ../../libs/jpeg-6/jidctred.cpp
        ../../#libs/jpeg-6/jload.cpp
        ../../libs/jpeg-6/jmemmgr.cpp
        ../../libs/jpeg-6/jmemnobs.cpp
        ../../#libs/jpeg-6/jpegtran.cpp
        ../../libs/jpeg-6/jquant1.cpp
        ../../libs/jpeg-6/jquant2.cpp
        ../../libs/jpeg-6/jutils.cpp)
else (NOT JPEG_FOUND)
   set(JPEG_INCLUDES "")
   set(JPEG_SOURCES "")
endif (NOT JPEG_FOUND)

if (NOT PNG_FOUND)
    file(GLOB PNG_INCLUDES ../../libs/png/*.h)
    file(GLOB PNG_SOURCES ../../libs/png/*.c)
else (NOT PNG_FOUND)
    set(PNG_INCLUDES "")
    set(PNG_SOURCES "")
endif (NOT PNG_FOUND)


if(NOT ZLIB_FOUND)
	file(GLOB BSPT_ZLIB_INCLUDES ../../libs/zlib/*.h)
	file(GLOB BSPT_ZLIB_SOURCES ../../libs/zlib/*.c)
#	list(APPEND BSPT_ZLIB_SOURCES ../../libs/zlib/minizip/unzip.cpp)
#	list(APPEND BSPT_ZLIB_SOURCES ../../libs/zlib/minizip/ioapi.c)
endif()


set(BSPT_INCLUDES_ALL
			${BSPT_INCLUDES}
			${BSPT_FRAMEWORK_INCLUDES}
			${BSPT_RENDERER_INCLUDES}
			${DMAP_INCLUDES}
			${MIKKTSPACE_INCLUDES}
			${JPG_INCLUDES}
			${PNG_INCLUDES}
			${BSPT_ZLIB_INCLUDES}
			)
			
set(BSPT_SOURCES_ALL
			${BSPT_SOURCES}
			${BSPT_FRAMEWORK_SOURCES}
			${BSPT_RENDERER_SOURCES}
			${DMAP_SOURCES}
			${MIKKTSPACE_SOURCES}
			${JPEG_SOURCES}
			${PNG_SOURCES}
			${BSPT_ZLIB_SOURCES}
			)

source_group("main" FILES ${BSPT_INCLUDES})
source_group("main" FILES ${BSPT_SOURCES})
source_group("dmap" FILES ${DMAP_INCLUDES})
source_group("dmap" FILES ${DMAP_SOURCES})
source_group("framework" FILES ${BSPT_FRAMEWORK_INCLUDES})
source_group("framework" FILES ${BSPT_FRAMEWORK_SOURCES})
source_group("renderer" FILES ${BSPT_RENDERER_INCLUDES})
source_group("renderer" FILES ${BSPT_RENDERER_SOURCES})
source_group("libs\\mikktspace" FILES ${MIKKTSPACE_INCLUDES})
source_group("libs\\mikktspace" FILES ${MIKKTSPACE_SOURCES})
source_group("libs\\jpeg-6" FILES ${JPEG_INCLUDES})
source_group("libs\\jpeg-6" FILES ${JPEG_SOURCES})
source_group("libs\\png" FILES ${PNG_INCLUDES})
source_group("libs\\png" FILES ${PNG_SOURCES})
#source_group("zlib" FILES ${BSPT_ZLIB_INCLUDES})
#source_group("zlib" FILES ${BSPT_ZLIB_SOURCES})

set(BSPT_PRECOMPILED_SOURCES ${BSPT_SOURCES_ALL})
list(REMOVE_ITEM BSPT_PRECOMPILED_SOURCES ${BSPT_ZLIB_SOURCES} ${JPEG_SOURCES} ${PNG_SOURCES} ${MIKKTSPACE_SOURCES})

include_directories(
	.
	../../idlib
	../../libs/zlib
	)

if(MSVC)

	list(REMOVE_ITEM BSPT_PRECOMPILED_SOURCES precompiled.cpp) 

	#foreach( src_file ${BSPT_PRECOMPILED_SOURCES} )
	#	message(STATUS "-include precompiled.h for ${src_file}")
	#endforeach()

    #set_target_properties(idlib PROPERTIES COMPILE_FLAGS "/Yuprecompiled.h")
    set_source_files_properties(precompiled.cpp
        PROPERTIES
        COMPILE_FLAGS "/Ycprecompiled.h"
        OBJECT_OUTPUTS "precompiled.pch"
        )
		
	set_source_files_properties(
		${BSPT_PRECOMPILED_SOURCES}
		PROPERTIES
		COMPILE_FLAGS "/Yuprecompiled.h"
		OBJECT_DEPENDS "precompiled.pch"
		)

    add_executable(rbdmap ${BSPT_SOURCES_ALL} ${BSPT_INCLUDES_ALL})
	add_dependencies(rbdmap idlib)
	target_link_libraries(rbdmap idlib winmm)

	# set MSVC default debug directory on executable	
	if(CMAKE_MAJOR_VERSION EQUAL 3 AND CMAKE_MINOR_VERSION GREATER_EQUAL 8)
		set_target_properties(rbdmap PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/../../..")
	endif()
	
else()
	if (USE_PRECOMPILED_HEADERS)
	foreach( src_file ${BSPT_PRECOMPILED_SOURCES} )
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
	add_custom_target(precomp_header_typeinfo ALL
	                  COMMAND ${CMAKE_CXX_COMPILER} ${_compiler_FLAGS} -x c++-header precompiled.h -o precompiled.h.gch
	                  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	                  COMMENT "Creating idlib/precompiled.h.gch for typeinfogen"
	                  )
	endif()
	
	add_executable(typeinfogen ${BSPT_SOURCES_ALL} ${BSPT_INCLUDES_ALL})
	add_dependencies(typeinfogen idlib)
	if (USE_PRECOMPILED_HEADERS)
	add_dependencies(typeinfogen precomp_header_typeinfo)
	endif()
	target_link_libraries(typeinfogen idlib)
	
endif()
	

