class XGBaseCrewMgr extends Actor config(GameData)
	dependson(XComPhotographer_Strategy);

struct RoomCrewInstance
{
	var string DesiredSlotType;
	var string FullyQualifiedSlotName;
	var StateObjectReference CrewRef;
	var XComUnitPawn CrewPawn;
};

struct RoomCrew
{
	var array<RoomCrewInstance> Crew; //An array of crew that are currently populating the room	
};

struct RoomMatinee
{
	var string EventSuffix;
	var array<string> Slots;
};

struct RoomCinematics
{
	var array<RoomMatinee> Matinees;
};

struct QueuedBindingInfo
{
	var string BaseSlotName;
	var StateObjectReference CrewRef;
};

struct QueuedAddInfo
{
	var int RoomIdx;
	var QueuedBindingInfo SlotBinding;
};

struct StaffUpdateRequest
{
	var int RoomIndex; //Room index of the currently processing room
	var array<XComGameState_StaffSlot> StaffSlotArray; //Stored staff slots for the requested room
	var XComGameState_FacilityXCom FacilityStateObject; //If the currently processing room is a facility, store it here
};

// For specifying specific matinees and slots from rooms (used in Bond system)
struct RoomMatineeGroup
{
	var string RoomMapName; // Must be filled
	var string EventSuffix; // If empty will only check against slots
	var array<string> Slots; // If empty will include all slots with EventSuffix
};

// Used to record used matinees in priority passes before main pass on the base
struct RoomMatineeTracking
{
	var int RoomIndex;
	var int MatineeIndex;
};

var private array<QueuedAddInfo> m_fillCrewStack;
var private array<int> m_fillGhostStack;
var private array <RoomCrew> m_arrRoomCrew;
var private array <RoomCinematics> m_arrRoomCinemas;
var private int m_pendingPolaroids;

var private XComGameState_HeadquartersXCom XComHQ;
var private int NumHeadshots;
var private bool bScopedUseUnderlays; //If set to true while adding crew, soldiers will use their underlays

var private string GhostMatineeSlotName;
var private string SciOrEngSlotName;
var private string AnySlotName;

// Tracks room indices for the crew manager to update so that the room reflects the current game state
var private array<StaffUpdateRequest> PendingRoomUpdates;
var private array<StaffUpdateRequest> ProcessingRoomUpdates;

// Vars supporting the PendingRoomUpdates state machine
var private bool bLogPlacement;
var private int TempIterator;
var private int FillerSlotStart;
var private int StaffSlotIndex;
var private XComGameState_Unit StaffedUnit; //Unit that is occupying the currently processing staff slot
var private XComGameState_StaffSlot StaffSlotState; // The staff slot currently being processed
var private Vector TempRoomOffset; //Offset of the currently processing room
var private array<string> DelayedEventsToStart;
var private string TempStartEvent;
var private bool bAnyAssignedStaff;
var private bool bAnyStaffSlots;
var private bool bOnlySoldierStaffSlots;
var privatewrite int MaxGrievers; //Limit the number of grieving soldiers in the memorial to a number related to deaths
var int CurrentGrievers;
var private bool bAllPlacementsSuccessful;
var private int NumPlacementAttempts;
var private array<StateObjectReference> FullCrew; //Clerks + staffable units
var private XComUnitPawn UnitPawn;
var private Vector ZeroVec;
var private X2FacilityTemplate TempFacilityTemplate;
var private int CurrentVisibleCrew;
var private bool bIgnoreCrewLimits; // Used when placing bonded pairs so they don't get divided by the crew limit
var private bool bFullBasePopulate; // All rooms being repopulated. Need to know for soldier bond soldier placement.
var private array<RoomMatineeTracking> UsedRoomMatinees;

var private bool bIsPlacingCrew;

// Config vars
var config array<RoomMatineeGroup> SoldierBondMatinees; // Level 1 and 2
var config array<RoomMatineeGroup> ExclusiveBondMatinees; // Level 3 only
var config array<RoomMatineeGroup> NegativeTraitMatinees;

//------------------------------------------------------
//------------------------------------------------------
function Init()
{
	local Object ThisObj;
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	m_arrRoomCrew.Add(XComHQ.Rooms.Length);

	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'StaffUpdated', OnStaffUpdated, ELD_OnStateSubmitted);
}

function bool IsAlreadyPlaced(StateObjectReference ObjRef, int CheckRoomIdx=-1)
{
	local int RoomIdx;

	if(CheckRoomIdx < 0)
	{
		for(RoomIdx = 0; RoomIdx < m_arrRoomCrew.Length; ++RoomIdx)
		{
			if(m_arrRoomCrew[RoomIdx].Crew.Find('CrewRef', ObjRef) != -1)
			{
				return true;
			}
		}
	}
	else
	{
		if(m_arrRoomCrew[CheckRoomIdx].Crew.Find('CrewRef', ObjRef) != -1)
		{
			return true;
		}
	}

	return false;
}

function bool ShouldUseUnderlay()
{
	return bScopedUseUnderlays;
}

private function bool RoomHasAnimMap(int RoomIndex)
{
	return (`GAME.GetGeoscape().m_kBase.m_arrLvlStreaming_Anim[RoomIndex] != none);
}

private function string GetRoomMapName(int RoomIndex)
{
	local LevelStreaming AnimLevel;
	AnimLevel = `GAME.GetGeoscape().m_kBase.m_arrLvlStreaming_Anim[RoomIndex];
	if (AnimLevel != None)
	{
		return string(AnimLevel.PackageName);
	}
	else
	{
		return "";
	}
}

private function name GetFullyQualifiedVariableName(int RoomIndex, string VarName)
{
	local string RoomMapName;
	RoomMapName = GetRoomMapName(RoomIndex);
	
	if (RoomMapName != "")
	{
		return name(RoomMapName$"."$VarName);
	}
	else
	{
		return name(VarName);
	}
}

private function ReleaseNewCrewIfInUse(StateObjectReference newCrew)
{
	local int RoomIdx, CrewIdx;
	for( RoomIdx = 0; RoomIdx < m_arrRoomCrew.Length; ++RoomIdx)
	{
		CrewIdx = m_arrRoomCrew[RoomIdx].Crew.Find('CrewRef', newCrew);
		if (CrewIdx != -1)
		{
			m_arrRoomCrew[RoomIdx].Crew[CrewIdx].CrewPawn = none;
			`HQPRES.GetUIPawnMgr().ClearPawnVariable(name(m_arrRoomCrew[RoomIdx].Crew[CrewIdx].FullyQualifiedSlotName));
			`HQPRES.GetUIPawnMgr().ReleaseCinematicPawn(self, m_arrRoomCrew[RoomIdx].Crew[CrewIdx].CrewRef.ObjectID);
			m_arrRoomCrew[RoomIdx].Crew.Remove(CrewIdx, 1);
			break;
		}
	}
}

private function XComGameState_FacilityXCom GetSpecificRoom(name RoomName)
{
	local XComGameState_FacilityXCom FacilityState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	if( XComHQ.HasFacilityByName(RoomName) )
	{
		foreach History.IterateByClassType(class'XComGameState_FacilityXCom', FacilityState)
		{
			if( FacilityState.GetMyTemplateName() == RoomName )
			{
				return FacilityState;
			}
		}
	}

	return None;
}

function RefreshFacilityPatients()
{
	local XComGameState_FacilityXCom InfirmaryRoom;

	InfirmaryRoom = GetSpecificRoom('AdvancedWarfareCenter');
	if(InfirmaryRoom != none)
	{
		RequestStaffUpdate(InfirmaryRoom.GetRoom());
	}
}


private function UpdateCinematicMatinees(string RoomMapName, out RoomCinematics Cinematics, const out array<name> RoomVariables)
{
	local name RoomVar;
	local string SlotType, MatineeName, Temp;
	local int Split, MatineeIdx;
	local RoomMatinee Matinee;

	foreach RoomVariables(RoomVar)
	{
		Temp = string(RoomVar);
		Temp -= RoomMapName;
		Temp -= ".";
		
		Matinee.Slots.Length = 0;
		Matinee.EventSuffix = "";

		SlotType = GetRightMost(Temp);
		Split = InStr(Temp, "_");
		if (Split != -1)
		{
			MatineeName = Left(Temp, Split);
			MatineeIdx = Cinematics.Matinees.Find('EventSuffix', MatineeName);
			if (MatineeIdx != -1)
			{
				if (Cinematics.Matinees[MatineeIdx].Slots.Find(SlotType) != -1)
				{
					`Redscreen("Duplicate matinee pawn slot name \""$SlotType$"\" for matinee \""$MatineeName$"\"");
					continue;
				}

				// add to existing multiple pawn matinee
				Cinematics.Matinees[MatineeIdx].Slots.AddItem(SlotType);
			}
			else
			{
				// add multiple pawn matinee
				Matinee.EventSuffix = MatineeName;
				Matinee.Slots.AddItem(SlotType);
				Cinematics.Matinees.AddItem(Matinee);
			}
		}
		else
		{
			// add single pawn matinee
			Matinee.Slots.AddItem(SlotType);
			Cinematics.Matinees.AddItem(Matinee);
		}
	}
}


simulated function int SortBySlotCount(RoomMatinee Matinee1, RoomMatinee Matinee2)
{
	// favour more slots
	if (Matinee1.Slots.Length == Matinee2.Slots.Length)
	{
		// randomize in a given slot count bucket
		if (rand(Matinee1.Slots.Length) < rand(Matinee2.Slots.Length))
		{
			return -1;
		}
		else
		{
			return 1;
		}
	}
	else if (Matinee1.Slots.Length < Matinee2.Slots.Length)
	{
		return -1;
	}
	else 
	{
		return 1;
	}
}

private function UpdateRoomCinematics()
{
	local XComPresentationLayerBase XPres;
	local array<name> RoomVariables;
	local string RoomMapName;
	local RoomCinematics Cinematics;
	local int RoomIdx;

	XPres = `HQPRES;

	m_arrRoomCinemas.Length = 0;
	m_arrRoomCinemas.Length = XComHQ.Rooms.Length;

	for (RoomIdx = 0; RoomIdx < m_arrRoomCinemas.Length; ++RoomIdx)
	{
		RoomMapName = GetRoomMapName(RoomIdx);

		if (RoomMapName != "")
		{
			XPres.GetUIPawnMgr().GetPawnVariablesStartingWith(name(RoomMapName), RoomVariables);
			UpdateCinematicMatinees(RoomMapName, Cinematics, RoomVariables);

			Cinematics.Matinees.Sort(SortBySlotCount);
			m_arrRoomCinemas[RoomIdx] = Cinematics;

			Cinematics.Matinees.Length = 0;
		}

		RoomVariables.Length = 0;
	}
}

function RepopulateBaseRoomsWithCrew()
{
	RemoveBaseCrew();
	SetTimer(0.035, false, 'PopulateBaseRoomsWithCrew');
}

function PopulateBaseRoomsWithCrew()
{
	local int idx;	
	local int RoomCounter;
	local int RandSort;
	
	UpdateRoomCinematics();
	bFullBasePopulate = true;

	RandSort = `SYNC_RAND(2);
	
	//Change up the order that we process the rooms so that we get variety in the random staffing
	if(RandSort == 1)
	{
		for(idx = XComHQ.Rooms.Length - 1; idx > -1; idx--)
		{
			RequestStaffUpdate(XComHQ.GetRoom(idx));
		}
	}
	else
	{
		for(idx = 0; idx < XComHQ.Rooms.Length; idx++)
		{
			RequestStaffUpdate(XComHQ.GetRoom(idx));
		}
	}
		
	for(idx = 0; idx < XComHQ.Rooms.Length; idx++)
	{
		if(XComHQ.GetRoom(idx).GetFacility() != none && XComHQ.GetRoom(idx).GetFacility().StaffSlots.Length == 0)
		{
			++RoomCounter;
		}				
	}	

	CurrentGrievers = 0;
	MaxGrievers = XComHQ.DeadCrew.Length == 0 ? 0 : Max((XComHQ.DeadCrew.Length / 4), 1);

	UpdateHeadStaffLocations();

	RefreshCrewPhotographs();

	`XCOMGRI.DoRemoteEvent('CIN_StartAvenger');
	`XCOMGRI.DoRemoteEvent('CIN_StartCrew');
}

function UpdateHeadStaffLocations()
{	
	local XComGameStateHistory History;
	local XComGameState_Unit HeadScientistGameState;
	local XComGameState_Unit HeadEngineerGameState;
	local Actor HeadScientist;
	local Actor HeadEngineer;
	local Vector HeadScientistLocation;
	local Rotator HeadScientistRotation;
	local Vector HeadEngineerLocation;
	local Rotator HeadEngineerRotation;	
	local PointInSpace Locator;
	local XComUnitPawn Pawn;
	local XComGameState_StaffSlot StaffSlot;
	local bool bInShadowChamber;

	History = `XCOMHISTORY;

	foreach WorldInfo.AllActors(class'PointInSpace', Locator)
	{
		if(Locator.Tag == 'CIN_Location_HeadScientist')
		{
			HeadScientistLocation = Locator.Location;
			HeadScientistRotation = Locator.Rotation;
		}
		else if(Locator.Tag == 'CIN_Location_HeadEngineer')
		{
			HeadEngineerLocation = Locator.Location;
			HeadEngineerRotation = Locator.Rotation;
		}
	}

	//Check if the head scientist and engineer are in the shadow chamber. They go into the shadow chamber together so only need to check one
	HeadScientistGameState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.GetHeadScientistRef()));
	StaffSlot = XComGameState_StaffSlot(History.GetGameStateForObjectID(HeadScientistGameState.StaffingSlot.ObjectID));
	if(StaffSlot != none)
	{
		if(StaffSlot.GetFacility().GetMyTemplateName() == 'ShadowChamber')
		{
			bInShadowChamber = true;
		}		
	}
	
	HeadScientist = HeadScientistGameState.GetVisualizer();
	if(HeadScientist == none && !bInShadowChamber)
	{
		Pawn = HeadScientistGameState.CreatePawn(self, HeadScientistLocation, HeadScientistRotation, false);
		Pawn.RestoreAnimSetsToDefault();
		Pawn.GotoState('InHQ');
		Pawn.PlayHQIdleAnim();
		History.SetVisualizer(HeadScientistGameState.ObjectID, Pawn);
	}
	else if(bInShadowChamber)
	{
		History.SetVisualizer(HeadScientistGameState.ObjectID, none);
		HeadScientist.Destroy();
	}

	HeadEngineerGameState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.GetHeadEngineerRef()));
	HeadEngineer = HeadEngineerGameState.GetVisualizer();
	if(HeadEngineer == none && !bInShadowChamber)
	{
		Pawn = HeadEngineerGameState.CreatePawn(self, HeadEngineerLocation, HeadEngineerRotation, false);
		Pawn.RestoreAnimSetsToDefault();
		Pawn.GotoState('InHQ');
		Pawn.PlayHQIdleAnim();
		History.SetVisualizer(HeadEngineerGameState.ObjectID, Pawn);
	}
	else if(bInShadowChamber)
	{
		History.SetVisualizer(HeadEngineerGameState.ObjectID, none);
		HeadEngineer.Destroy();
	}
}

function RefreshCrewPhotographs()
{
	local StateObjectReference CrewRef;
	foreach XComHQ.Crew(CrewRef)
	{
		if (CrewRef.ObjectID > 0 && CrewRef.ObjectID != XComHQ.GetHeadEngineerRef() && CrewRef.ObjectID != XComHQ.GetHeadScientistRef())
		{
			TakeCrewPhotobgraph(CrewRef);
		}
	}

	foreach XComHQ.DeadCrew(CrewRef)
	{
		TakeCrewPhotobgraph(CrewRef);
	}
}

//Specify bForce if the photograph should be taken even if it is already cached ( for example, after a character has been customized )
function TakeCrewPhotobgraph(StateObjectReference UnitRef, bool bForce = false, bool bHighPriority = false )
{
	m_pendingPolaroids += 1;

	`HQPRES.GetPhotoboothAutoGen().AddHeadShotRequest(UnitRef, 512, 512, OnSoldierHeadCaptureFinished, class'X2StrategyElement_DefaultSoldierPersonalities'.static.Personality_ByTheBook(), , bHighPriority);
	`HQPRES.GetPhotoboothAutoGen().RequestPhotos();

	if (bForce)
	{
		RefreshWantedCaptures();
	}
}

private function OnSoldierHeadCaptureFinished(StateObjectReference UnitRef)
{
	m_pendingPolaroids -= 1;
	if( m_pendingPolaroids == 0 )
	{
		RefreshMemorialPolaroids();
	}
}

private function XComLevelActor GetPolaroidActor(int Idx)
{
	local XComLevelActor TheActor;

	foreach WorldInfo.AllActors(class'XComLevelActor', TheActor)
	{
		if (TheActor != none && TheActor.Tag == name("PolaroidActor"$(Idx+1)))
			break;
	}

	return TheActor;
}

function RefreshMemorialPolaroids()
{
	local XComLevelActor TheActor;
	local int SoldierIdx;
	local StateObjectReference UnitRef;
	local Texture2D SoldierPicture;
	local MaterialInterface Mat;
	local MaterialInstanceConstant NewMIC;
	local MaterialInstanceConstant InstancedMaterial;
	local XComGameState_CampaignSettings SettingsState;

	//The tag names start at 1 ...
	SoldierIdx = 1;
	foreach WorldInfo.AllActors(class'XComLevelActor', TheActor)
	{
		if(TheActor != none && TheActor.Tag == name("PolaroidActor"$SoldierIdx))
		{
			if((SoldierIdx - 1) < XComHQ.DeadCrew.Length)
			{
				UnitRef = XComHQ.DeadCrew[SoldierIdx - 1];
				SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
				SoldierPicture = `XENGINE.m_kPhotoManager.GetHeadshotTexture(SettingsState.GameIndex, UnitRef.ObjectID, 512, 512);

				Mat = TheActor.StaticMeshComponent.GetMaterial(0);
				InstancedMaterial = MaterialInstanceConstant(Mat);
				if(InstancedMaterial != none)
				{
					// If this is not a child MIC, make it one. This is done so that the material updates below don't stomp
					// on each other between units.
					if(InStr(InstancedMaterial.Name, "MaterialInstanceConstant") == INDEX_NONE)
					{
						NewMIC = new (self) class'MaterialInstanceConstant';
						NewMIC.SetParent(InstancedMaterial);
						TheActor.StaticMeshComponent.SetMaterial(0, NewMIC);
						InstancedMaterial = NewMIC;
					}

					InstancedMaterial.SetTextureParameterValue('PolaroidTexture', SoldierPicture);
					TheActor.StaticMeshComponent.SetHidden(false);
				}
			}
			else if(!TheActor.StaticMeshComponent.HiddenGame)
			{
				TheActor.StaticMeshComponent.SetHidden(true);
			}

			++SoldierIdx;
		}
	}
}

function FillHeadTexture()
{
	local XComGameState_Unit Unit;
	local int i;
	local StateObjectReference ObjRef;
	local Texture2D HeadTexture;
	local array<XComGameState_Unit> m_arrSoldiers;
	local Texture2DArray HeadsTexture;
	local XComGameState_CampaignSettings SettingsState;

	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	HeadsTexture = `XENGINE.HeadsTexture;
	
	// Determine 4 highest ranked soldiers
	for( i = 0; i < XComHQ.Crew.Length; i++ )
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.Crew[i].ObjectID));
		if( Unit.IsAlive() && Unit.GetMyTemplateName() == 'Soldier' )
		{
			m_arrSoldiers.AddItem(Unit);
		}
	}
	m_arrSoldiers.Sort(SortByRank);
		
	for( i = 0; i < min(4, m_arrSoldiers.Length); i++ )
	{
		Unit = m_arrSoldiers[i];
		ObjRef = Unit.GetReference();
		SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
		HeadTexture = `XENGINE.m_kPhotoManager.GetHeadshotTexture(SettingsState.GameIndex, ObjRef.ObjectID, 256, 256);
		if( i < HeadsTexture.NumTextures && HeadTexture != none )
		{
			HeadsTexture.SetTexture(i, HeadTexture);
		}
	}
	HeadsTexture.UpdateResourceScript();	
}

function OnWantedCaptureFinished(StateObjectReference UnitRef)
{
	NumHeadshots--;
	if( NumHeadshots == 0 )
	{
		FillHeadTexture();
	}
}

simulated function int SortByRank(XComGameState_Unit UnitA, XComGameState_Unit UnitB)
{
	local int RankA, RankB;

	RankA = UnitA.GetRank();
	RankB = UnitB.GetRank();

	if( RankA < RankB )
	{
		return -1;
	}
	else if( RankA > RankB )
	{
		return 1;
	}
	return 0;
}

function RefreshWantedCaptures()
{
	local array<XComGameState_Unit> m_arrSoldiers;
	local int i;
	local XComGameState_Unit Unit;
	local StateObjectReference ObjRef;

	// Determine 4 highest ranked soldiers
	for( i = 0; i < XComHQ.Crew.Length; i++ )
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.Crew[i].ObjectID));
		if( Unit.IsAlive() && Unit.GetMyTemplateName() == 'Soldier' )
		{
			m_arrSoldiers.AddItem(Unit);
		}
	}
	m_arrSoldiers.Sort(SortByRank);
	
	
	for( i = 0; i < min(4, m_arrSoldiers.Length); i++ )
	{
		Unit = m_arrSoldiers[i];
		ObjRef = Unit.GetReference();

		NumHeadshots++;
		`HQPRES.GetPhotoboothAutoGen().AddHeadShotRequest(ObjRef, 256, 256, OnWantedCaptureFinished, class'X2StrategyElement_DefaultSoldierPersonalities'.static.Personality_ByTheBook());
		`HQPRES.GetPhotoboothAutoGen().RequestPhotos();
	}
}

private function name GenerateEventName(string PreFix, int RoomIdx, RoomCrewInstance CrewInfo)
{
	local string BaseQualifiedName;
	local string GroupedName;
	local string RoomMapName;

	RoomMapName = GetRoomMapName(RoomIdx);
	assert(RoomMapName != "");

	BaseQualifiedName = CrewInfo.FullyQualifiedSlotName;
	BaseQualifiedName -= RoomMapName;
	BaseQualifiedName -= ".";

	GroupedName = GetRightMost(BaseQualifiedName);

	if (GroupedName != BaseQualifiedName)
	{
		BaseQualifiedName = Left(BaseQualifiedName, Len(BaseQualifiedName) - Len(GroupedName) - 1);
	}

	return name(PreFix$RoomMapName$"."$BaseQualifiedName);
}

private function int RemoveCrewFromOtherRoom(int DesiredRoomIdx, StateObjectReference CrewRef)
{
	local int VacatedIdx, CrewIdx;
	local name StopEvent;
	local XComPresentationLayerBase XPres;
	XPres = `HQPRES;

	for (VacatedIdx = 0; VacatedIdx < m_arrRoomCrew.Length; ++VacatedIdx)
	{
		CrewIdx = m_arrRoomCrew[VacatedIdx].Crew.Find('CrewRef', CrewRef);
		if (CrewIdx != -1)
		{			
			if (RoomHasAnimMap(VacatedIdx))
			{
				StopEvent = GenerateEventName("CIN_Stop", VacatedIdx, m_arrRoomCrew[VacatedIdx].Crew[CrewIdx]);
				`XCOMGRI.DoRemoteEvent(StopEvent);
			}

			m_arrRoomCrew[VacatedIdx].Crew[CrewIdx].CrewPawn = none;
			XPres.GetUIPawnMgr().ClearPawnVariable(name(m_arrRoomCrew[VacatedIdx].Crew[CrewIdx].FullyQualifiedSlotName));
			m_arrRoomCrew[VacatedIdx].Crew.Remove(CrewIdx, 1);
			return VacatedIdx;
		}
	}
		
	return -1;
}

private function bool SpawnAndAddCrewToRoom(int RoomIdx, X2FacilityTemplate FacilityTemplate, string DesiredSlotType, StateObjectReference CrewRef, bool bStaffSlot)
{
	local int NewIdx;
	local Rotator ZeroRotator;
	local Vector RoomOffset;
	local RoomCrewInstance CrewInfo;
	local XComPresentationLayerBase XPres;
	local name CineDummy;
	local int MaxAllowed;
	local int CurrentOfTemplate;
	local int CrewIndex;
	local XComGameState_Unit CrewStateObject;
	
	if( !bIgnoreCrewLimits && CurrentVisibleCrew >= `XPROFILESETTINGS.Data.MaxVisibleCrew && `XPROFILESETTINGS.Data.MaxVisibleCrew > 0 )
	{
		return false;
	}

	XPres = `HQPRES;

	//If this is not a staff slot, then check to see if we can add this crew member. It is assumed the staff slot logic vetted this transaction so we don't check in that condition
	if(!bStaffSlot)
	{
		//Count how many of this type of crew member there are for this room
		for(CrewIndex = 0; CrewIndex < m_arrRoomCrew[RoomIdx].Crew.Length; ++CrewIndex)
		{
			if(m_arrRoomCrew[RoomIdx].Crew[CrewIndex].DesiredSlotType == DesiredSlotType)
			{
				++CurrentOfTemplate;
			}
		}

		//Get the mac number allowed
		MaxAllowed = FacilityTemplate.GetMaxCrewOfTemplate(name(DesiredSlotType));
	}

	CrewStateObject = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(CrewRef.ObjectID));

	//Only add the crew member if we can sustain them, OR this is a staff slot we're filling
	if(bStaffSlot || CurrentOfTemplate < MaxAllowed)
	{
		`log("Adding"@CrewStateObject.GetFullName()@"("@CrewStateObject.GetMyTemplateName()@") to slot"@DesiredSlotType@"in facility"@FacilityTemplate.DisplayName, bLogPlacement);
		RoomOffset = `GAME.GetGeoscape().m_kBase.m_arrLvlStreaming_Anim[RoomIdx].Offset;
		NewIdx = m_arrRoomCrew[RoomIdx].Crew.Find('CrewRef', CrewRef);
		if(NewIdx != -1)
		{
			m_arrRoomCrew[RoomIdx].Crew[NewIdx].DesiredSlotType = DesiredSlotType;
		}
		else
		{
			CrewInfo.CrewRef = CrewRef;
			CrewInfo.DesiredSlotType = DesiredSlotType;
			CineDummy = GetFullyQualifiedVariableName(RoomIdx, "CineDummy");

			bScopedUseUnderlays = true;
			XPres.GetUIPawnMgr().ReleaseCinematicPawn(self, CrewRef.ObjectID);//Request a new pawn ( in case the existing one is tied up in matinee )
			CrewInfo.CrewPawn = XPres.GetUIPawnMgr().RequestCinematicPawn(self, CrewRef.ObjectID, RoomOffset, ZeroRotator, '', CineDummy);			
			
			//We want to minimize the impact it has on the game thread - RAM - restore when it's safe
			//CrewInfo.CrewPawn.SetUpdateSkelWhenNotRendered(false);
			
			bScopedUseUnderlays = false;

			m_arrRoomCrew[RoomIdx].Crew.AddItem(CrewInfo);
		}

		++CurrentVisibleCrew;

		return true;
	}

	if(CurrentOfTemplate >= MaxAllowed && MaxAllowed > 0)
	{
		`log("Adding"@CrewStateObject.GetFullName()@"("@CrewStateObject.GetMyTemplateName()@") to slot"@DesiredSlotType@"in facility"@FacilityTemplate.DisplayName@"was UNSUCCESSFUL. Hit max allowance of slot type: "@CurrentOfTemplate@"/"@MaxAllowed, bLogPlacement);
	}

	return false;
}

private function bool SlotTypeCriteriaMet(string DesiredType, string SlotType)
{
	if (InStr(DesiredType, AnySlotName) == 0)
		return true;

	if ((SlotType == "Engineer" || SlotType == "Scientist") && InStr(DesiredType, SciOrEngSlotName) == 0)
		return true;

	return (InStr(DesiredType, SlotType) == 0);
}

private function bool MatineeRequiresUpgrade(const out RoomMatinee Matinee, X2FacilityTemplate Template)
{
	local string SlotType;
	local name PotentialUpgradeSlotType;
	
	foreach Matinee.Slots(SlotType)
	{
		foreach Template.MatineeSlotsForUpgrades(PotentialUpgradeSlotType)
		{
			if(string(PotentialUpgradeSlotType) == SlotType)
			{
				return true;
			}
		}
	}

	return false;
}

private function bool CanSatifyMatineeSlots(const out array<RoomCrewInstance> CrewToPlace, const out RoomMatinee Matinee)
{
	local string SlotType;
	local array<int> PlacedCrew;
	local int MatchingCrewIdx;

	`log("Checking Matinee:"@Matinee.EventSuffix, bLogPlacement);

	foreach Matinee.Slots(SlotType)
	{
		`log("     Matching Slot ["$SlotType$"]", bLogPlacement);

		for (MatchingCrewIdx = 0; MatchingCrewIdx < CrewToPlace.Length; ++MatchingCrewIdx)
		{
			`log("     CrewToPlace["$MatchingCrewIdx$"] desired:"@CrewToPlace[MatchingCrewIdx].DesiredSlotType, bLogPlacement);
			if(PlacedCrew.Find(MatchingCrewIdx) != -1 || CrewToPlace[MatchingCrewIdx].FullyQualifiedSlotName != "")
			{				
				`log("          Already Placed...", bLogPlacement);
				continue;
			}	

			if (SlotTypeCriteriaMet(SlotType, CrewToPlace[MatchingCrewIdx].DesiredSlotType))
			{
				`log("          Met Criteria Placing...", bLogPlacement);
				PlacedCrew.AddItem(MatchingCrewIdx);
				break;
			}
			else
			{
				`log("          Failed Criteria continuing...", bLogPlacement);
			}
		}
	}

	`log("Checking Matinee Complete"@PlacedCrew.Length@"of"@Matinee.Slots.Length@"slots filled", bLogPlacement);

	return (PlacedCrew.Length == Matinee.Slots.Length);
}


private function AddIfUnique(out array<string> EventsToStart, string NewEvent)
{
	if (EventsToStart.Find(NewEvent) != -1)
		return;

	EventsToStart.AddItem(NewEvent);
}

private function int FillSlotsWithCrew(int RoomIdx, out array<RoomCrewInstance> CrewToPlace, out array<RoomCrewInstance> PlacedCrew, const out RoomMatinee Matinee, out array<string> EventsToStart)
{
	local string SlotType;
	local int MatchingCrewIdx;
	local XComPresentationLayerBase XPres;
	local string MatineeStartEvent;

	XPres = `HQPRES;

	foreach Matinee.Slots(SlotType)
	{
		for (MatchingCrewIdx = 0; MatchingCrewIdx < CrewToPlace.Length; ++MatchingCrewIdx)
		{
			if(PlacedCrew.Find('CrewRef', CrewToPlace[MatchingCrewIdx].CrewRef) != -1 || CrewToPlace[MatchingCrewIdx].FullyQualifiedSlotName != "")
				continue;

			if (SlotTypeCriteriaMet(SlotType, CrewToPlace[MatchingCrewIdx].DesiredSlotType))
			{
				if (Matinee.EventSuffix != "")
				{
					MatineeStartEvent = GetRoomMapName(RoomIdx) $ "." $ Matinee.EventSuffix;
					CrewToPlace[MatchingCrewIdx].FullyQualifiedSlotName = MatineeStartEvent $ "_" $ SlotType;

					AddIfUnique(EventsToStart, MatineeStartEvent);
				}
				else
				{
					CrewToPlace[MatchingCrewIdx].FullyQualifiedSlotName = GetRoomMapName(RoomIdx) $ "." $ SlotType;
					
					AddIfUnique(EventsToStart, CrewToPlace[MatchingCrewIdx].FullyQualifiedSlotName);
				}

				XPres.GetUIPawnMgr().SetPawnVariable(CrewToPlace[MatchingCrewIdx].CrewPawn, name(CrewToPlace[MatchingCrewIdx].FullyQualifiedSlotName));

				PlacedCrew.AddItem(CrewToPlace[MatchingCrewIdx]);
				CrewToPlace.Remove(MatchingCrewIdx--, 1);
				break;
			}
		}
	}

	return CrewToPlace.Length;
}

// Assigns bond and negative trait soldiers
private function AssignSpecialCaseCrew()
{
	local XComGameStateHistory History;
	local array<XComGameState_Unit> AllSoldiers, RandomizedSoldiers, PotentialBondmates, BondmatesToPlace, TraitUnitsToPlace;
	local XComGameState_Unit BondmateA, BondmateB, TraitUnit;
	local XComGameState_FacilityXCom FacilityState;
	local X2FacilityTemplate FacilityTemplate;
	local array<int> UsedSoldierIDs; // Track already placed soldiers so we don't reuse (for bonds)
	local array<RoomMatineeGroup> BondMatineeGroups, TraitMatineeGroups;
	local StateObjectReference BondmateRef;
	local SoldierBond Bond;
	local bool bFoundMatch;
	local int idx, RoomIdx, GroupIdx;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetGameStateForObjectID(XComHQ.ObjectID));
	AllSoldiers = XComHQ.GetSoldiers();
	BondMatineeGroups = default.SoldierBondMatinees;
	TraitMatineeGroups = default.NegativeTraitMatinees;
	UsedSoldierIDs.Length = 0;
	UsedRoomMatinees.Length = 0;

	// Randomize the order of the soldier list so we don't get the same bond pairs every time if there are many available at once
	while (AllSoldiers.Length > 0)
	{
		idx = `SYNC_RAND(AllSoldiers.Length);
		RandomizedSoldiers.AddItem(AllSoldiers[idx]);
		AllSoldiers.Remove(idx, 1);
	}

	// First Grab All Potential Bond Soldiers
	for(idx = 0; idx < RandomizedSoldiers.Length; idx++)
	{
		if(UsedSoldierIDs.Find(RandomizedSoldiers[idx].ObjectID) == INDEX_NONE)
		{
			BondmateA = RandomizedSoldiers[idx];

			if(BondmateA.CanAppearInBase() && !BondmateA.IsInjured() && !IsAlreadyPlaced(BondmateA.GetReference()))
			{
				if(BondmateA.HasSoldierBond(BondmateRef))
				{
					if(UsedSoldierIDs.Find(BondmateRef.ObjectID) == INDEX_NONE)
					{
						BondmateB = XComGameState_Unit(History.GetGameStateForObjectID(BondmateRef.ObjectID));

						if(BondmateB.CanAppearInBase() && !BondmateB.IsInjured() && !IsAlreadyPlaced(BondmateB.GetReference()) && BondmateA.GetBondData(BondmateRef, Bond) &&
						   class'X2StrategyGameRulesetDataStructures'.static.CanHaveBondAtLevel(BondmateA, BondmateB, (Bond.BondLevel + 1)))
						{
							UsedSoldierIDs.AddItem(BondmateA.ObjectID);
							UsedSoldierIDs.AddItem(BondmateB.ObjectID);
							BondmatesToPlace.AddItem(BondmateA);
							BondmatesToPlace.AddItem(BondmateB);
						}
					}
				}
				else
				{
					PotentialBondmates = class'X2StrategyGameRulesetDataStructures'.static.GetAllValidSoldierBondsAtLevel(BondmateA, 1);
					bFoundMatch = false;
					
					while(PotentialBondmates.Length > 0 && !bFoundMatch)
					{
						BondmateB = PotentialBondmates[0];

						if(UsedSoldierIDs.Find(BondmateB.ObjectID) == INDEX_NONE && BondmateB.CanAppearInBase() && !BondmateB.IsInjured() &&
						   !IsAlreadyPlaced(BondmateB.GetReference()))
						{
							bFoundMatch = true;
							UsedSoldierIDs.AddItem(BondmateA.ObjectID);
							UsedSoldierIDs.AddItem(BondmateB.ObjectID);
							BondmatesToPlace.AddItem(BondmateA);
							BondmatesToPlace.AddItem(BondmateB);
						}

						PotentialBondmates.Remove(0, 1);
					}

				}
			}
		}
	}

	// Next Grab All Bond soldiers
	for(idx = 0; idx < RandomizedSoldiers.Length; idx++)
	{
		if(UsedSoldierIDs.Find(RandomizedSoldiers[idx].ObjectID) == INDEX_NONE)
		{
			BondmateA = RandomizedSoldiers[idx];

			if(BondmateA.CanAppearInBase() && !IsAlreadyPlaced(BondmateA.GetReference()))
			{
				if(BondmateA.HasSoldierBond(BondmateRef))
				{
					if(UsedSoldierIDs.Find(BondmateRef.ObjectID) == INDEX_NONE)
					{
						BondmateB = XComGameState_Unit(History.GetGameStateForObjectID(BondmateRef.ObjectID));

						if(BondmateB.CanAppearInBase() && !IsAlreadyPlaced(BondmateB.GetReference()))
						{
							UsedSoldierIDs.AddItem(BondmateA.ObjectID);
							UsedSoldierIDs.AddItem(BondmateB.ObjectID);
							BondmatesToPlace.AddItem(BondmateA);
							BondmatesToPlace.AddItem(BondmateB);
						}
					}
				}
			}
		}
	}

	// Next grab all negative trait soldiers
	for(idx = 0; idx < RandomizedSoldiers.Length; idx++)
	{
		if(UsedSoldierIDs.Find(RandomizedSoldiers[idx].ObjectID) == INDEX_NONE)
		{
			TraitUnit = RandomizedSoldiers[idx];

			if(TraitUnit.CanAppearInBase() && TraitUnit.HasNegativeTraits() && !IsAlreadyPlaced(TraitUnit.GetReference()))
			{
				UsedSoldierIDs.AddItem(TraitUnit.ObjectID);
				TraitUnitsToPlace.AddItem(TraitUnit);
			}
		}
	}

	// Place as many bond soldiers as we can
	while(BondmatesToPlace.Length > 1 && BondMatineeGroups.Length > 0)
	{
		GroupIdx = `SYNC_RAND(BondMatineeGroups.Length);
		RoomIdx = GetRoomIndexFromAnimMap(BondMatineeGroups[GroupIdx].RoomMapName);

		FacilityState = GetFacilityFromRoomIndex(RoomIdx);

		if (FacilityState == none)
		{
			BondMatineeGroups.Remove(GroupIdx, 1);
			continue;
		}

		if(BondMatineeGroups[GroupIdx].Slots.Length == 2)
		{
			FacilityTemplate = FacilityState.GetMyTemplate();
			if (FacilityTemplate.PlaceCrewMember(self, FacilityState.GetReference(), BondmatesToPlace[0].GetReference(), false))
			{
				// Ignore crew limits while we attempt to place the second half of the bonded pair
				bIgnoreCrewLimits = true;
				FacilityTemplate.PlaceCrewMember(self, FacilityState.GetReference(), BondmatesToPlace[1].GetReference(), false);
				bIgnoreCrewLimits = false;
			}

			FillBondMatinee(RoomIdx, BondMatineeGroups[GroupIdx], BondmatesToPlace[0], BondmatesToPlace[1]);

			BondmatesToPlace.Remove(0, 1);
			BondmatesToPlace.Remove(0, 1);
		}

		BondMatineeGroups.Remove(GroupIdx, 1);
	}

	// Place as many trait soldiers as we can
	TraitUnitsToPlace.Sort(SortTraitUnits);
	while(TraitUnitsToPlace.Length > 0 && TraitMatineeGroups.Length > 0)
	{
		GroupIdx = `SYNC_RAND(TraitMatineeGroups.Length);
		RoomIdx = GetRoomIndexFromAnimMap(TraitMatineeGroups[GroupIdx].RoomMapName);

		FacilityState = GetFacilityFromRoomIndex(RoomIdx);

		if(FacilityState == none)
		{
			TraitMatineeGroups.Remove(GroupIdx, 1);
			continue;
		}

		FacilityTemplate = FacilityState.GetMyTemplate();
		FacilityTemplate.PlaceCrewMember(self, FacilityState.GetReference(), TraitUnitsToPlace[0].GetReference(), false);
		FillNegativeTraitMatinee(RoomIdx, TraitMatineeGroups[GroupIdx], TraitUnitsToPlace[0]);
		TraitUnitsToPlace.Remove(0, 1);
		TraitMatineeGroups.Remove(GroupIdx, 1);
	}
}

private function int SortTraitUnits(XComGameState_Unit UnitStateA, XComGameState_Unit UnitStateB)
{
	return (UnitStateA.AlertTraits.Length - UnitStateB.AlertTraits.Length);
}

private function FillNegativeTraitMatinee(int RoomIndex, RoomMatineeGroup TraitMatineeGroup, XComGameState_Unit TraitUnit)
{
	local RoomCinematics RoomCinema;
	local RoomMatinee Matinee;
	local bool bFoundMatch;
	local int MatIdx, SlotIdx, TraitUnitIdx;
	local RoomCrewInstance TraitUnitCrew;
	local string SlotType, MatineeStartEvent;
	local XComPresentationLayerBase XPres;
	local RoomMatineeTracking RoomMatTrack;

	RoomCinema = m_arrRoomCinemas[RoomIndex];
	bFoundMatch = false;

	// Find the matinee in our room cinematics list
	for(MatIdx = 0; MatIdx < RoomCinema.Matinees.Length; MatIdx++)
	{
		Matinee = RoomCinema.Matinees[MatIdx];

		if(TraitMatineeGroup.EventSuffix == Matinee.EventSuffix)
		{
			for(SlotIdx = 0; SlotIdx < Matinee.Slots.Length; SlotIdx++)
			{
				if(TraitMatineeGroup.Slots.Find(Matinee.Slots[SlotIdx]) != INDEX_NONE)
				{
					bFoundMatch = true;
					break;
				}
			}
		}

		if(bFoundMatch)
		{
			break;
		}
	}

	// We found a match, now fill the matinee with the trait unit
	if(bFoundMatch)
	{
		TraitUnitIdx = m_arrRoomCrew[RoomIndex].Crew.Find('CrewRef', TraitUnit.GetReference());

		if(TraitUnitIdx != INDEX_NONE)
		{
			TraitUnitCrew = m_arrRoomCrew[RoomIndex].Crew[TraitUnitIdx];
			SlotType = Matinee.Slots[SlotIdx];

			if(SlotTypeCriteriaMet(SlotType, TraitUnitCrew.DesiredSlotType))
			{
				if(Matinee.EventSuffix != "")
				{
					MatineeStartEvent = GetRoomMapName(RoomIndex) $ "." $ Matinee.EventSuffix;
					TraitUnitCrew.FullyQualifiedSlotName = MatineeStartEvent $ "_" $ SlotType;

					AddIfUnique(DelayedEventsToStart, MatineeStartEvent);
				}
				else
				{
					MatineeStartEvent = GetRoomMapName(RoomIndex) $ ".";
					TraitUnitCrew.FullyQualifiedSlotName = MatineeStartEvent $ SlotType;

					AddIfUnique(DelayedEventsToStart, TraitUnitCrew.FullyQualifiedSlotName);
				}

				// Set Pawns
				XPres = `HQPRES;
				XPres.GetUIPawnMgr().SetPawnVariable(TraitUnitCrew.CrewPawn, name(TraitUnitCrew.FullyQualifiedSlotName));

				// Add back into the room list
				m_arrRoomCrew[RoomIndex].Crew[TraitUnitIdx] = TraitUnitCrew;

				// Track used matinee
				RoomMatTrack.RoomIndex = RoomIndex;
				RoomMatTrack.MatineeIndex = MatIdx;
				UsedRoomMatinees.AddItem(RoomMatTrack);
			}
		}
	}
}

private function FillBondMatinee(int RoomIndex, RoomMatineeGroup BondMatineeGroup, XComGameState_Unit BondmateA, XComGameState_Unit BondmateB)
{
	local RoomCinematics RoomCinema;
	local RoomMatinee Matinee;
	local bool bFoundMatch;
	local int MatIdx, SlotIdx, BondAIdx, BondBIdx;
	local RoomCrewInstance BondACrew, BondBCrew;
	local string SlotTypeA, SlotTypeB, MatineeStartEvent;
	local XComPresentationLayerBase XPres;
	local RoomMatineeTracking RoomMatTrack;

	RoomCinema = m_arrRoomCinemas[RoomIndex];
	bFoundMatch = false;

	// Find the matinee in our room cinematics list
	for(MatIdx = 0; MatIdx < RoomCinema.Matinees.Length; MatIdx++)
	{
		Matinee = RoomCinema.Matinees[MatIdx];

		if(Matinee.Slots.Length == 2)
		{
			if(BondMatineeGroup.EventSuffix == Matinee.EventSuffix)
			{
				for(SlotIdx = 0; SlotIdx < Matinee.Slots.Length; SlotIdx++)
				{
					if(BondMatineeGroup.Slots.Find(Matinee.Slots[SlotIdx]) == INDEX_NONE)
					{
						bFoundMatch = false;
						break;
					}
				}

				bFoundMatch = true;
			}

			if(bFoundMatch)
			{
				break;
			}
		}
	}

	// We found a match, now fill the matinee with the bondmates
	if(bFoundMatch)
	{
		BondAIdx = m_arrRoomCrew[RoomIndex].Crew.Find('CrewRef', BondmateA.GetReference());
		BondBIdx = m_arrRoomCrew[RoomIndex].Crew.Find('CrewRef', BondmateB.GetReference());

		if(BondAIdx != INDEX_NONE && BondBIdx != INDEX_NONE)
		{
			BondACrew = m_arrRoomCrew[RoomIndex].Crew[BondAIdx];
			BondBCrew = m_arrRoomCrew[RoomIndex].Crew[BondBIdx];
			SlotTypeA = Matinee.Slots[0];
			SlotTypeB = Matinee.Slots[1];

			if(SlotTypeCriteriaMet(SlotTypeA, BondACrew.DesiredSlotType) && SlotTypeCriteriaMet(SlotTypeB, BondBCrew.DesiredSlotType))
			{
				if(Matinee.EventSuffix != "")
				{
					MatineeStartEvent = GetRoomMapName(RoomIndex) $ "." $ Matinee.EventSuffix;
					BondACrew.FullyQualifiedSlotName = MatineeStartEvent $ "_" $ SlotTypeA;
					BondBCrew.FullyQualifiedSlotName = MatineeStartEvent $ "_" $ SlotTypeB;

					AddIfUnique(DelayedEventsToStart, MatineeStartEvent);
				}
				else
				{
					MatineeStartEvent = GetRoomMapName(RoomIndex) $ ".";
					BondACrew.FullyQualifiedSlotName = MatineeStartEvent $ SlotTypeA;
					BondBCrew.FullyQualifiedSlotName = MatineeStartEvent $ SlotTypeB;

					AddIfUnique(DelayedEventsToStart, BondACrew.FullyQualifiedSlotName);
					AddIfUnique(DelayedEventsToStart, BondBCrew.FullyQualifiedSlotName);
				}

				// Set Pawns
				XPres = `HQPRES;
				XPres.GetUIPawnMgr().SetPawnVariable(BondACrew.CrewPawn, name(BondACrew.FullyQualifiedSlotName));
				XPres.GetUIPawnMgr().SetPawnVariable(BondBCrew.CrewPawn, name(BondBCrew.FullyQualifiedSlotName));

				// Add back into the room list
				m_arrRoomCrew[RoomIndex].Crew[BondAIdx] = BondACrew;
				m_arrRoomCrew[RoomIndex].Crew[BondBIdx] = BondBCrew;

				// Track used matinee
				RoomMatTrack.RoomIndex = RoomIndex;
				RoomMatTrack.MatineeIndex = MatIdx;
				UsedRoomMatinees.AddItem(RoomMatTrack);
			}
		}
	}
}

function XComUnitPawn GetPawnForUnit(StateObjectReference UnitRef)
{
	local int RoomIdx, CrewIdx;
	for (RoomIdx = 0; RoomIdx < m_arrRoomCrew.Length; ++RoomIdx)
	{
		CrewIdx = m_arrRoomCrew[RoomIdx].Crew.Find('CrewRef', UnitRef);
		if (CrewIdx != -1)
		{
			return m_arrRoomCrew[RoomIdx].Crew[CrewIdx].CrewPawn;
		}
	}

	return none; 
}

private function XComGameState_FacilityXCom GetFacilityFromRoomIndex(int RoomIdx)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersRoom RoomState;

	if (RoomIdx < 0)
		return none;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetGameStateForObjectID(XComHQ.ObjectID));
	RoomState = XComGameState_HeadquartersRoom(History.GetGameStateForObjectID(XComHQ.Rooms[RoomIdx].ObjectID));
	return RoomState.GetFacility();
}

function XComGameState_HeadquartersRoom GetRoomFromUnit(StateObjectReference UnitRef)
{
	return GetRoomFromRoomIndex(GetRoomIndexFromUnit(UnitRef));
}

private function int GetRoomIndexFromUnit(StateObjectReference UnitRef)
{
	local int RoomIdx, CrewIdx;
	for(RoomIdx = 0; RoomIdx < m_arrRoomCrew.Length; ++RoomIdx)
	{
		CrewIdx = m_arrRoomCrew[RoomIdx].Crew.Find('CrewRef', UnitRef);
		if(CrewIdx != -1)
		{
			return RoomIdx;
		}
	}

	return -1;
}

private function XComGameState_HeadquartersRoom GetRoomFromRoomIndex(int RoomIdx)
{
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetGameStateForObjectID(XComHQ.ObjectID));

	if(RoomIdx < 0 || RoomIdx >= XComHQ.Rooms.Length)
	{
		return none;
	}

	return  XComGameState_HeadquartersRoom(History.GetGameStateForObjectID(XComHQ.Rooms[RoomIdx].ObjectID));
}

private function int GetRoomIndexFromAnimMap(string AnimMapName)
{
	local array<LevelStreaming> AllAnimLevels;
	local LevelStreaming AnimLevel;
	local int idx;
	
	AllAnimLevels = `GAME.GetGeoscape().m_kBase.m_arrLvlStreaming_Anim;

	for(idx = 0; idx < AllAnimLevels.Length; idx++)
	{
		AnimLevel = AllAnimLevels[idx];

		if(AnimLevel != None && string(AnimLevel.PackageName) == AnimMapName)
		{
			return idx;
		}
	}
	
	return -1;
}

private function ClearAllRoomsCrew()
{
	local int i, j;

	for(i = 0; i < ProcessingRoomUpdates.Length; i++)
	{
		for(j = 0; j < m_arrRoomCrew[ProcessingRoomUpdates[i].RoomIndex].Crew.Length; j++)
		{
			m_arrRoomCrew[ProcessingRoomUpdates[i].RoomIndex].Crew[j].FullyQualifiedSlotName = "";
		}
	}	
}

//Returns whether all crew were successfully placed, bClearSlotNames is no longer used
private function bool SelectBestSlotsForCrew(int RoomIdx, XComGameState_FacilityXCom FacilityStateObject, out array<string> EventsToStart, bool bClearSlotNames)
{
	local RoomMatinee Matinee;
	local array<RoomCrewInstance> CrewToPlace;//Crew that we want to attempt to place, elements are moved from this array into PlacedCrew as they are successfully placed
	local array<RoomCrewInstance> PlacedCrew; //Crew that were successfully placed
	local int MatineeIdx, CrewIdx, CrewRemainingIndex;
	local int NumProcessed;
	
	//Sync up the already placed crew and crew to place arrays, since are doing another pass on this room
	for(CrewIdx = 0; CrewIdx < m_arrRoomCrew[RoomIdx].Crew.Length; ++CrewIdx)
	{
		if(m_arrRoomCrew[RoomIdx].Crew[CrewIdx].FullyQualifiedSlotName != "")
		{
			PlacedCrew.AddItem(m_arrRoomCrew[RoomIdx].Crew[CrewIdx]);
		}
		else
		{
			CrewToPlace.AddItem(m_arrRoomCrew[RoomIdx].Crew[CrewIdx]);
		}
	}
	
	//May be true if we are processing additional iterations of this method beyond the first
	if(CrewToPlace.Length == 0)
	{
		return true;
	}

	//Create the list of room cinematics if we haven't done so already
	if(m_arrRoomCinemas.Length == 0)
	{
		UpdateRoomCinematics();
	}

	//We want to pick randomly, so start looking for a match at a random offset into the matinee list
	NumProcessed = 0;
	MatineeIdx = `SYNC_RAND(m_arrRoomCinemas[RoomIdx].Matinees.Length);
	while(NumProcessed < m_arrRoomCinemas[RoomIdx].Matinees.Length && CrewToPlace.Length > 0)
	{
		if(!MatineeAlreadyFilled(RoomIdx, MatineeIdx))
		{
			Matinee = m_arrRoomCinemas[RoomIdx].Matinees[MatineeIdx];

			//Skip matinees that need upgrades we don't have
			if(FacilityStateObject == none || !MatineeRequiresUpgrade(Matinee, FacilityStateObject.GetMyTemplate()) || FacilityStateObject.HasBeenUpgraded())
			{
				// Check if already being used by bond soldiers @mnauta

				if(CanSatifyMatineeSlots(CrewToPlace, Matinee))
				{
					FillSlotsWithCrew(RoomIdx, CrewToPlace, PlacedCrew, Matinee, EventsToStart);
					m_arrRoomCinemas[RoomIdx].Matinees[MatineeIdx] = Matinee;
				}
			}
		}

		MatineeIdx = (MatineeIdx + 1) % m_arrRoomCinemas[RoomIdx].Matinees.Length;
		++NumProcessed;
	}

	//Update the room crew to reflect the actually placed crew.
	m_arrRoomCrew[RoomIdx].Crew = PlacedCrew;

	if (CrewToPlace.Length > 0)
	{
		//Remove the unplaced crew from the level - the need to be recreated and reattached somewhere new.
		for(CrewRemainingIndex = 0; CrewRemainingIndex < CrewToPlace.Length; ++CrewRemainingIndex)
		{
			`HQPRES.GetUIPawnMgr().ReleaseCinematicPawn(self, CrewToPlace[CrewRemainingIndex].CrewRef.ObjectID);					
			break;
		}

		`log("Failed to place all crew in room "$GetRoomMapName(RoomIdx)$". Left over crew count = "$CrewToPlace.Length);
		return false;
	}

	return true;
}

// For use with special priority pass matinees (Soldier bond, negative trait)
private function bool MatineeAlreadyFilled(int RoomIndex, int MatineeIndex)
{
	local int idx;

	for(idx = 0; idx < UsedRoomMatinees.Length; idx++)
	{
		if(UsedRoomMatinees[idx].RoomIndex == RoomIndex && UsedRoomMatinees[idx].MatineeIndex == MatineeIndex)
		{
			return true;
		}
	}

	return false;
}

function bool AddCrew(int RoomIdx, X2FacilityTemplate FacilityTemplate, StateObjectReference CrewRef, string MatineeSlotName, Vector RoomOffset, bool bIsStaffSlot)
{
	// only spawn pawn and run matinee if there is a preferred matinee slot, empty string means its managed wholy by matinee or something, but...
	// maybe should bind to maintee without variable binding just for event identification and trigerring
	if(MatineeSlotName != "")
	{
		// add CrewRef to RoomIdx and spawn pawn
		return SpawnAndAddCrewToRoom(RoomIdx, FacilityTemplate, MatineeSlotName, CrewRef, bIsStaffSlot);
	}

	return false;
}

private function EventListenerReturn OnStaffUpdated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_StaffSlot StaffSlotUpdated;
	local XComGameState_StaffSlot PreviousStaffSlotUpdated;
	local XComGameState_BaseObject Previous;
	local XComGameState_BaseObject Current;
	local XComGameState_HeadquartersRoom HQRoom;
	local XComGameStateHistory History;
	local int VacatedIdx, CrewIdx;
	local bool bPreviousRoom;

	StaffSlotUpdated = XComGameState_StaffSlot(EventData);

	History = `XCOMHISTORY;
	History.GetCurrentAndPreviousGameStatesForObjectID(StaffSlotUpdated.ObjectID, Previous, Current);
	PreviousStaffSlotUpdated = XComGameState_StaffSlot(Previous);
	
	for(VacatedIdx = 0; VacatedIdx < m_arrRoomCrew.Length; ++VacatedIdx)
	{
		CrewIdx = m_arrRoomCrew[VacatedIdx].Crew.Find('CrewRef', PreviousStaffSlotUpdated.AssignedStaff.UnitRef);
		if(CrewIdx != -1)
		{			
			bPreviousRoom = true;
			break;
		}
	}

	UpdateHeadStaffLocations();

	//Indicate we want to update the unit's previous home
	if(bPreviousRoom)
	{	
		HQRoom = XComGameState_HeadquartersRoom(History.GetGameStateForObjectID(XComHQ.Rooms[VacatedIdx].ObjectID));
		RequestStaffUpdate(HQRoom);
	}
	
	//Update for the new location
	if(StaffSlotUpdated.GetRoom() != None)
	{
		RequestStaffUpdate(StaffSlotUpdated.GetRoom());
	}
	else if(StaffSlotUpdated.GetFacility() != None)
	{
		RequestStaffUpdate(StaffSlotUpdated.GetFacility().GetRoom());
	}

	return ELR_NoInterrupt;
}

function RequestStaffUpdate(XComGameState_HeadquartersRoom HQRoom)
{
	local int Index;		
	local XComGameStateHistory History;
	local bool bAddUpdate;
	local StaffUpdateRequest NewStaffingRequest;

	History = `XCOMHISTORY;

	if(HQRoom.GetFacility() != none)
	{
		NewStaffingRequest.FacilityStateObject = HQRoom.GetFacility();
		NewStaffingRequest.RoomIndex = NewStaffingRequest.FacilityStateObject.GetRoom().MapIndex;
		for(Index = 0; Index < NewStaffingRequest.FacilityStateObject.StaffSlots.Length; ++Index)
		{
			if(NewStaffingRequest.FacilityStateObject.StaffSlots[Index].ObjectID > 0)
			{
				NewStaffingRequest.StaffSlotArray.AddItem(XComGameState_StaffSlot(History.GetGameStateForObjectID(NewStaffingRequest.FacilityStateObject.StaffSlots[Index].ObjectID)));
			}
		}		
	}
	else
	{			
		NewStaffingRequest.RoomIndex = HQRoom.MapIndex;
		for(Index = 0; Index < HQRoom.BuildSlots.Length; ++Index)
		{
			if(HQRoom.BuildSlots[Index].ObjectID > 0)
			{
				NewStaffingRequest.StaffSlotArray.AddItem(XComGameState_StaffSlot(History.GetGameStateForObjectID(HQRoom.BuildSlots[Index].ObjectID)));
			}
		}
	}

	bAddUpdate = true;
	for(Index = 0; Index < PendingRoomUpdates.Length; ++Index)
	{
		if(PendingRoomUpdates[Index].RoomIndex == NewStaffingRequest.RoomIndex)
		{
			bAddUpdate = false;
			break;
		}
	}

	if(bAddUpdate)
	{
		PendingRoomUpdates.AddItem(NewStaffingRequest);
	}
}

private function AddGhost(int RoomIdx)
{
	local name StartEvent;
	StartEvent = name("CIN_Start"$GetFullyQualifiedVariableName(RoomIdx, GhostMatineeSlotName));
	`XCOMGRI.DoRemoteEvent(StartEvent);
}

private function RemoveGhost(int RoomIdx)
{
	local name StopEvent;
	StopEvent = name("CIN_Stop"$GetFullyQualifiedVariableName(RoomIdx, GhostMatineeSlotName));
	`XCOMGRI.DoRemoteEvent(StopEvent);
}

function VacateAllCrew(int RoomIdx)
{
	local int SlotIdx;
	local name StopEvent;
	local RoomCrewInstance SlotBindingLocalCopy;
	local XComPresentationLayerBase XPres;
	XPres = `HQPRES;

	for(SlotIdx = 0; SlotIdx < m_arrRoomCrew[RoomIdx].Crew.Length; ++SlotIdx)
	{
		SlotBindingLocalCopy = m_arrRoomCrew[RoomIdx].Crew[SlotIdx];
		if(RoomHasAnimMap(RoomIdx))
		{
			StopEvent = GenerateEventName("CIN_Stop", RoomIdx, SlotBindingLocalCopy);
			`XCOMGRI.DoRemoteEvent(StopEvent);
		}

		if(SlotBindingLocalCopy.CrewRef.ObjectID != 0)
		{
			if(SlotBindingLocalCopy.FullyQualifiedSlotName != "")
			{
				XPres.GetUIPawnMgr().ClearPawnVariable(name(SlotBindingLocalCopy.FullyQualifiedSlotName));
			}

			m_arrRoomCrew[RoomIdx].Crew[SlotIdx].CrewPawn = none;
			`HQPRES.GetUIPawnMgr().ReleaseCinematicPawn(self, SlotBindingLocalCopy.CrewRef.ObjectID);
		}	
	}

	m_arrRoomCrew[RoomIdx].Crew.Length = 0;

	RemoveGhost(RoomIdx);
}

private function RemoveRoomCrew(int RoomIdx)
{
	local RoomCrewInstance SlotBinding;
	local XComPresentationLayerBase XPres;	
	local int SlotIdx;

	XPres = `HQPRES;

	for(SlotIdx = 0; SlotIdx < m_arrRoomCrew[RoomIdx].Crew.Length; ++SlotIdx)
	{		
		if(SlotBinding.CrewRef.ObjectID != 0)
		{
			if(SlotBinding.FullyQualifiedSlotName != "")
			{
				XPres.GetUIPawnMgr().ClearPawnVariable(name(SlotBinding.FullyQualifiedSlotName));
			}

			m_arrRoomCrew[RoomIdx].Crew[SlotIdx].CrewPawn = none;
			XPres.GetUIPawnMgr().ReleaseCinematicPawn(self, SlotBinding.CrewRef.ObjectID);
		}
	}
	m_arrRoomCrew[RoomIdx].Crew.Length = 0;
}

function RemoveBaseCrew()
{
	local int RoomIdx;

	`XCOMGRI.DoRemoteEvent('CIN_StopCrew');

	for (RoomIdx = 0; RoomIdx < XComHQ.Rooms.Length; RoomIdx++)
	{
		RemoveRoomCrew(RoomIdx);
	}
}

function bool IsPlacingStaff()
{
	return bIsPlacingCrew;
}

auto State Idle
{
	simulated event BeginState(name PreviousStateName)
	{		
	}

	simulated event Tick(float fDeltaT)
	{
		// Failsafe if we are somehow in the idle state and there are blocks that should have been visualized.
		if(PendingRoomUpdates.Length > 0 && ProcessingRoomUpdates.Length == 0)
		{
			ProcessingRoomUpdates = PendingRoomUpdates;
			PendingRoomUpdates.Length = 0;
			GotoState('PlacingStaff');
		}
	}
Begin:
}

//------------------------------------------------------------------------------------------------
simulated state PlacingStaff
{	
	simulated event BeginState(name PreviousStateName)
	{
		bIsPlacingCrew = true;
	}	

	function bool StepPopulateAllFillerSlots(int StepSize)
	{
		local int MaxIterate;
		local int StopIterate;
		local int RoomIndex;
		local int ProcessedRooms;
		local X2FacilityTemplate FacilityTemplate;
		local XComGameStateHistory History;
		local bool bPlacedCrew;
		local bool bPlacedClerk;
		local array<StaffUpdateRequest> FacilitiesToCheck;
		local int NextRoomIndexStart;

		History = `XCOMHISTORY;
		XComHQ = XComGameState_HeadquartersXCom(History.GetGameStateForObjectID(XComHQ.ObjectID));
		
		//Make a list of facilities that can host units
		for(TempIterator = 0; TempIterator < ProcessingRoomUpdates.Length; ++TempIterator)
		{
			if(ProcessingRoomUpdates[TempIterator].FacilityStateObject != none)
			{
				FacilitiesToCheck.AddItem(ProcessingRoomUpdates[TempIterator]);
			}
		}

		if (FacilitiesToCheck.Length == 0)
			return true;

		NextRoomIndexStart = Rand(FacilitiesToCheck.Length);
		MaxIterate = Max(XComHQ.Clerks.Length, XComHQ.Crew.Length);		
		StopIterate = FillerSlotStart + StepSize;
		for(TempIterator = FillerSlotStart; TempIterator < StopIterate && TempIterator < MaxIterate; ++TempIterator)
		{	
			StaffedUnit = none;
			
			//See if we need to place this crew
			if(TempIterator < XComHQ.Crew.Length)
			{
				if(!IsAlreadyPlaced(XComHQ.Crew[TempIterator]))
				{
					StaffedUnit = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Crew[TempIterator].ObjectID));
					`log("============================="@StaffedUnit.GetFullName()@"=============================", bLogPlacement);
					`log("Populating filler slot with Crew:"@StaffedUnit.GetMyTemplate().DataName, bLogPlacement);
					bPlacedCrew = false;
				}
				else
				{
					bPlacedCrew = true;
				}
			}
			else
			{
				bPlacedCrew = true;
			}

			//See if we need to place this clerk
			if(TempIterator < XComHQ.Clerks.Length)
			{
				if(!IsAlreadyPlaced(XComHQ.Clerks[TempIterator]))
				{
					if(StaffedUnit == none)
					{
						`log("============================= Clerk =============================", bLogPlacement);
					}
					`log("Populating filler slot with Clerk", bLogPlacement);
					bPlacedClerk = false;
				}
				else
				{
					bPlacedClerk = true;
				}
			}
			else
			{
				bPlacedClerk = true;
			}
						
			if(bPlacedClerk && bPlacedCrew)//No processing needed
			{
				continue;
			}
						
			//Iterate the list of facilities that the crew member could populate, attempting to put them into the room until the placement is successful. We do double duty here
			//iterating the crew as well as the clerks
			RoomIndex = NextRoomIndexStart;
			ProcessedRooms = 0;
			while(ProcessedRooms < FacilitiesToCheck.Length)
			{								
				`log("Checking room:"@FacilitiesToCheck[RoomIndex].FacilityStateObject.GetMyTemplateName(), bLogPlacement);

				bAnyAssignedStaff = false;
				bAnyStaffSlots = false;
				for(StaffSlotIndex = 0; StaffSlotIndex < FacilitiesToCheck[RoomIndex].StaffSlotArray.Length; ++StaffSlotIndex)
				{
					bAnyStaffSlots = true;
					bOnlySoldierStaffSlots = true;

					StaffSlotState = XComGameState_StaffSlot(History.GetGameStateForObjectID(FacilitiesToCheck[RoomIndex].StaffSlotArray[StaffSlotIndex].ObjectID));
					if (StaffSlotState != none && !StaffSlotState.IsSoldierSlot())
					{
						bOnlySoldierStaffSlots = false;
					}

					StaffedUnit = XComGameState_Unit(History.GetGameStateForObjectID(FacilitiesToCheck[RoomIndex].StaffSlotArray[StaffSlotIndex].AssignedStaff.UnitRef.ObjectID));
					if(StaffedUnit != none)
					{
						bAnyAssignedStaff = true;
						break;
					}
				}

				//Only populate filler staff if there are no staff slots OR the room has been staffed
				if (bAnyAssignedStaff || !bAnyStaffSlots || bOnlySoldierStaffSlots)
				{
					FacilityTemplate = FacilitiesToCheck[RoomIndex].FacilityStateObject.GetMyTemplate();

					if(TempIterator < XComHQ.Crew.Length && !bPlacedCrew)
					{
						if(XComHQ.Crew[TempIterator].ObjectID != XComHQ.GetHeadEngineerRef() && XComHQ.Crew[TempIterator].ObjectID != XComHQ.GetHeadScientistRef())
						{
							bPlacedCrew = FacilityTemplate.PlaceCrewMember(self, FacilitiesToCheck[RoomIndex].FacilityStateObject.GetReference(), XComHQ.Crew[TempIterator], false);
						}
						else
						{
							bPlacedCrew = true;// Head engineer and scientist are never filler
						}
					}

					if(TempIterator < XComHQ.Clerks.Length && !bPlacedClerk)
					{
						bPlacedClerk = FacilityTemplate.PlaceCrewMember(self, FacilitiesToCheck[RoomIndex].FacilityStateObject.GetReference(), XComHQ.Clerks[TempIterator], false);
					}
				}				

				if(bPlacedClerk && bPlacedCrew)
				{
					break;
				}

				RoomIndex = (RoomIndex + 1) % FacilitiesToCheck.Length;
				++ProcessedRooms;
			}

			//Make sure we cycle through all rooms so that we get an even distribution of crew
			NextRoomIndexStart = (NextRoomIndexStart + 1) % FacilitiesToCheck.Length;			

			`log("==============================================================", bLogPlacement);
		}

		FillerSlotStart += StepSize;

		return FillerSlotStart < MaxIterate;
	}

Begin:		
	CurrentVisibleCrew = 0;
	for(TempIterator = 0; TempIterator < ProcessingRoomUpdates.Length; ++TempIterator)
	{
		//Clear the room out. Stop Matinees, clear pawns, etc. so we can start with a fresh state
		VacateAllCrew(ProcessingRoomUpdates[TempIterator].RoomIndex);
		
		// Ensure the facilities have all of the necessary matinee slots needed to populate staff
		UpdateRoomCinematics();

		//Restock it based on the current staff slots
		bAnyAssignedStaff = false;
		bAnyStaffSlots = false;

		//This is only relevant if the room has a kismet/matinee map to control things
		if(`GAME.GetGeoscape().m_kBase.m_arrLvlStreaming_Anim[ProcessingRoomUpdates[TempIterator].RoomIndex] != none)
		{
			//Allow the facility, if there is one, to do special processing that will pre-empt all slot processing. Used for certain facilities like the advanced warfare center.
			if(ProcessingRoomUpdates[TempIterator].FacilityStateObject != none)
			{
				TempFacilityTemplate = ProcessingRoomUpdates[TempIterator].FacilityStateObject.GetMyTemplate();
				TempFacilityTemplate.PopulateImportantFacilityCrew(self, ProcessingRoomUpdates[TempIterator].FacilityStateObject.GetReference());
			}

			TempRoomOffset = `GAME.GetGeoscape().m_kBase.m_arrLvlStreaming_Anim[ProcessingRoomUpdates[TempIterator].RoomIndex].Offset;
			for(StaffSlotIndex = 0; StaffSlotIndex < ProcessingRoomUpdates[TempIterator].StaffSlotArray.Length; ++StaffSlotIndex)
			{	
				StaffSlotState = ProcessingRoomUpdates[TempIterator].StaffSlotArray[StaffSlotIndex];
				StaffedUnit = StaffSlotState.GetAssignedStaff();
				if(StaffedUnit != none && (StaffedUnit.CanAppearInBase() || (StaffedUnit.GetMyTemplate().AppearInStaffSlots.Find(StaffSlotState.GetMyTemplateName()) != INDEX_NONE)))
				{					
					if(StaffedUnit.StaffingSlot.ObjectID == StaffSlotState.ObjectID)
					{
						if(!IsAlreadyPlaced(StaffedUnit.GetReference(), ProcessingRoomUpdates[TempIterator].RoomIndex))
						{
							//The unit is actually at the location
							AddCrew(ProcessingRoomUpdates[TempIterator].RoomIndex, TempFacilityTemplate, StaffedUnit.GetReference(), StaffSlotState.GetMyTemplate().MatineeSlotName, TempRoomOffset, true);
						}
					}
					else
					{
						//The unit is providing a gremlin to a nearby room. Which the strategy code refers to as "ghosts"
						AddGhost(ProcessingRoomUpdates[TempIterator].RoomIndex);						
					}
				}
			}
		}		
	}

	// Clear out room matinee slot names (so we can fill them cleanly)
	ClearAllRoomsCrew();

	// If full base pass, prioritize filling in unstaffed bondmates before doing filler staff @mnauta
	if(bFullBasePopulate)
	{
		bFullBasePopulate = false;
		AssignSpecialCaseCrew();
	}

	//Perform a loop alternating between iterating all members of the crew and placing them in room matinees. 	
	NumPlacementAttempts = 0;
	do
	{
		`log("============================= Filler Slot Calculation Iteration"@(NumPlacementAttempts + 1)@"=============================", bLogPlacement);
		`log("===========================================================================================================================", bLogPlacement);
		`log("===========================================================================================================================", bLogPlacement);

		//Populate the filler slots for all ProcessingRoomUpdates rooms. This is done incrementally because it spawns pawns, which is expensive
		FillerSlotStart = 0;
		while(StepPopulateAllFillerSlots(2))
		{
			Sleep(0.1f);
		}

		//Select from the available matinees based on the assigned crew
		bAllPlacementsSuccessful = true;
		for(TempIterator = 0; TempIterator < ProcessingRoomUpdates.Length; ++TempIterator)
		{			
			// optimize choice of Matinee for RoomIdx
			bAllPlacementsSuccessful = SelectBestSlotsForCrew(ProcessingRoomUpdates[TempIterator].RoomIndex, 
															  ProcessingRoomUpdates[TempIterator].FacilityStateObject,
															  DelayedEventsToStart, NumPlacementAttempts == 0) && bAllPlacementsSuccessful;
		}

		`log("===========================================================================================================================", bLogPlacement);
		`log("===========================================================================================================================", bLogPlacement);
		++NumPlacementAttempts;
	} until(bAllPlacementsSuccessful || NumPlacementAttempts >= 10);

	bIsPlacingCrew = false;

	Sleep(0.1f);

	//Issue the Matinee start remote events
	for(TempIterator = 0; TempIterator < DelayedEventsToStart.Length; ++TempIterator)
	{		
		TempStartEvent = "CIN_Start"$DelayedEventsToStart[TempIterator];
		`log("Calling Remote Event:"@TempStartEvent, bLogPlacement);
		`XCOMGRI.DoRemoteEvent(name(TempStartEvent));
	}

	Sleep(1.0f);

	//Now that the matinees are started, set the pawns so that they don't waste game thread time when they are not on screen
	foreach WorldInfo.AllActors(class'XComUnitPawn', UnitPawn)
	{
		if(UnitPawn.Owner == self)
		{			
			if(UnitPawn.Location == ZeroVec)
			{
				UnitPawn.SetHidden(true);
			}
			UnitPawn.SetUpdateSkelWhenNotRendered(false);
		}
	}

	DelayedEventsToStart.Length = 0;
	ProcessingRoomUpdates.Length = 0;
	GotoState('Idle');
}

defaultproperties
{
	m_pendingPolaroids = 0;
	GhostMatineeSlotName = "GremlinSlot";
	SciOrEngSlotName = "CrewSlot";
	AnySlotName = "AnySlot";	
	bLogPlacement = false
	bIsPlacingCrew=false
}
