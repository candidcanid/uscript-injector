//-----------------------------------------------------------
// Used by the visualizer system to control a Visualization Actor
//-----------------------------------------------------------
class X2Action_AlertUnit extends X2Action;

var localized string m_sAlertedUnitMessage[EAlertCause.eAC_MAX];

//Cached info for performing the action
//*************************************
var eAlertLevel				m_eAlertLevel;
var eAlertCause				m_eCause;
//*************************************

// Return value indicates whether or not we should pop up an 'Alert' message - only when going up in alert levels.
function bool UpdateAlertLevel()
{
	local int iLastLevel;
	local int iCurrentLevel;

	iCurrentLevel = XComGameState_Unit(Metadata.StateObject_NewState).GetCurrentStat(eStat_AlertLevel);
	iLastLevel = XComGameState_Unit(Metadata.StateObject_OldState).GetCurrentStat(eStat_AlertLevel);

	if(iLastLevel < iCurrentLevel)
		return true;
	return false;
}
//------------------------------------------------------------------------------------------------
simulated state Executing
{
Begin:
	
	if (Unit.IsAlive())
	{
		if( `CHEATMGR.bWorldDebugMessagesEnabled && UpdateAlertLevel() ) // Only show pop-up when alert level goes up.  Not when dropping from Red to yellow.
		{
			`PRES.QueueWorldMessage( m_sAlertedUnitMessage[m_eCause], Unit.GetLocation(), Unit.GetVisualizedStateReference(), eColor_Bad,,, Unit.m_eTeamVisibilityFlags, , , , , , , , , , , , , true);
		}
		if(Unit.IsTurret())
		{
			Unit.UpdateTurretIdle();
		}
		`PRES.m_kUnitFlagManager.RespondToNewGameState(Unit, StateChangeContext.GetLastStateInInterruptChain());

		Unit.VisualizedAlertLevel = m_eAlertLevel;

		//Since we have a unit changing alert states, update the music if necessary
		`XTACTICALSOUNDMGR.EvaluateTacticalMusicState();
		
		`battle.Update_GlobalEnemyVisualizeAlertFlags();
	}

	CompleteAction();
}

defaultproperties
{
	bCauseTimeDilationWhenInterrupting = true
}

