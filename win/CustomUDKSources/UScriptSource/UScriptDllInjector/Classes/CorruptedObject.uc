class CorruptedObject extends Object;

// ~1024 bytes (0x400 / 0x4 = 0x100 = 256)
var int ScratchPad[256];

function PaddingFunc0() {
    `log("WARNING: calling PaddingFunc");
}

function PaddingFunc1() {
    `log("WARNING: calling stub");
}

function PaddingFunc2(int CStrDLLPath) {
    `log("WARNING: calling stub");
}

function PaddingFunc3() {
    `log("WARNING: calling stub");
}

function PaddingFunc4(int CStrDLLPath) {
    `log("WARNING: calling stub");
}

function PaddingFunc5(int CStrDLLPath) {
    `log("WARNING: calling stub");
}

// :: 64bit specific ::
`if(`isdefined(Arch_x86_64))

final function FuncOverrideTarget(int A, int B, int C) {
    `log("WARNING: calling stub");
}

// :: 32bit specific ::
`else

final function FuncOverrideTarget(int CStrDLLPath) {
    `log("WARNING: calling stub");
}

`endif

final function Address Native_InternalObjectTesting() {
    local Address Dummy;
    `log("ERROR: calling empty stub func");
    return Dummy;
}

defaultproperties 
{
    // 'signature' for where ScratchPad starts inside CorruptedObject
    //   because the offset of where UObject properties tends to shift around
    //   we set a signature and find the offset later using a memory read primitive
    ScratchPad[0] = 0x3333beef;
    ScratchPad[1] = 0x2222dead;
}
