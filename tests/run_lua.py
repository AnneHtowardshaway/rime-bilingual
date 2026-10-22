"""优先使用标准 Lua；macOS 可复用鼠须管捆绑的 Lua，不安装依赖。"""
import ctypes
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
os.environ["RIME_TEST_ROOT"] = str(root)
interpreter = shutil.which("lua") or shutil.which("lua5.4")
if interpreter:
    sys.exit(subprocess.call([interpreter, str(root / "tests/filter_spec.lua")]))
frameworks = Path("/Library/Input Methods/Squirrel.app/Contents/Frameworks")
ctypes.CDLL(str(frameworks / "librime.1.dylib"), mode=ctypes.RTLD_GLOBAL)
lua = ctypes.CDLL(str(frameworks / "rime-plugins/librime-lua.dylib"))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                         ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
if not state:
    raise RuntimeError("无法初始化 Lua")
try:
    lua.luaL_openlibs(state)
    status = lua.luaL_loadfilex(state, os.fsencode(root / "tests/filter_spec.lua"), None)
    if status == 0:
        status = lua.lua_pcallk(state, 0, 0, 0, 0, None)
    if status:
        raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
finally:
    lua.lua_close(state)
