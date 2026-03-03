import strutils, os

if defined(emscripten):
  --nimcache:tmp
  --os:linux
  --cpu:wasm32
  --cc:clang
  when defined(windows):
    --clang.exe:emcc.bat
    --clang.linkerexe:emcc.bat
    --clang.cpp.exe:emcc.bat
    --clang.cpp.linkerexe:emcc.bat
  else:
    --clang.exe:emcc
    --clang.linkerexe:emcc
    --clang.cpp.exe:emcc
    --clang.cpp.linkerexe:emcc
  --listCmd

  --gc:orc
  --exceptions:goto
  --define:noSignalHandler
  --debugger:native

  # Delete dist directory if it exists
  if dirExists("dist"):
    rmDir("dist")
  mkDir("dist")

  # Temporary. This probably shouldn't be here. Workaround until a better solution is found
  mkDir("dist/data")
  cpFile("tests/ding.wav", "dist/data/ding.wav")
  cpFile("tests/xylophone-sweep.slappy", "dist/data/xylophone-sweep.slappy")
  cpFile("tests/xylophone-sweep.ogg", "dist/data/xylophone-sweep.ogg")
  cpFile("tests/drums.mono.wav", "dist/data/drums.mono.wav")

  switch(
    "passL",
    """
    -o dist/todo_emscripten.html
    --preload-file dist/data/
    -s ASYNCIFY
    -s FETCH
    -s USE_WEBGL2=1
    -s MAX_WEBGL_VERSION=2
    -s MIN_WEBGL_VERSION=1
    -s FULL_ES3=1
    -s GL_ENABLE_GET_PROC_ADDRESS=1
    -s ALLOW_MEMORY_GROWTH
    --profiling
    -lopenal
    """.replace("\n", " ")
  )

when not defined(debug):
  --define:noAutoGLerrorCheck
  --define:release

--define:ssl
--define:profile
--define:nimTypeNames

