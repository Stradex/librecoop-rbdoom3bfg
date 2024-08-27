cd ..
rm -rf build
mkdir build
cd build
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DONATIVE=ON -DFFMPEG=OFF -DBINKDEC=ON -DUSE_PRECOMPILED_HEADERS=OFF -DUSE_INTRINSICS_SSE=ON ../neo
