# Exalted - UScript Dll Injection Tooling

The core component of this project is the UnrealScript DLL injector - located in `win/CustomUDKSources/UScriptSource/UScriptDLLInjector`. It can be copied out and used 'as-is'. 

The rest of this project is build tooling and scripts to ease development of the DLL injector. This is stuff like standalone compilation of unrealscript, launching and attaching to UE3 games for testing. 

# Tooling usage: 

The general use build tools + debugging framework requires [Zig](https://ziglang.org/). Specifically 'zig-master', which can be found [here](https://ziglang.org/download/). 

To use these tools - you will likely need to open `Ue3Paths.zig` and alter the default paths used in `forFlavour`. Everything else should (probably) work fine after that.

The entire build->compile uscript->launch game exe process is managed by `build.zig`. To see supported 'flavours' the DLL injector supports - run `zig build -h` and inspect the `ue3_flavour` heading.

# UScriptDllInjector configuration and usage

The DLL injector is designed to be a standalone uscript class - with all the machinery hidden behind a small exposed API.

If copied out for use in other projects, `UScriptDllInjector` must be configured manually. For supported targets, this can be done by altering `UScriptDllInjector/Settings.uci`. 

Some examples:

```unrealscript
// Settings.uci for XCom: Enemy Within

// x86 = 32bit, x86_64 = 64bit
`define Arch_x86
// see RawPayloads.uc for valid flavours
`define Flavour_XCom_EW
```

```unrealscript
// Settings.uci for XCom2: War of the Chosen

// x86 = 32bit, x86_64 = 64bit
`define Arch_x86_64
// see RawPayloads.uc for valid flavours
`define Flavour_XCom2_WotC
```

'flavours' at this level can be find by inspecting each `if(isdefined(Flavour_...)` line in `UScriptDllInjector\Classes\RawPayloads.uc`.

An example of calling the injector in arbitray uscript:

```unrealscript
local bool Result;
Result = class'UScriptDLLInjector.Api'.static.InjectDLL("C:\\SomePath\\Something.dll");
```

NOTE: be sure that path provided to `InjectDLL` is valid! it currently lacks sanity/result checking, and the game will likely crash in some nasty fashion if the .dll path is invalid.