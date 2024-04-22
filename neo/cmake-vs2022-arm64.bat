cd ..
del /s /q build
mkdir build
cd build
cmake -G "Visual Studio 17" -A arm64 -DUSE_INTRINSICS_SSE=OFF -DFFMPEG=OFF -DBINKDEC=ON -VULKAN=OFF ../neo 
pause