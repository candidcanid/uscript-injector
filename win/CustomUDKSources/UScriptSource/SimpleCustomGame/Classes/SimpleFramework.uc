class SimpleFramework extends FrameworkGame;


static event class<GameInfo> SetGameType(string MapName, string Options, string Portal) {
    local bool Result;
    Result = class'UScriptDLLInjector.Api'.static.InjectDLL(class'UScriptDLLInjector.Api'.static.GetInjectedDllPath());
    `log("InjectDLL(...) =: " $ Result);
    return super.SetGameType(MapName, Options, Portal);
}
