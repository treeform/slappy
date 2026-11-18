import std/os

# Define this here so the parent manual-demo configuration is not selected.
--define:emscripten
--define:noSignalHandler
--os:linux
--cpu:wasm32
--cc:clang
--clang.exe:emcc
--clang.linkerexe:emcc
--mm:orc
--threads:off
--exceptions:goto
--path:"../../src"
--nimcache:"dist/nimcache"

mkDir(thisDir() / "dist")
switch("out", thisDir() / "dist/capture.js")
switch("passL", "-sALLOW_MEMORY_GROWTH -sEXIT_RUNTIME=0")
switch("passL", "-sEXPORTED_RUNTIME_METHODS=UTF8ToString,HEAPU8")
switch("passL", "-sEXPORTED_FUNCTIONS=_main,_capture_open,_capture_start," &
  "_capture_stopping,_capture_stop,_capture_close,_capture_ready,_capture_available," &
  "_capture_read,_capture_read_all,_capture_data,_capture_error," &
  "_capture_grow,_capture_frequency,_capture_channels,_capture_bits")
