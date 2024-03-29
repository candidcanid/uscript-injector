//---------------------------------------------------------------------------------------
//  FILE:    X2VisibilityObserver.uc
//  AUTHOR:  Ryan McFall  --  10/9/2013
//  PURPOSE: This class is responsible for ensuring that the visibility state of each
//           visualizer matches what is stored in the visibility mgr. This acts as a 
//           guard against the visibility state being left in an invalid state by visualizers 
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2VisibilityObserver extends Object implements(X2VisualizationMgrObserverInterface) native(Core);

var private int HighestHistoryIndexProcessed;

/// <summary>
/// Called when an active visualization system becomes idle. At the moment this is a catch all that is supposed to fix up any incorrect visibility
/// state on the pawns and visualizers. We are going to want to move away from this approach and let the individual visualizers do this, but this can 
/// remain as a validation step to warn when the game state and visualizer disagree.
/// </summary>
event OnVisualizationIdle()
{	
	local X2TacticalGameRuleset Ruleset;	
	local array<StateObjectReference> Viewers;
	local int IndexViewers;
	local X2GameRulesetVisibilityInterface ViewerOfTarget;
	local int LocalPlayerID;
	local XComGameStateHistory History;
	local Actor Visualizer;
	local XComGameState_BaseObject TargetState;
	local X2GameRulesetVisibilityInterface TargetInterface;
	local bool bAnyLocalViewers;
	local XComGameState_Unit UnitState;
	local bool bIsUnitStateRemovedFromPlay;	
	local bool bAllowSelectAll;
	local GameRulesCache_VisibilityInfo VisInfo;

	Ruleset = `TACTICALRULES;
	History = `XCOMHISTORY;
	
	bAllowSelectAll = XComTacticalCheatManager(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().CheatManager).bAllowSelectAll;

	LocalPlayerID = Ruleset.GetLocalClientPlayerObjectID();
	foreach History.IterateByClassType(class'XComGameState_BaseObject', TargetState)
	{
		TargetInterface = X2GameRulesetVisibilityInterface(TargetState);
		if (TargetInterface != none)
		{
			UnitState = XComGameState_Unit(TargetState);
			Visualizer = History.GetGameStateForObjectID(TargetState.ObjectID).GetVisualizer();

			bAnyLocalViewers = UnitState != none && class'X2TacticalVisibilityHelpers'.static.IsUnitAlwaysVisibleToLocalPlayer(UnitState);

			if(bAnyLocalViewers == false)
			{
				if(!Ruleset.VisibilityMgr.GetVisibilityInfo(TargetState.ObjectID, TargetState.ObjectID, VisInfo, -1))
				{
					//This visualizer is unknown to the visibility system, yet has a visibility interface. This shouldn't be happening, but right now is relegated to demo direct mode so 
					//isn't too serious... default these to visible
					bAnyLocalViewers = true;
				}
				else
				{
					Viewers.Length = 0;
					Ruleset.VisibilityMgr.GetAllViewersOfTarget(TargetState.ObjectID, Viewers, class'XComGameState_BaseObject', -1, class'X2TacticalVisibilityHelpers'.default.LivingGameplayVisibleFilter);
					for(IndexViewers = 0; IndexViewers < Viewers.Length; ++IndexViewers)
					{
						ViewerOfTarget = X2GameRulesetVisibilityInterface(History.GetGameStateForObjectID(Viewers[IndexViewers].ObjectID));
						if(LocalPlayerID == ViewerOfTarget.GetAssociatedPlayerID())
						{
							if(Visualizer != none)
							{
								bAnyLocalViewers = true;
								break;
							}
						}
					}
				}
			}

			if (Visualizer != none)
			{
				// Check to see if this is a XComGameState_Unit and do unit specific processing
				bIsUnitStateRemovedFromPlay = false;
				if (UnitState != none)
				{
					//bAnyLocalViewers = bAnyLocalViewers || XGUnit(Visualizer).GetPawn().UpdatePawnVisibility(); //Combine with the results from the FOW
					if (UnitState.bRemovedFromPlay || UnitState.bRemoved)
					{
						bIsUnitStateRemovedFromPlay = true;
					}
				}

				if(!bIsUnitStateRemovedFromPlay && TargetInterface.ForceModelVisible() != eForceNotVisible && 
					(bAnyLocalViewers || (TargetInterface.ForceModelVisible() == eForceVisible) || bAllowSelectAll))
				{
					Visualizer.SetVisibleToTeams(eTeam_All);
				}
				else
				{
					Visualizer.SetVisibleToTeams(eTeam_None);
				}
			}
		}
	}		
}

/// <summary>
/// Called by visualizer code when it decides that an entity should re-evaluate its visibility situation
/// </summary>
event VisualizerUpdateVisibility(Actor Visualizer, out TTile NewTile)
{
	local FOWTileStatus TileStatus;
	local BYTE GameplayFlags;
	local X2VisualizerInterface VisualizerInterface;
	local X2GameRulesetVisibilityInterface VisibilityViewerInterface;
	local XComGameState_BaseObject GameStateObject;
	local EForceVisibilitySetting ForcedVisible;

	VisualizerInterface = X2VisualizerInterface(Visualizer);
	if( VisualizerInterface != none )
	{
		GameStateObject = `XCOMHISTORY.GetGameStateForObjectID(VisualizerInterface.GetVisualizedStateReference().ObjectID);
		VisibilityViewerInterface = X2GameRulesetVisibilityInterface(GameStateObject);
		if( VisibilityViewerInterface != none )
		{
			ForcedVisible = VisibilityViewerInterface.ForceModelVisible();
		}
	}

	if(ForcedVisible == eForceVisible || XComTacticalCheatManager(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().CheatManager).bAllowSelectAll)
	{
		Visualizer.SetVisibleToTeams(eTeam_All);
		//`SHAPEMGR.DrawTile(NewTile, 0, 255, 255);
	}
	else if(ForcedVisible == eForceNotVisible)
	{
		Visualizer.SetVisibleToTeams(eTeam_None);
	}
	else
	{
		`XWORLD.GetTileFOWValue(NewTile, TileStatus, GameplayFlags);

		if( TileStatus == eFOWTileStatus_Seen )
		{			
			if( GameplayFlags != 0 )
			{				
				Visualizer.SetVisibleToTeams(eTeam_All);
				//`SHAPEMGR.DrawTile(NewTile, 0, 255, 0);
			}
			else
			{
				Visualizer.SetVisibleToTeams(eTeam_None);
				//`SHAPEMGR.DrawTile(NewTile, 255, 255, 0);
			}
		}
		else
		{
			Visualizer.SetVisibleToTeams(eTeam_None);
			//`SHAPEMGR.DrawTile(NewTile, 255, 0, 0);
		}
	}
}

event OnActiveUnitChanged(XComGameState_Unit NewActiveUnit);
event OnVisualizationBlockComplete(XComGameState AssociatedGameState)
{
	local array<int> ChangedObjectIDs;
	local int ScanObjects;
	local int CurrentObjectID;
	local XComGameState_Unit CurrentUnit;
	local XComGameStateHistory History;
	local XGUnit Unit;
	local XComGameStateVisualizationMgr VisMgr;

	if(AssociatedGameState != none)
	{
		History = `XCOMHISTORY;
			VisMgr = `XCOMVISUALIZATIONMGR;
		class'X2TacticalVisibilityHelpers'.static.GetVisibilityMgr().GetVisibilityStatusChangedObjects(AssociatedGameState.HistoryIndex, ChangedObjectIDs);

		for(ScanObjects = 0; ScanObjects < ChangedObjectIDs.Length; ++ScanObjects)
		{
			CurrentObjectID = ChangedObjectIDs[ScanObjects];

			CurrentUnit = XComGameState_Unit(History.GetGameStateForObjectID(CurrentObjectID, , AssociatedGameState.HistoryIndex));
			if(CurrentUnit != None)
			{
				Unit = XGUnit(CurrentUnit.GetVisualizer());
				if (Unit != none)
				{
					if(!VisMgr.IsActorBeingVisualized(Unit))
					{
						Unit.IdleStateMachine.CheckForStanceUpdate();
					}
					else
					{
						Unit.IdleStateMachine.CheckForStanceUpdateOnIdle();
					}
				}
			}
		}
	}	
}

function EventListenerReturn OnVisibilityChange(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit SourceUnitState;
	local XComGameState_Unit TargetObject;
	local X2GameRulesetVisibilityManager VisManager;
	local GameRulesCache_VisibilityInfo CurrentVisibility;
	local GameRulesCache_VisibilityInfo PreviousVisibility;
	local XGUnit UnitVisualizer;
	local bool bVisible;

	// check for early out conditions
	SourceUnitState = XComGameState_Unit(EventSource);
	if (SourceUnitState == none || 
		SourceUnitState.ControllingPlayer.ObjectID != `TACTICALRULES.GetLocalClientPlayerObjectID()) //Only care about local viewers
		return ELR_NoInterrupt;

	TargetObject = XComGameState_Unit(EventData); //Only care about unit vis against non team units
	if (TargetObject == none) return ELR_NoInterrupt;

	VisManager = `TACTICALRULES.VisibilityMgr;

	if (TargetObject.ControllingPlayer.ObjectID == `TACTICALRULES.GetLocalClientPlayerObjectID())
	{
		bVisible = true;
	}
	else
	{
		// get the current and previous visibility states for the changed object
		VisManager.GetVisibilityInfo(SourceUnitState.ObjectID, TargetObject.ObjectID, CurrentVisibility, GameState.HistoryIndex);
		if (CurrentVisibility.bVisibleGameplay) // check if the changed object became visible this frame
		{
			if (GameState.HistoryIndex > 0)
			{
				VisManager.GetVisibilityInfo(SourceUnitState.ObjectID, TargetObject.ObjectID, PreviousVisibility, GameState.HistoryIndex - 1);
			}

			if (!PreviousVisibility.bVisibleGameplay)
			{
				bVisible = true;
			}
		}
	}

	if (bVisible)
	{
		UnitVisualizer = XGUnit(`XCOMHISTORY.GetVisualizer(TargetObject.ObjectID));
		if (UnitVisualizer != none)
		{
			//Re-enable ticks on the unit if game play says it has become visible. The visualizers will need it soon. 
			UnitVisualizer.SetTickIsDisabled(false);
			UnitVisualizer.GetPawn().LOD_TickRate = 0.0f;
		}
	}

	return ELR_NoInterrupt;
}

function RegisterEvent()
{
	local Object ThisObj;

	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'ObjectVisibilityChanged', OnVisibilityChange, ELD_OnStateSubmitted);
}

function UnregisterEvents()
{
	local Object ThisObj;

	ThisObj = self;
	`XEVENTMGR.UnRegisterFromAllEvents(ThisObj);
}

DefaultProperties
{
	HighestHistoryIndexProcessed=-1
}
