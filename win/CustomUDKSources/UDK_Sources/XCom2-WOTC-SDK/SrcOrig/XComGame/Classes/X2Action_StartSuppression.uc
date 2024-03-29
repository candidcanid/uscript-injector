class X2Action_StartSuppression extends X2Action;

var private XGUnit              SourceUnit, TargetUnit;

function Init()
{
	local XComGameStateContext_Ability AbilityContext;

	super.Init();

	SourceUnit = XGUnit(Metadata.VisualizeActor);
	AbilityContext = XComGameStateContext_Ability(StateChangeContext);
	TargetUnit = XGUnit(`XCOMHISTORY.GetGameStateForObjectID(AbilityContext.InputContext.PrimaryTarget.ObjectID).GetVisualizer());
}

function bool CheckInterrupted()
{
	return false;
}

simulated state Executing
{
Begin:
	if (SourceUnit.IsMine())
		SourceUnit.UnitSpeak('Suppressing');
	else if (TargetUnit.IsMine())
		TargetUnit.UnitSpeak('Suppressed');

	SourceUnit.ConstantCombatSuppressArea(false);
	SourceUnit.ConstantCombatSuppress(true, TargetUnit);
	SourceUnit.IdleStateMachine.CheckForStanceUpdate();

	CompleteAction();
}