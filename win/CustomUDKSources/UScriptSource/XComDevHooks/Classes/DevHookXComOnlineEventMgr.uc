class DevHookXComOnlineEventMgr extends XComOnlineEventMgr;

var bool HasInjected;

`if(`isdefined(Flavour_XCom2_WotC))

function bool _IsPresentationLayerReady()
{
    local XComPresentationLayerBase Presentation;
    Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.

    return Presentation != none && Presentation.IsPresentationLayerReady() && Presentation.Get2DMovie().DialogBox != none;
}

`endif

event Tick(float DeltaTime) {
`if(`isdefined(Flavour_XCom_EW))
    local bool Result;
    Result = class'UScriptDLLInjector.Api'.static.InjectDLL("C:\\Modding\\zig-out\\lib\\testdll_payload.dll");
    `log("InjectDLL(...) =: " $ Result);
    HasInjected = true;
`endif

`if(`isdefined(Flavour_XCom2_WotC))
    local bool Result;
    if(_IsPresentationLayerReady() && !HasInjected) {
        Result = class'UScriptDLLInjector.Api'.static.InjectDLL("C:\\Modding\\zig-out\\lib\\testdll_payload.dll");
        `log("InjectDLL(...) =: " $ Result);
        HasInjected = true;
    }
`endif
}

