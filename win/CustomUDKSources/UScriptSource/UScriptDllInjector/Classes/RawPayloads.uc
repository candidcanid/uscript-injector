class RawPayloads extends Object dependsOn(DataStructures);

`if(`isdefined(Flavour_udk32))
var Address Ptr__HEADER_BASE;
var Address Ptr_VftEntry_GLog_Log;
var Address Ptr_VftEntry_UFunction_Bind;
var Address Ptr_FName_Names;
var Address Ptr_GNatives;
var Address Ptr_GPropAddr;
var Address Ptr_GPropObject;
var Address Ptr_GProperty;
var Address Ptr_Plt_LoadLibraryA;
var Address Ptr_Plt_LoadLibraryW;
var Address Ptr_GMalloc;
var int off_UFunction_FuncMap_Data;
var int off_UFUnction_FuncMap_Length;
var int off_UFunction_LowFlags;
var int off_UFunction_HighFlags;
var int off_UFunction_Func;
var Address Ptr_Vft_UObject;
var Address Ptr_UMaterialInstanceTimeVarying_execSetDuration;

defaultproperties
{
    Ptr__HEADER_BASE=(Low=0x400000);
    Ptr_VftEntry_GLog_Log=(Low=0x21a5eb8);
    Ptr_VftEntry_UFunction_Bind=(Low=0x2193b7c);
    Ptr_FName_Names=(Low=0x2925f00);
    Ptr_GNatives=(Low=0x28d9050);
    Ptr_GPropAddr=(Low=0x28b5078);
    Ptr_GPropObject=(Low=0x28b507c);
    Ptr_GProperty=(Low=0x28b5060);
    Ptr_Plt_LoadLibraryA=(Low=0x213d2d8);
    Ptr_Plt_LoadLibraryW=(Low=0x213d238);
    Ptr_GMalloc=(Low=0x28b504c);
    off_UFunction_FuncMap_Data=0x90;
    off_UFUnction_FuncMap_Length=0x94;
    off_UFunction_LowFlags=0x84;
    off_UFunction_HighFlags=0xcc;
    off_UFunction_Func=0xa4;
    Ptr_Vft_UObject=(Low=0x21a1a48);
    Ptr_UMaterialInstanceTimeVarying_execSetDuration=(Low=0x916e40);
}
`endif
`if(`isdefined(Flavour_udk64))
var int CheckRWX[11];
var int SimpleCallFuncPtr[15];
var Address Ptr__HEADER_BASE;
var Address Ptr_VftEntry_GLog_Log;
var Address Ptr_VftEntry_UFunction_Bind;
var Address Ptr_FName_Names;
var Address Ptr_GNatives;
var Address Ptr_GPropAddr;
var Address Ptr_GPropObject;
var Address Ptr_GProperty;
var Address Ptr_Plt_LoadLibraryA;
var Address Ptr_Plt_LoadLibraryW;
var Address Ptr_Plt_VirtualAlloc;
var int off_UFunction_FuncMap_Data;
var int off_UFUnction_FuncMap_Length;
var int off_UFunction_LowFlags;
var int off_UFunction_HighFlags;
var int off_UFunction_Func;
var Address Ptr_Vft_UObject;
var Address Ptr_UMaterialInstance_execSetFontParameterValue;

defaultproperties
{
    Ptr__HEADER_BASE=(Low=0x40000000,High=0x1);
    Ptr_VftEntry_GLog_Log=(Low=0x42297ac8,High=0x1);
    Ptr_VftEntry_UFunction_Bind=(Low=0x4227cca8,High=0x1);
    Ptr_FName_Names=(Low=0x43068e60,High=0x1);
    Ptr_GNatives=(Low=0x42fd7f90,High=0x1);
    Ptr_GPropAddr=(Low=0x42fb3160,High=0x1);
    Ptr_GPropObject=(Low=0x42fb3168,High=0x1);
    Ptr_GProperty=(Low=0x42fb3130,High=0x1);
    Ptr_Plt_LoadLibraryA=(Low=0x421e3548,High=0x1);
    Ptr_Plt_LoadLibraryW=(Low=0x421e3638,High=0x1);
    Ptr_Plt_VirtualAlloc=(Low=0xdddddddd,High=0x22);
    off_UFunction_FuncMap_Data=0xdc;
    off_UFUnction_FuncMap_Length=0xe4;
    off_UFunction_LowFlags=0xd0;
    off_UFunction_HighFlags=0x124;
    off_UFunction_Func=0xf8;
    Ptr_Vft_UObject=(Low=0x4228fbd0,High=0x1);
    Ptr_UMaterialInstance_execSetFontParameterValue=(Low=0x405ba510,High=0x1);
    CheckRWX(0)=0x11111111;
    CheckRWX(1)=0x11111111;
    CheckRWX(2)=0x22222222;
    CheckRWX(3)=0x22222222;
    CheckRWX(4)=0x33333333;
    CheckRWX(5)=0x33333333;
    CheckRWX(6)=0x25048d48;
    CheckRWX(7)=0xabcd;
    CheckRWX(8)=0xd9058948;
    CheckRWX(9)=0xc3ffffff;
    CheckRWX(10)=0x90909090;
    SimpleCallFuncPtr(0)=0x11111111;
    SimpleCallFuncPtr(1)=0x11111111;
    SimpleCallFuncPtr(2)=0x22222222;
    SimpleCallFuncPtr(3)=0x22222222;
    SimpleCallFuncPtr(4)=0x33333333;
    SimpleCallFuncPtr(5)=0x33333333;
    SimpleCallFuncPtr(6)=0x4c515041;
    SimpleCallFuncPtr(7)=0xffde058b;
    SimpleCallFuncPtr(8)=0x8b48ffff;
    SimpleCallFuncPtr(9)=0xffffdf0d;
    SimpleCallFuncPtr(10)=0xd0ff41ff;
    SimpleCallFuncPtr(11)=0xcd058948;
    SimpleCallFuncPtr(12)=0x59ffffff;
    SimpleCallFuncPtr(13)=0x90c35841;
    SimpleCallFuncPtr(14)=0x90909090;
}
`endif
`if(`isdefined(Flavour_XCom_EW))
var Address Ptr__HEADER_BASE;
var Address Ptr_VftEntry_GLog_Log;
var Address Ptr_VftEntry_UFunction_Bind;
var Address Ptr_FName_Names;
var Address Ptr_GNatives;
var Address Ptr_GPropAddr;
var Address Ptr_GPropObject;
var Address Ptr_GProperty;
var Address Ptr_Plt_LoadLibraryA;
var Address Ptr_Plt_LoadLibraryW;
var Address Ptr_GMalloc;
var int off_UFunction_FuncMap_Data;
var int off_UFUnction_FuncMap_Length;
var int off_UFunction_LowFlags;
var int off_UFunction_HighFlags;
var int off_UFunction_Func;
var Address Ptr_Vft_UObject;
var Address Ptr_UMaterialInstanceTimeVarying_execSetDuration;

defaultproperties
{
    Ptr__HEADER_BASE=(Low=0x400000);
    Ptr_VftEntry_GLog_Log=(Low=0x18a245c);
    Ptr_VftEntry_UFunction_Bind=(Low=0x188f858);
    Ptr_FName_Names=(Low=0x1cfef90);
    Ptr_GNatives=(Low=0x1c6fd70);
    Ptr_GPropAddr=(Low=0x1c49d5c);
    Ptr_GPropObject=(Low=0x1c49d60);
    Ptr_GProperty=(Low=0x1c49d44);
    Ptr_Plt_LoadLibraryA=(Low=0x13951e4);
    Ptr_Plt_LoadLibraryW=(Low=0x1395380);
    Ptr_GMalloc=(Low=0x1c49d30);
    off_UFunction_FuncMap_Data=0x90;
    off_UFUnction_FuncMap_Length=0x94;
    off_UFunction_LowFlags=0x84;
    off_UFunction_HighFlags=0xcc;
    off_UFunction_Func=0xa0;
    Ptr_Vft_UObject=(Low=0x189dff0);
    Ptr_UMaterialInstanceTimeVarying_execSetDuration=(Low=0x48b6e0);
}
`endif
`if(`isdefined(Flavour_XCom2_WotC))
var int CheckRWX[11];
var int SimpleCallFuncPtr[15];
var Address Ptr__HEADER_BASE;
var Address Ptr_VftEntry_GLog_Log;
var Address Ptr_VftEntry_UFunction_Bind;
var Address Ptr_FName_Names;
var Address Ptr_GNatives;
var Address Ptr_Plt_LoadLibraryA;
var Address Ptr_Plt_LoadLibraryW;
var Address Ptr_Plt_VirtualAlloc;
var int off_UFunction_FuncMap_Data;
var int off_UFUnction_FuncMap_Length;
var int off_UFunction_LowFlags;
var int off_UFunction_HighFlags;
var int off_UFunction_Func;
var Address Ptr_Vft_UObject;
var Address Ptr_UMaterialInstance_execSetFontParameterValue;

defaultproperties
{
    Ptr__HEADER_BASE=(Low=0x40000000,High=0x1);
    Ptr_VftEntry_GLog_Log=(Low=0x413b1e00,High=0x1);
    Ptr_VftEntry_UFunction_Bind=(Low=0x41388ee8,High=0x1);
    Ptr_FName_Names=(Low=0x41daf450,High=0x1);
    Ptr_GNatives=(Low=0x41c9dc40,High=0x1);
    Ptr_Plt_LoadLibraryA=(Low=0x41364710,High=0x1);
    Ptr_Plt_LoadLibraryW=(Low=0x41364628,High=0x1);
    Ptr_Plt_VirtualAlloc=(Low=0x413646f8,High=0x1);
    off_UFunction_FuncMap_Data=0xdc;
    off_UFUnction_FuncMap_Length=0xe4;
    off_UFunction_LowFlags=0xd0;
    off_UFunction_HighFlags=0x124;
    off_UFunction_Func=0xf0;
    Ptr_Vft_UObject=(Low=0x413a7580,High=0x1);
    Ptr_UMaterialInstance_execSetFontParameterValue=(Low=0x40489910,High=0x1);
    CheckRWX(0)=0x11111111;
    CheckRWX(1)=0x11111111;
    CheckRWX(2)=0x22222222;
    CheckRWX(3)=0x22222222;
    CheckRWX(4)=0x33333333;
    CheckRWX(5)=0x33333333;
    CheckRWX(6)=0x25048d48;
    CheckRWX(7)=0xabcd;
    CheckRWX(8)=0xd9058948;
    CheckRWX(9)=0xc3ffffff;
    CheckRWX(10)=0x90909090;
    SimpleCallFuncPtr(0)=0x11111111;
    SimpleCallFuncPtr(1)=0x11111111;
    SimpleCallFuncPtr(2)=0x22222222;
    SimpleCallFuncPtr(3)=0x22222222;
    SimpleCallFuncPtr(4)=0x33333333;
    SimpleCallFuncPtr(5)=0x33333333;
    SimpleCallFuncPtr(6)=0x4c515041;
    SimpleCallFuncPtr(7)=0xffde058b;
    SimpleCallFuncPtr(8)=0x8b48ffff;
    SimpleCallFuncPtr(9)=0xffffdf0d;
    SimpleCallFuncPtr(10)=0xd0ff41ff;
    SimpleCallFuncPtr(11)=0xcd058948;
    SimpleCallFuncPtr(12)=0x59ffffff;
    SimpleCallFuncPtr(13)=0x90c35841;
    SimpleCallFuncPtr(14)=0x90909090;
}
`endif
