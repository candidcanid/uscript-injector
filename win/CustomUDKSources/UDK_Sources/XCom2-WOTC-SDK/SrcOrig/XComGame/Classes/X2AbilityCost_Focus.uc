class X2AbilityCost_Focus extends X2AbilityCost;

var int FocusAmount;
var bool ConsumeAllFocus;
var bool GhostOnlyCost;

simulated function name CanAfford(XComGameState_Ability kAbility, XComGameState_Unit ActivatingUnit)
{
	local int FocusLevel;

	if( GhostOnlyCost && ActivatingUnit.GhostSourceUnit.ObjectID == 0 )
	{
		return 'AA_Success';
	}

	FocusLevel = ActivatingUnit.GetTemplarFocusLevel();
	if (FocusLevel >= FocusAmount)
		return 'AA_Success';

	return 'AA_CannotAfford_Focus';
}

simulated function ApplyCost(XComGameStateContext_Ability AbilityContext, XComGameState_Ability kAbility, XComGameState_BaseObject AffectState, XComGameState_Item AffectWeapon, XComGameState NewGameState)
{
	local XComGameState_Effect_TemplarFocus FocusState;
	local XComGameState_Unit ActivatingUnit;

	ActivatingUnit = XComGameState_Unit(AffectState);

	if (bFreeCost || FocusAmount < 1 || (GhostOnlyCost && ActivatingUnit.GhostSourceUnit.ObjectID == 0) )
		return;

	FocusState = ActivatingUnit.GetTemplarFocusEffectState();
	`assert(FocusState != none);
	FocusState = XComGameState_Effect_TemplarFocus(NewGameState.ModifyStateObject(FocusState.Class, FocusState.ObjectID));
	if( ConsumeAllFocus )
	{
		FocusState.SetFocusLevel(0, XComGameState_Unit(AffectState), NewGameState);
	}
	else
	{
		FocusState.SetFocusLevel(FocusState.FocusLevel - FocusAmount, XComGameState_Unit(AffectState), NewGameState);
	}
}

DefaultProperties
{
	FocusAmount = 1;
}