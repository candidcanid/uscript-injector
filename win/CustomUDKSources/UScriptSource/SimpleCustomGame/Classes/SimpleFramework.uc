class SimpleFramework extends FrameworkGame;


static event class<GameInfo> SetGameType(string MapName, string Options, string Portal) {
    local bool Result;
    Result = class'UScriptDLLInjector.Api'.static.InjectDLL("C:\\Modding\\zig-out\\lib\\testdll_payload.dll");
    `log("InjectDLL(...) =: " $ Result);
    return super.SetGameType(MapName, Options, Portal);
}
