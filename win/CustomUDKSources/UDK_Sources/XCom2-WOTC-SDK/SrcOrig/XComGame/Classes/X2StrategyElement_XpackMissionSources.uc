//---------------------------------------------------------------------------------------
//  FILE:    X2StrategyElement_XpackMissionSources.uc
//  AUTHOR:  Mark Nauta  --  06/23/2016
//  PURPOSE: Define new XPACK mission source templates
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2StrategyElement_XpackMissionSources extends X2StrategyElement_DefaultMissionSources
	config(GameData);

var config int MaxResOpsPerCampaign;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> MissionSources;

	// Faction Tutorial Mission
	MissionSources.AddItem(CreateLostAndAbandonedTemplate());

	MissionSources.AddItem(CreateResistanceOpTemplate());
	MissionSources.AddItem(CreateRescueSoldierTemplate());
	MissionSources.AddItem(CreateChosenAmbushTemplate());
	MissionSources.AddItem(CreateChosenStrongholdTemplate());
	MissionSources.AddItem(CreateChosenAvengerAssaultTemplate());

	return MissionSources;
}

// MEET FACTION
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateLostAndAbandonedTemplate()
{
	local X2MissionSourceTemplate Template;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_LostAndAbandoned');
	Template.DifficultyValue = 1;
	Template.bCannotBackOutUI = true;
	Template.bCannotBackOutSquadSelect = true;
	Template.OnSuccessFn = LostAndAbandonedOnComplete;
	Template.OnFailureFn = LostAndAbandonedOnFailure;
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromTemplate;
//BEGIN AUTOGENERATED CODE: Template Overrides 'MissionSource_LostAndAbandoned'
	Template.OverworldMeshPath = "UI_3D.Overwold_Final.ResOps";
//END AUTOGENERATED CODE: Template Overrides 'MissionSource_LostAndAbandoned'
	Template.MissionImage = "img:///UILibrary_StrategyImages.X2StrategyMap.Alert_Flight_Device";
	Template.SpawnMissionsFn = SpawnLostAndAbandonedMission;
	Template.MissionPopupFn = LostAndAbandonedPopup;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;
	Template.GetMissionRegionFn = GetCalendarMissionRegion;
	Template.CustomLoadingMovieName_Intro = "CIN_XP_LostAbandoned_01_Loading.bk2";
	Template.CustomLoadingMovieName_IntroSound = "Skyranger_LoadingScreen_Engines";
	Template.CustomLoadingMovieName_Outro = "CIN_XP_28_LostEvac.bk2";
	Template.CustomLoadingMovieName_OutroSound = "X2_XP_28_Lost_Evac";
	Template.CustomMusicSet = 'LostAndAbandoned';
	Template.bBlockFirstEncounterVO = true;
	Template.bBlockSitrepDisplay = true;
	Template.bRequiresSkyrangerTravel = true;
	Template.bBlocksNegativeTraits = true;
	Template.bBlockShaken = true;

	return Template;
}

static function LostAndAbandonedOnComplete(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResHQ;
	local XComGameState_ResistanceFaction FactionState;
	local XComGameState_Unit MissionUnitState, UnitState;
	local XComGameState_Item WeaponState;
	local XComGameState_AdventChosen ChosenState;
	local X2CharacterTemplateManager CharTemplateMgr;
	local X2CharacterTemplate CharacterTemplate;
	local int SquadIdx, MinReadyWill;

	GiveRewards(NewGameState, MissionState);

	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	if (ResHQ.ActivePOIs.Length == 0)
	{
		ResHQ.AttemptSpawnRandomPOI(NewGameState);
	}
	
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ResistanceOpsCompleted');

	// Make sure XCOM meets the Reapers and gets Elena as a reward
	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	
	FactionState = GetReaperFactionState();
	if (FactionState != none && !FactionState.bMetXCom)
	{
		for(SquadIdx = 0; SquadIdx < XComHQ.Squad.Length; SquadIdx++)
		{
			MissionUnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[SquadIdx].ObjectID));
			if (MissionUnitState != none)
			{
				if (MissionUnitState.GetMyTemplateName() == 'LostAndAbandonedElena')
				{
					CharTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
					CharacterTemplate = CharTemplateMgr.FindCharacterTemplate('ReaperSoldier');

					// Create the new unit and make sure she has the best gear available (will also update to appropriate armor customizations)
					UnitState = CharacterTemplate.CreateInstanceFromTemplate(NewGameState);
					UnitState.ApplySquaddieLoadout(NewGameState);
					UnitState.ApplyBestGearLoadout(NewGameState);
					UnitState.SetStatus(eStatus_Active);
					UnitState.bNeedsNewClassPopup = false;

					// Will overwrite any gear specific customization so she correctly matches the mission (ie plated armor look with conv gear)
					UnitState.SetTAppearance(MissionUnitState.kAppearance);
					UnitState.SetCharacterName(MissionUnitState.GetFirstName(), MissionUnitState.GetLastName(), MissionUnitState.GetNickName());
					UnitState.SetCountry(MissionUnitState.GetCountry());
					UnitState.SetBackground(MissionUnitState.GetBackground());

					// Make sure that primary and secondary weapon appearances match
					WeaponState = UnitState.GetPrimaryWeapon();
					WeaponState.WeaponAppearance = MissionUnitState.GetPrimaryWeapon().WeaponAppearance;
					WeaponState = UnitState.GetSecondaryWeapon();
					WeaponState.WeaponAppearance = MissionUnitState.GetSecondaryWeapon().WeaponAppearance;

					XComHQ.AddToCrew(NewGameState, UnitState);

					UnitState.SetCurrentStat(eStat_HP, MissionUnitState.GetCurrentStat(eStat_HP));
					UnitState.SetCurrentStat(eStat_Will, MissionUnitState.GetCurrentStat(eStat_Will));
					UnitState.AddXp(MissionUnitState.GetXPValue() - UnitState.GetXPValue());
					UnitState.CopyKills(MissionUnitState);
					UnitState.CopyKillAssists(MissionUnitState);
					UnitState.LowestHP = MissionUnitState.LowestHP;
					UnitState.HighestHP = MissionUnitState.HighestHP;
					UnitState.bRankedUp = false;

					// Bump up Elena's will to be Ready if she is Tired, so she can go on the next mission
					MinReadyWill = UnitState.GetMinWillForMentalState(eMentalState_Ready);
					if (UnitState.GetCurrentStat(eStat_Will) < MinReadyWill)
					{
						UnitState.SetCurrentStat(eStat_Will, MinReadyWill);
						UnitState.UpdateMentalState();
					}

					// Replace the mission Elena in the squad with the new one, so she appears on the walkup for promotions
					XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
					XComHQ.Squad[SquadIdx].ObjectID = UnitState.ObjectID;
				}
				else if (MissionUnitState.GetMyTemplateName() == 'LostAndAbandonedMox')
				{
					CharTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
					CharacterTemplate = CharTemplateMgr.FindCharacterTemplate('SkirmisherSoldier');

					// Create the new unit and make sure he has the best gear available (will also update to appropriate armor customizations)
					UnitState = CharacterTemplate.CreateInstanceFromTemplate(NewGameState);
					UnitState.ApplySquaddieLoadout(NewGameState);
					UnitState.ApplyBestGearLoadout(NewGameState);
					UnitState.SetStatus(eStatus_Active);
					UnitState.bNeedsNewClassPopup = false;
					
					// Will overwrite any gear specific customization so she correctly matches the mission (ie plated armor look with conv gear)
					UnitState.SetTAppearance(MissionUnitState.kAppearance);
					UnitState.SetCharacterName(MissionUnitState.GetFirstName(), MissionUnitState.GetLastName(), MissionUnitState.GetNickName());
					UnitState.SetCountry(MissionUnitState.GetCountry());
					UnitState.SetBackground(MissionUnitState.GetBackground());
					
					// Make sure that primary and secondary weapon appearances match
					WeaponState = UnitState.GetPrimaryWeapon();
					WeaponState.WeaponAppearance = MissionUnitState.GetPrimaryWeapon().WeaponAppearance;
					WeaponState = UnitState.GetSecondaryWeapon();
					WeaponState.WeaponAppearance = MissionUnitState.GetSecondaryWeapon().WeaponAppearance;
					
					UnitState.AddXp(MissionUnitState.GetXPValue() - UnitState.GetXPValue());
					UnitState.CopyKills(MissionUnitState);
					UnitState.CopyKillAssists(MissionUnitState);

					// Set Mox as captured and remove him from the squad
					UnitState.bCaptured = true;
					XComHQ.Squad.Remove(SquadIdx, 1);
					SquadIdx--;

					foreach History.IterateByClassType(class'XComGameState_AdventChosen', ChosenState)
					{
						if (ChosenState.GetMyTemplateName() == 'Chosen_Assassin')
						{
							ChosenState = XComGameState_AdventChosen(NewGameState.ModifyStateObject(class'XComGameState_AdventChosen', ChosenState.ObjectID));
							ChosenState.bCapturedSoldier = true;
							ChosenState.CapturedSoldiers.AddItem(UnitState.GetReference());
							ChosenState.TotalCapturedSoldiers++;
							ChosenState.ModifyKnowledgeScore(NewGameState, ChosenState.GetScaledKnowledgeDelta(class'XComGameState_AdventChosen'.default.KnowledgePerCapture));
							UnitState.ChosenCaptorRef = ChosenState.GetReference();
							break;
						}
					}
				}
			}
		}

		// XCom needs to officially meet the Reapers.
		FactionState = XComGameState_ResistanceFaction(NewGameState.ModifyStateObject(class'XComGameState_ResistanceFaction', FactionState.ObjectID));
		FactionState.MeetXCom(NewGameState);
	}
	
	`XEVENTMGR.TriggerEvent('LostAndAbandonedComplete', , , NewGameState);
}

static function LostAndAbandonedOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	FinalMissionOnFailure(NewGameState, MissionState);
}

static function SpawnLostAndAbandonedMission(XComGameState NewGameState, int MissionMonthIndex)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_MissionSite MissionState;
	local X2MissionSourceTemplate MissionSource;
	local XComGameState_MissionCalendar CalendarState;
	local XComGameState_ResistanceFaction FactionState;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate('MissionSource_LostAndAbandoned'));

	MissionState = BuildResOpMission(NewGameState, MissionSource, true);

	FactionState = GetReaperFactionState();
	if (FactionState != none)
	{
		MissionState.ResistanceFaction = FactionState.GetReference();
	}
	else
	{
		`Redscreen("@jweinhoffer Lost and Abandoned spawned, but could not find the Reaper faction!");
	}
	
	`XEVENTMGR.TriggerEvent('LostAndAbandonedSpawned', MissionState, MissionState, NewGameState);

	// Set Popup and mission source flags in the calendar - do this after creating the mission so rewards are generated properly
	CalendarState = GetMissionCalendar(NewGameState);
	CalendarState.MissionPopupSources.AddItem('MissionSource_LostAndAbandoned');
	CalendarState.CreatedMissionSources.AddItem('MissionSource_LostAndAbandoned');
}

static function LostAndAbandonedPopup(optional XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_MissionSite ResOpState;

	if (MissionState == none)
	{
		History = `XCOMHISTORY;

		foreach History.IterateByClassType(class'XComGameState_MissionSite', ResOpState)
		{
			if (ResOpState.Source == 'MissionSource_LostAndAbandoned' && ResOpState.Available)
			{
				break;
			}
		}
	}

	`HQPRES.UILostAndAbandonedMission(ResOpState);
}

static function XComGameState_ResistanceFaction GetReaperFactionState()
{
	local XComGameStateHistory History;
	local XComGameState_ResistanceFaction FactionState;

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
	{
		if (FactionState.GetMyTemplateName() == 'Faction_Reapers')
		{
			break;
		}
	}
	
	return FactionState;
}

// RESISTANCE OP
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateResistanceOpTemplate()
{
	local X2MissionSourceTemplate Template;
	local RewardDeckEntry DeckEntry;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_ResistanceOp');
	Template.bIncreasesForceLevel = false;
	Template.bDisconnectRegionOnFail = true;
	Template.OnSuccessFn = ResOpOnSuccess;
	Template.OnFailureFn = ResOpOnFailure;
	Template.OnExpireFn = ResOpOnExpire;
//BEGIN AUTOGENERATED CODE: Template Overrides 'MissionSource_ResistanceOp'
	Template.OverworldMeshPath = "UI_3D.Overwold_Final.ResOps";
	Template.MissionImage = "img://UILibrary_Common.Councilman_small";
//END AUTOGENERATED CODE: Template Overrides 'MissionSource_ResistanceOp'
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromMonth;
	Template.SpawnMissionsFn = SpawnResOpMission;
	Template.MissionPopupFn = ResOpPopup;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;
	Template.GetMissionRegionFn = GetCalendarMissionRegion;

	DeckEntry.RewardName = 'Reward_Scientist';
	DeckEntry.Quantity = 1;
	Template.RewardDeck.AddItem(DeckEntry);
	DeckEntry.RewardName = 'Reward_Engineer';
	DeckEntry.Quantity = 1;
	Template.RewardDeck.AddItem(DeckEntry);

	return Template;
}

static function ResOpOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local array<int> ExcludeIndices;

	ExcludeIndices = GetResOpExcludeRewards(MissionState);
	MissionState.bUsePartialSuccessText = (ExcludeIndices.Length > 0);
	GiveRewards(NewGameState, MissionState, ExcludeIndices);
	SpawnPointOfInterest(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ResistanceOpsCompleted');
	
	`XEVENTMGR.TriggerEvent('ResistanceOpComplete', , , NewGameState);
}

static function ResOpOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local array<int> ExcludeIndices;

	if (!IsInStartingRegion(MissionState))
	{
		LoseContactWithMissionRegion(NewGameState, MissionState, true);
	}

	// Even though the primary objective was failed, we still want to check if secondary objectives were completed and award those soldiers
	ExcludeIndices = GetResOpExcludeRewards(MissionState);
	ExcludeIndices.AddItem(0); // Exclude the primary VIP
	ExcludeIndices.AddItem(1); // Exclude the Intel reward
	GiveRewards(NewGameState, MissionState, ExcludeIndices);

	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.DeactivatePOI(NewGameState, MissionState.POIToSpawn);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ResistanceOpsFailed');

	`XEVENTMGR.TriggerEvent('ResistanceOpComplete', , , NewGameState);
}

static function ResOpOnExpire(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	if (!IsInStartingRegion(MissionState))
	{
		LoseContactWithMissionRegion(NewGameState, MissionState, false);
		`XEVENTMGR.TriggerEvent('SkippedMissionLostContact', , , NewGameState);
	}

	class'XComGameState_HeadquartersResistance'.static.DeactivatePOI(NewGameState, MissionState.POIToSpawn);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ResistanceOpsFailed');
}

static function array<int> GetResOpExcludeRewards(XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local array<int> ExcludeIndices;
	local int idx;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`assert(BattleData.m_iMissionID == MissionState.ObjectID);

	for (idx = 0; idx < BattleData.MapData.ActiveMission.MissionObjectives.Length; idx++)
	{
		// SecondaryVIP_01 and SoldierVIP are the tags for the first soldier unit rescued in Gather Survivors and Recover Expedition, respectively
		if ((BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'SecondaryVIP_01' ||
			BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'SoldierVIP') &&
			!BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted)
		{
			// Index should always be 2, since the first two rewards are Intel and the Sci / Eng VIP
			ExcludeIndices.AddItem(2);
		}

		// SecondaryVIP_02 is the second soldier rescued in Gather Survivors
		if (BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'SecondaryVIP_02' &&
			!BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted)
		{
			ExcludeIndices.AddItem(3);
		}
	}

	return ExcludeIndices;
}

//---------------------------------------------------------------------------------------
static function XComGameState_ResistanceFaction SelectRandomResistanceOpFaction()
{
	local XComGameStateHistory History;
	local XComGameState_ResistanceFaction FactionState;
	local array<XComGameState_ResistanceFaction> AvailableFactions;

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
	{
		if (FactionState.bMetXCom)
		{
			AvailableFactions.AddItem(FactionState);
		}
	}

	if (AvailableFactions.Length > 0)
	{
		FactionState = AvailableFactions[`SYNC_RAND_STATIC(AvailableFactions.Length)];
	}

	if (FactionState == none)
	{
		`Redscreen("@jweinhoffer @gameplay No Factions could not be found for Resistance Op mission.");
	}

	return FactionState;
}

//---------------------------------------------------------------------------------------
static function name SelectResistanceOpRewardType(XComGameState_MissionCalendar CalendarState)
{
	local X2StrategyElementTemplateManager TemplateManager;
	local X2RewardTemplate RewardTemplate;
	local name RewardType;
	local int SourceIndex, Index;
	local bool bFoundNeededReward, bIgnoreAvailability;
	local array<name> SkipList;

	SourceIndex = CalendarState.MissionRewardDecks.Find('MissionSource', 'MissionSource_ResistanceOp');

	// Refill the deck if empty
	if (SourceIndex == INDEX_NONE || CalendarState.MissionRewardDecks[SourceIndex].Rewards.Length == 0)
	{
		CreateResistanceOpRewards(CalendarState);
	}

	SourceIndex = CalendarState.MissionRewardDecks.Find('MissionSource', 'MissionSource_ResistanceOp');

	// first resistance op mission is always a scientist reward
	if (!CalendarState.HasCreatedMissionOfSource('MissionSource_ResistanceOp') && !CalendarState.HasCreatedMissionOfSource('MissionSource_LostAndAbandoned'))
	{
		RewardType = 'Reward_Scientist';
		Index = CalendarState.MissionRewardDecks[SourceIndex].Rewards.Find(RewardType);

		if (Index != INDEX_NONE)
		{
			CalendarState.MissionRewardDecks[SourceIndex].Rewards.Remove(Index, 1);
		}
	}
	else
	{
		while (RewardType == '')
		{
			TemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

			// Check if there is a reward that the player badly needs, if so use it as the reward
			for (Index = 0; Index < CalendarState.MissionRewardDecks[SourceIndex].Rewards.Length; Index++)
			{
				if (SkipList.Find(CalendarState.MissionRewardDecks[SourceIndex].Rewards[Index]) == INDEX_NONE)
				{
					RewardType = CalendarState.MissionRewardDecks[SourceIndex].Rewards[Index];
					RewardTemplate = X2RewardTemplate(TemplateManager.FindStrategyElementTemplate(RewardType));
					if (RewardTemplate != none)
					{
						if (bIgnoreAvailability || (RewardTemplate.IsRewardNeededFn != none && RewardTemplate.IsRewardNeededFn()))
						{
							CalendarState.MissionRewardDecks[SourceIndex].Rewards.Remove(Index, 1);
							bFoundNeededReward = true;
							break;
						}
						else // If the reward does not have have an IsRewardNeededFn, or it has failed, add it to the skip list so that reward type isn't checked again
						{
							SkipList.AddItem(RewardType);
							RewardType = ''; // Clear the reward type
						}
					}
				}
			}

			if (!bFoundNeededReward)
			{
				// take the first reward that is valid for this point in the game
				for (Index = 0; Index < CalendarState.MissionRewardDecks[SourceIndex].Rewards.Length; Index++)
				{
					RewardType = CalendarState.MissionRewardDecks[SourceIndex].Rewards[Index];
					RewardTemplate = X2RewardTemplate(TemplateManager.FindStrategyElementTemplate(RewardType));
					if (RewardTemplate != none && (bIgnoreAvailability || (RewardTemplate.IsRewardAvailableFn == none || RewardTemplate.IsRewardAvailableFn())))
					{
						CalendarState.MissionRewardDecks[SourceIndex].Rewards.Remove(Index, 1);
						break;
					}
					else
					{
						RewardType = ''; // Clear the reward type
					}
				}
			}

			if (RewardType == '')
			{
				// If we're starting over with a new reward deck, wipe the old one to get rid of any excluded stragglers
				CalendarState.MissionRewardDecks[SourceIndex].Rewards.Length = 0;
				CreateResistanceOpRewards(CalendarState);
				bIgnoreAvailability = true; // Already cycled through every reward once, so ignore availability functions the second time
			}
		}
	}

	return RewardType;
}

//---------------------------------------------------------------------------------------
static function CreateResistanceOpRewards(XComGameState_MissionCalendar CalendarState)
{
	local X2StrategyElementTemplateManager StratMgr;
	local X2MissionSourceTemplate MissionSource;
	local array<name> Rewards;
	local int idx, SourceIndex;
	local MissionRewardDeck RewardDeck;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate('MissionSource_ResistanceOp'));
	Rewards = GetShuffledRewardDeck(MissionSource.RewardDeck);

	SourceIndex = CalendarState.MissionRewardDecks.Find('MissionSource', 'MissionSource_ResistanceOp');

	if (SourceIndex == INDEX_NONE)
	{
		RewardDeck.MissionSource = 'MissionSource_ResistanceOp';
		CalendarState.MissionRewardDecks.AddItem(RewardDeck);
		SourceIndex = CalendarState.MissionRewardDecks.Find('MissionSource', 'MissionSource_ResistanceOp');
	}

	// Append to end of current list
	for (idx = 0; idx < Rewards.Length; idx++)
	{
		CalendarState.MissionRewardDecks[SourceIndex].Rewards.AddItem(Rewards[idx]);
	}
}

static function SpawnResOpMission(XComGameState NewGameState, int MissionMonthIndex)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_MissionSite MissionState;
	local XComGameState_ResistanceFaction FactionState;
	local X2MissionSourceTemplate MissionSource;
	local XComGameState_MissionCalendar CalendarState;

	CalendarState = GetMissionCalendar(NewGameState);

	// We only want a limited amount of Res Ops per campaign
	if(CalendarState.GetNumTimesMissionSourceCreated('MissionSource_ResistanceOp') >= default.MaxResOpsPerCampaign)
	{
		SpawnCouncilMission(NewGameState, MissionMonthIndex);
		return;
	}

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate('MissionSource_ResistanceOp'));
	
	MissionState = BuildResOpMission(NewGameState, MissionSource);
	FactionState = SelectRandomResistanceOpFaction();
	MissionState.ResistanceFaction = FactionState.GetReference();
	
	// Set Popup and mission source flags in the calendar - do this after creating the mission so rewards are generated properly
	CalendarState.MissionPopupSources.AddItem('MissionSource_ResistanceOp');
	CalendarState.CreatedMissionSources.AddItem('MissionSource_ResistanceOp');
}

private static function XComGameState_MissionSite BuildResOpMission(XComGameState NewGameState, X2MissionSourceTemplate MissionSource, optional bool bNoPOI)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_MissionSite MissionState;
	local XComGameState_WorldRegion RegionState;
	local XComGameState_MissionCalendar CalendarState;
	local XComGameState_Reward RewardState;
	local X2RewardTemplate RewardTemplate;
	local array<XComGameState_Reward> MissionRewards;
	local array<XComGameState_WorldRegion> PossibleRegions;
	local float MissionDuration;
	local XComGameState_HeadquartersResistance ResHQ;
	
	// Calculate Mission Expiration timer
	MissionDuration = float((default.MissionMinDuration + `SYNC_RAND_STATIC(default.MissionMaxDuration - default.MissionMinDuration + 1)) * 3600);

	PossibleRegions = MissionSource.GetMissionRegionFn(NewGameState);
	RegionState = PossibleRegions[0];

	// Generate the mission reward (either Scientist or Engineer)
	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	CalendarState = GetMissionCalendar(NewGameState);
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate(SelectResistanceOpRewardType(CalendarState)));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
	RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
	AddTacticalTagToRewardUnit(NewGameState, RewardState, 'VIPReward');
	MissionRewards.AddItem(RewardState);

	// All Resistance Op missions also give an Intel reward
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Intel'));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
	RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
	MissionRewards.AddItem(RewardState);

	MissionState = XComGameState_MissionSite(NewGameState.CreateNewStateObject(class'XComGameState_MissionSite'));

	// If first on non-narrative, do not allow Swarm Defense since the reinforcement groups will be too strong
	if (!(XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings')).bXPackNarrativeEnabled) &&
		!CalendarState.HasCreatedMissionOfSource('MissionSource_ResistanceOp'))
	{
		MissionState.ExcludeMissionFamilies.AddItem("SwarmDefense");
	}

	MissionState.BuildMission(MissionSource, RegionState.GetRandom2DLocationInRegion(), RegionState.GetReference(), MissionRewards, true, true, , MissionDuration);
	
	if (!bNoPOI)
	{
		MissionState.PickPOI(NewGameState);
	}

	if (MissionState.GeneratedMission.Mission.MissionFamily == "GatherSurvivors" ||	MissionState.GeneratedMission.Mission.MissionFamily == "RecoverExpedition")
	{
		// Gather Survivors and Recover Expedition have an optional soldier reward
		RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Soldier'));
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
		AddTacticalTagToRewardUnit(NewGameState, RewardState, 'SoldierRewardA');
		MissionState.Rewards.AddItem(RewardState.GetReference());
	}

	if (MissionState.GeneratedMission.Mission.MissionFamily == "GatherSurvivors")
	{
		// Gather Survivors missions also have a second optional soldier to rescue
		RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Soldier'));
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
		AddTacticalTagToRewardUnit(NewGameState, RewardState, 'SoldierRewardB');
		MissionState.Rewards.AddItem(RewardState.GetReference());
	}

	return MissionState;
}

private static function AddTacticalTagToRewardUnit(XComGameState NewGameState, XComGameState_Reward RewardState, name TacticalTag)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));
	if (UnitState != none)
	{
		UnitState.TacticalTag = TacticalTag;
	}
}

static function ResOpPopup(optional XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_MissionSite ResOpState;

	if (MissionState == none)
	{
		History = `XCOMHISTORY;

		foreach History.IterateByClassType(class'XComGameState_MissionSite', ResOpState)
		{
			if (ResOpState.Source == 'MissionSource_ResistanceOp' && ResOpState.Available)
			{
				break;
			}
		}
	}

	`HQPRES.UIResistanceOpMission(ResOpState);
}

// CHOSEN AMBUSH
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateRescueSoldierTemplate()
{
	local X2MissionSourceTemplate Template;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_RescueSoldier');
	Template.bIncreasesForceLevel = false;
	Template.OnSuccessFn = RescueSoldierOnSuccess;
	Template.OnFailureFn = RescueSoldierOnFailure;
	Template.OnExpireFn = RescueSoldierOnExpire;
//BEGIN AUTOGENERATED CODE: Template Overrides 'MissionSource_RescueSoldier'
	Template.OverworldMeshPath = "StaticMesh'UI_3D.Overwold_Final.RescueOps'";
	Template.MissionImage = "img:///UILibrary_XPACK_StrategyImages.DarkEvent_The_Collectors";
//END AUTOGENERATED CODE: Template Overrides 'MissionSource_RescueSoldier'
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromMonth;
	Template.MissionPopupFn = RescueSoldierPopup;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;
	
	return Template;
}

static function RescueSoldierOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersResistance ResHQ;

	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	ResHQ.AttemptSpawnRandomPOI(NewGameState);

	GiveRewards(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_RescueSoldierCompleted');
	
	`XEVENTMGR.TriggerEvent('RescueSoldierComplete', , , NewGameState);
}

static function RescueSoldierOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_RescueSoldierFailed');

	`XEVENTMGR.TriggerEvent('RescueSoldierComplete', , , NewGameState);
}

static function RescueSoldierOnExpire(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_RescueSoldierFailed');
}

static function RescueSoldierPopup(optional XComGameState_MissionSite MissionState)
{
	`HQPRES.UIRescueSoldierMission(MissionState);
}

// CHOSEN AMBUSH
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateChosenAmbushTemplate()
{
	local X2MissionSourceTemplate Template;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_ChosenAmbush');
	Template.bSkipRewardsRecap = true;
	Template.bCannotBackOutUI = true;
	Template.bCannotBackOutSquadSelect = true;
	Template.CustomLoadingMovieName_Intro = "1080_LoadingScreen_Advent_8.bk2";
	Template.bRequiresSkyRangerTravel = false;
	Template.OnSuccessFn = ChosenAmbushOnSuccess;
	Template.OnFailureFn = ChosenAmbushOnFailure;	
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromMonth;
	Template.MissionPopupFn = ChosenAmbushPopup;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;

	//BEGIN AUTOGENERATED CODE: Template Overrides 'MissionSource_ChosenAmbush'
	Template.OverworldMeshPath = "UI_3D.Overwold_Final.EscapeAmbush";
	Template.MissionImage = "img:///UILibrary_XPACK_StrategyImages.Mission_ChosenAmbush";
	//END AUTOGENERATED CODE: Template Overrides 'MissionSource_ChosenAmbush'

	return Template;
}

static function ChosenAmbushOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResHQ;
		
	// Spawn a POI and save the next time ambushes can occur
	ResHQ = GetAndAddResHQ(NewGameState);
	ResHQ.AttemptSpawnRandomPOI(NewGameState);
	ResHQ.SaveNextCovertActionAmbushTime();
	ResHQ.UpdateCovertActionNegatedRisks(NewGameState);

	// Flag the ambush as completed
	XComHQ = GetAndAddXComHQ(NewGameState);
	XComHQ.bWaitingForChosenAmbush = false;

	GiveRewards(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ChosenAmbushCompleted');
}

static function ChosenAmbushOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResHQ;

	// Save the next time ambushes can occur
	ResHQ = GetAndAddResHQ(NewGameState);
	ResHQ.SaveNextCovertActionAmbushTime();
	ResHQ.UpdateCovertActionNegatedRisks(NewGameState);

	// Flag the ambush as completed
	XComHQ = GetAndAddXComHQ(NewGameState);
	XComHQ.bWaitingForChosenAmbush = false;

	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ChosenAmbushFailed');
}

static function ChosenAmbushPopup(optional XComGameState_MissionSite MissionState)
{
	`HQPRES.UIChosenAmbushMission(MissionState);
}

// CHOSEN STRONGHOLD
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateChosenStrongholdTemplate()
{
	local X2MissionSourceTemplate Template;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_ChosenStronghold');
	Template.bIncreasesForceLevel = false;
	Template.DifficultyValue = 3;
//BEGIN AUTOGENERATED CODE: Template Overrides 'MissionSource_ChosenStronghold'
	Template.OverworldMeshPath = "StaticMesh'UI_3D.Overwold_Final.Chosen_Sarcophagus'";
	Template.MissionImage = "img:///UILibrary_XPACK_StrategyImages.Alert_Stronghold";
//END AUTOGENERATED CODE: Template Overrides 'MissionSource_ChosenStronghold'
	Template.OnSuccessFn = ChosenStrongholdOnSuccess;
	Template.OnFailureFn = ChosenStrongholdOnFailure;
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromTemplate;
	Template.MissionPopupFn = ChosenStrongholdPopup;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;
	Template.bIgnoreDifficultyCap = true;

	return Template;
}

static function ChosenStrongholdOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersResistance ResHQ;
	local XComGameState_AdventChosen ChosenState;
	
	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	ResHQ.AttemptSpawnRandomPOI(NewGameState);

	// If the player succeeded in the Stronghold mission, the Chosen has been killed
	ChosenState = MissionState.GetResistanceFaction().GetRivalChosen();	
	if (ChosenState != none)
	{
		// Mark the Chosen as permanently defeated
		ChosenState = XComGameState_AdventChosen(NewGameState.ModifyStateObject(class'XComGameState_AdventChosen', ChosenState.ObjectID));
		ChosenState.bDefeated = true;
	}

	GiveRewards(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);

	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ChosenStrongholdDestroyed');
}

static function ChosenStrongholdOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_AdventChosen ChosenState;

	MissionState.RemoveEntity(NewGameState);

	foreach NewGameState.IterateByClassType(class'XComGameState_AdventChosen', ChosenState)
	{
		if(ChosenState.bWasOnLastMission)
		{
			ChosenState.bFailedStrongholdMission = true;
			return;
		}
	}

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_AdventChosen', ChosenState)
	{
		if(ChosenState.bWasOnLastMission)
		{
			ChosenState = XComGameState_AdventChosen(NewGameState.ModifyStateObject(class'XComGameState_AdventChosen', ChosenState.ObjectID));
			ChosenState.bFailedStrongholdMission = true;
			return;
		}
	}
}

static function ChosenStrongholdPopup(optional XComGameState_MissionSite MissionState)
{
	`HQPRES.UIChosenStrongholdMission(MissionState);
}

// CHOSEN AVENGER ASSAULT
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateChosenAvengerAssaultTemplate()
{
	local X2MissionSourceTemplate Template;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_ChosenAvengerAssault');
	Template.DifficultyValue = 3;
	Template.bSkipRewardsRecap = true;
	Template.bCannotBackOutUI = true;
	Template.bCannotBackOutSquadSelect = true;
	Template.CustomMusicSet = 'Tutorial';
	Template.CustomLoadingMovieName_Intro = "1080_XP_LoadingScreen_SiegeCannon.bk2";
	Template.MissionImage = "img:///UILibrary_XPACK_StrategyImages.Alert_Avenger_Assault";
	Template.OverworldMeshPath = "StaticMesh'UI_3D.Overwold_Final.Retribution'";
	Template.bRequiresSkyRangerTravel = false;
	Template.OnSuccessFn = AvengerAssaultOnSuccess;
	Template.OnFailureFn = AvengerAssaultOnFailure;
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromTemplate;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;

	return Template;
}

static function AvengerAssaultOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_AdventChosen ChosenState;
	local XComGameState_MissionSiteChosenAssault ChosenAssault;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResHQ;

	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	ResHQ.AttemptSpawnRandomPOI(NewGameState);

	// Reset XComHQ's location so it can fly correctly when returning from the mission
	XComHQ = GetAndAddXComHQ(NewGameState);
	XComHQ.CurrentLocation.ObjectID = XComHQ.SavedLocation.ObjectID;

	ChosenAssault = XComGameState_MissionSiteChosenAssault(MissionState);
	if (ChosenAssault != none)
	{
		ChosenState = XComGameState_AdventChosen(NewGameState.ModifyStateObject(class'XComGameState_AdventChosen', ChosenAssault.AttackingChosen.ObjectID));
		ChosenState.SetKnowledgeLevel(NewGameState, eChosenKnowledge_Sentinel, false, true);
	}

	GiveRewards(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvengerAssaultCompleted');
}

static function AvengerAssaultOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	FinalMissionOnFailure(NewGameState, MissionState);
}
