//-----------------------------------------------------------
// Used by the visualizer system to control a Visualization Actor
//-----------------------------------------------------------
class X2Action_TimedInterTrackMessageAllMultiTargets extends X2Action;

var float SendMessagesAfterSec;

var protected XComGameStateContext_Ability AbilityContext;
var protected XComGameState VisualizeGameState;

function Init()
{
	super.Init();

	AbilityContext = XComGameStateContext_Ability(StateChangeContext);
	VisualizeGameState = AbilityContext.GetLastStateInInterruptChain();
}

simulated state Executing
{
Begin:
	Sleep(SendMessagesAfterSec * GetDelayModifier());

	//DELETE ME

	CompleteAction();
}