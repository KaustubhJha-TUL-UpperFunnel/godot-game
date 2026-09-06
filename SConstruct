#!/usr/bin/env python

env = SConscript("godot-cpp/SConstruct", {"api_version": "4.7"})

env.Append(CPPPATH=["descent/include"])
if env["platform"] == "windows" and env.get("is_msvc", False):
    env.Append(CXXFLAGS=["/std:c++17"])
else:
    env.Append(CXXFLAGS=["-std=c++17"])

sources = Glob("descent/src/*.cpp")
library = env.SharedLibrary(
    "descent/bin/libdescent{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
    source=sources,
)

env.NoCache(library)
Default(library)

