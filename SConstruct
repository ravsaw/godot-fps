#!/usr/bin/env python
import os
from SCons.Script import ARGUMENTS, Default, Exit, Glob, SConscript

godot_cpp_path = ARGUMENTS.get("godot_cpp_path", "godot-cpp")

if not os.path.isdir(godot_cpp_path):
    print("Missing godot-cpp directory. Provide it with godot_cpp_path=<path>.")
    Exit(1)

env = SConscript(os.path.join(godot_cpp_path, "SConstruct"))

env.Append(CPPPATH=["src"])

sources = []
sources += Glob("src/*.cpp")
sources += Glob("src/core/*.cpp")
sources += Glob("src/alife/*.cpp")
sources += Glob("src/player/*.cpp")
sources += Glob("src/weapon/*.cpp")
sources += Glob("src/npc/*.cpp")
sources += Glob("src/world/*.cpp")

library = env.SharedLibrary(
    "project/bin/godot_fps{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
    source=sources,
)

Default(library)