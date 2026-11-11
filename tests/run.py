"""Optional runner when a standalone Lua 5.4 executable is unavailable.

Install lupa in a virtual environment, then run: python tests/run.py
The shipped REAPER script does not depend on Python or lupa.
"""
from pathlib import Path
import os
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
for path in root.rglob('*.lua'):
    lua.execute('assert(load(...))', path.read_text())
lua.execute("package.path = './?.lua;' .. package.path; dofile('tests/unit.lua')")
