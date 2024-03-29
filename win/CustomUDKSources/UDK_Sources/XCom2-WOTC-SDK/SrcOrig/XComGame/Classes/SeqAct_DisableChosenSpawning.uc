//---------------------------------------------------------------------------------------
//  FILE:    SeqAct_DisableChosenSpawning.uc
//  PURPOSE: Kismet action to disable Chosen spawning for the battle.  
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class SeqAct_DisableChosenSpawning extends SequenceAction;

event Activated()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;
	
	History = `XCOMHISTORY;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Kismet Disabled Chosen Spawns");

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	
	if(InputLinks[0].bHasImpulse)
	{
		BattleData.bChosenSpawningDisabledViaKismet = true;
	}
	else if(InputLinks[1].bHasImpulse)
	{
		BattleData.bChosenSpawningDisabledViaKismet = false;
	}

	`TACTICALRULES.SubmitGameState(NewGameState);
}

defaultproperties
{
	ObjCategory="Gameplay"
	ObjName="Chosen - Enable/Disable Spawning"

	InputLinks(0)=(LinkDesc="Disable")
	InputLinks(1)=(LinkDesc="ReEnable")

	bConvertedForReplaySystem=true
	bCanBeUsedForGameplaySequence=true
}
