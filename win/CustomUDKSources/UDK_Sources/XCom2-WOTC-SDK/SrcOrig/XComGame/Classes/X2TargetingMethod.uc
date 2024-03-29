//---------------------------------------------------------------------------------------
//  FILE:    X2TargetingMethod.uc
//  AUTHOR:  David Burchanowski  --  2/10/2014
//  PURPOSE: Base class for targeting methods. Targeting methods control how the user interacts with
//           with the game world when to determine the target of an ability.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2TargetingMethod extends Object
	abstract
	native(Core)
	config(GameCore);

var privatewrite AvailableAction Action;
var protectedwrite XComGameState_Ability Ability;
var privatewrite name ProjectileTimingStyle;
var privatewrite name OrdnanceTypeName;

// Override in child classes to indicate that this targeting method fills out a movement path
// with GetPreAbilityPath() if needed.
var const bool ProvidesPath;

var transient array<Actor> MarkedTargets;
var protected transient XComInstancedMeshActor AOEMeshActor;
var protected bool bFriendlyFireAgainstUnits;
var protected bool bFriendlyFireAgainstObjects;
var protected bool bSeriousConsequencesForAction;
var delegate<ConfirmAbilityCallback> m_fnConfirmAbilityCallback;
var protected bool AbilityIsOffensive;

// Evaluate Stance Variables
var protected XGUnit FiringUnit;
var protected XComGameState_Unit UnitState;
var protected float SettleTimer;
var protected vector CachedTargetLocation;
var protected vector EvaluateStanceTargetLocation;
var protected config float TimeToSettleBeforeUpdatingStance;

var protected bool bHasPostProcess, bEnabledPostProcess;
var protected name EnablePostProcess, DisablePostProcess;

delegate bool ConfirmAbilityCallback(optional AvailableAction AvailableActionInfo);

function Init(AvailableAction InAction, int NewTargetIndex)
{
	local XComGameStateHistory History;

	Action = InAction;

	History = `XCOMHISTORY;
	Ability = XComGameState_Ability(History.GetGameStateForObjectID(Action.AbilityObjectRef.ObjectID));
	`assert(Ability != none);
	bFriendlyFireAgainstUnits = false; //friendly fire init to false, will be set to true only when friendly fire is detected on update
	bFriendlyFireAgainstObjects = false;
	bSeriousConsequencesForAction = false;

	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Ability.OwnerStateObject.ObjectID));
	`assert(UnitState != none);

	FiringUnit = XGUnit(UnitState.GetVisualizer());
	// We can activate many abilities before their visualizers are ready to go. There should probably be
	// some change to prevent non-visualizer dependent abilities from needing this check at all. 
	//`assert(FiringUnit != none);

	bHasPostProcess = UnitState.GetTargetingMethodPostProcess(Ability, Ability.GetSourceWeapon(), none, EnablePostProcess, DisablePostProcess);

	AOEMeshActor = `BATTLE.spawn(class'XComInstancedMeshActor');
	
	AbilityIsOffensive = GetAbilityIsOffensive();

	if(AbilityIsOffensive)
	{
		AOEMeshActor.InstancedMeshComponent.SetStaticMesh(StaticMesh(DynamicLoadObject("UI_3D.Tile.AOETile", class'StaticMesh')));
	}
	else
	{
		AOEMeshActor.InstancedMeshComponent.SetStaticMesh(StaticMesh(DynamicLoadObject("UI_3D.Tile.AOETile_Neutral", class'StaticMesh')));
	}

	// Start it at an impossible location to force an update
	CachedTargetLocation.Z = -255;
}

//Used in cases where we need a targeting method but it didn't come from input ( ie. AI shots, overwatch, etc. )
function InitFromState(XComGameState_Ability AbilityState)
{
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	Ability = AbilityState;
	`assert(Ability != none);
	bFriendlyFireAgainstUnits = false; //friendly fire init to false, will be set to true only when friendly fire is detected on update
	bFriendlyFireAgainstObjects = false;
	bSeriousConsequencesForAction = false;

	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Ability.OwnerStateObject.ObjectID));
	`assert(UnitState != none);

	FiringUnit = XGUnit(UnitState.GetVisualizer());

	// Start it at an impossible location to force an update
	CachedTargetLocation.Z = -255;
}

function UpdatePostProcessEffects(bool bEnabled)
{
	if (bHasPostProcess)
	{
		if (bEnabled)
		{
			if (EnablePostProcess != '')
				`PRES.EnablePostProcessEffect(EnablePostProcess, true, true);
			
			bEnabledPostProcess = true;
		}
		else if (bEnabledPostProcess)
		{
			if (DisablePostProcess != '')
				`PRES.EnablePostProcessEffect(DisablePostProcess, true, true);

			bEnabledPostProcess = false;
		}
	}
}

function Canceled()
{
	AOEMeshActor.Destroy();
}

function Committed();

function Update(float DeltaTime)
{
	UpdateTargetLocation(DeltaTime);
}

function UpdateTargetLocation(float DeltaTime)
{
	local vector NewTargetLocation;
	if( GetCurrentTargetFocus(NewTargetLocation) )
	{
		if( NewTargetLocation != CachedTargetLocation )
		{
			SettleTimer = 0.0f;
		}

		SettleTimer += DeltaTime;
		if( SettleTimer > TimeToSettleBeforeUpdatingStance && NewTargetLocation != EvaluateStanceTargetLocation )
		{
			EvaluateStanceTargetLocation = NewTargetLocation;
			FiringUnit.IdleStateMachine.CheckForStanceUpdate();
		}

		CachedTargetLocation = NewTargetLocation;
	}
}

function bool AllowMouseConfirm()
{
	return Action.bFreeAim;
}

function NextTarget();
function PrevTarget();

function DirectSetTarget(int TargetIndex);

native function DrawAOETiles(array<TTile> Tiles);

function int GetTargetIndex()
{
	return -1;
}

function bool GetAdditionalTargets(out AvailableTarget AdditionalTargets)
{
	return false;
}

function int GetTargetedObjectID()
{
	local int CurrentTargetIndex;

	CurrentTargetIndex = GetTargetIndex();
	if(CurrentTargetIndex >= 0 && CurrentTargetIndex < Action.AvailableTargets.Length)
	{
		return Action.AvailableTargets[CurrentTargetIndex].PrimaryTarget.ObjectID;
	}
	else
	{
		return 0;
	}
}

function Actor GetTargetedActor()
{
	local int TargetID;

	TargetID = GetTargetedObjectID();
	if (TargetID != 0)
		return `XCOMHISTORY.GetVisualizer(TargetID);

	return none;
}

function GetTargetLocations(out array<Vector> TargetLocations)
{
	TargetLocations.Length = 0;
}

function bool GetCurrentTargetFocus(out Vector Focus)
{
	return false;
}

function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	return 'AA_Success';
}

function bool GetPreAbilityPath(out array<TTile> PathTiles)
{
	return false;
}

/// <summary>
/// Returns true if this targeting method uses the precomputed path class to build a projectile path
/// </summary>
static function bool UseGrenadePath()
{
	return false;
}

/// <summary>
/// Returns the name of the timing style the projectile should use
/// </summary>
static function name GetProjectileTimingStyle()
{
	return default.ProjectileTimingStyle;
}

/// <summary>
/// Returns the name of the ordnance type
/// </summary>
static function name GetOrdnanceType()
{
	return default.OrdnanceTypeName;
}

protected native function ClearTargetedActors();
//Mark the Targeted Actor as friendly if ability is offensive and firing on friendly units
protected native function MarkTargetedActors(const out array<Actor> TargetedActors, const ETeam FirerTeam = eTeam_None);
protected native function GetTargetedActors(const vector Location, out array<Actor> TargetActors, optional out array<TTile> TargetTiles);

//	Uses only the provided TargetTiles list to generate a list of actors to mark, instead of using normal ability targeting logic
protected native function GetTargetedActorsInTiles(const out array<TTile> TargetTiles, out array<Actor> TargetActors, optional bool bUnitsOnly);

simulated public function FriendlyFireWarningCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		bFriendlyFireAgainstUnits = false;
		bFriendlyFireAgainstObjects = false;
		bSeriousConsequencesForAction = false;
		m_fnConfirmAbilityCallback();
	}
}

function bool VerifyTargetableFromIndividualMethod(delegate<ConfirmAbilityCallback> fnCallback)
{
	local TDialogueBoxData kDialogData;
	local XComPresentationLayerBase PresBase;

	if (bFriendlyFireAgainstObjects || bFriendlyFireAgainstUnits || bSeriousConsequencesForAction )
	{
		m_fnConfirmAbilityCallback = fnCallback;
		PresBase = XComPlayerController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController()).Pres;

		kDialogData.eType = eDialog_Warning;

		if (bFriendlyFireAgainstUnits)
		{
			kDialogData.strTitle = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendliesTitle;
			kDialogData.strText = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendliesBody;
			kDialogData.strAccept = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendliesAccept;
			kDialogData.strCancel = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendliesCancel;
		}
		else if( bFriendlyFireAgainstObjects )
		{
			kDialogData.strTitle = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendlyObjectTitle;
			kDialogData.strText = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendlyObjectBody;
			kDialogData.strAccept = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendlyObjectAccept;
			kDialogData.strCancel = class'UITacticalHUD_AbilityContainer'.default.m_strHitFriendlyObjectCancel;
		}
		else
		{
			kDialogData.strTitle = class'UITacticalHUD_AbilityContainer'.default.m_strAscensionPlatformTitle;
			kDialogData.strText = class'UITacticalHUD_AbilityContainer'.default.m_strAscensionPlatformBody;
			kDialogData.strAccept = class'UITacticalHUD_AbilityContainer'.default.m_strAscensionPlatformAccept;
			kDialogData.strCancel = class'UITacticalHUD_AbilityContainer'.default.m_strAscensionPlatformCancel;
		}
		kDialogData.fnCallback = FriendlyFireWarningCallback;

		PresBase.UIRaiseDialog(kDialogData);

		return false;
	}

	return true;
}

function bool GetAbilityIsOffensive()
{
	local X2AbilityTemplate AbilityTemplate;
	local X2GrenadeTemplate GrenadeTemplate;
	local XComGameState_Item SourceWeapon;

	AbilityTemplate = Ability.GetMyTemplate();
	if (AbilityTemplate.Hostility != eHostility_Offensive)
	{
		return false;
	}

	//  special handling for grenade hostility since they all get routed through ThrowGrenade or LaunchGrenade
	SourceWeapon = Ability.GetSourceWeapon();
	if (SourceWeapon != none)
	{
		GrenadeTemplate = X2GrenadeTemplate(SourceWeapon.GetMyTemplate());
		if (GrenadeTemplate != none && !GrenadeTemplate.bFriendlyFireWarning)
		{
			return false;
		}
		GrenadeTemplate = X2GrenadeTemplate(SourceWeapon.GetLoadedAmmoTemplate(Ability));
		if (GrenadeTemplate != none && !GrenadeTemplate.bFriendlyFireWarning)
		{
			return false;
		}
	}

	if (!AbilityTemplate.bFriendlyFireWarning)
		return false;

	return true;
}

function CheckForFriendlyUnit(const out array<Actor> list)
{
	local XComGameStateHistory History;
	local Actor TargetActor;
	local XGUnit TargetUnit;
	local ETeam FiringUnitTeam;
	local XComDestructibleActor TargetDestructible;
	local XComGameState_Destructible DestructibleState;
	local bool bWarnRobotsOnly;
	local XComGameState_Item SourceWeapon;
	local X2GrenadeTemplate GrenadeTemplate;

	bFriendlyFireAgainstUnits = false;
	bFriendlyFireAgainstObjects = false;
	bSeriousConsequencesForAction = false;

	if( !AbilityIsOffensive )
		return;

	bWarnRobotsOnly = Ability.GetMyTemplate().bFriendlyFireWarningRobotsOnly;
	SourceWeapon = Ability.GetSourceWeapon();
	if (SourceWeapon != none)
	{
		GrenadeTemplate = X2GrenadeTemplate(SourceWeapon.GetMyTemplate());
		if (GrenadeTemplate != none && GrenadeTemplate.bFriendlyFireWarningRobotsOnly)
		{
			bWarnRobotsOnly = true;
		}
		GrenadeTemplate = X2GrenadeTemplate(SourceWeapon.GetLoadedAmmoTemplate(Ability));
		if (GrenadeTemplate != none && GrenadeTemplate.bFriendlyFireWarningRobotsOnly)
		{
			bWarnRobotsOnly = true;
		}
	}

	History = `XCOMHISTORY;
	
	FiringUnitTeam = FiringUnit.GetTeam();
	foreach list(TargetActor)
	{
		TargetUnit = XGUnit(TargetActor);
		if (TargetUnit != none && (TargetUnit.GetTeam() == FiringUnitTeam) && TargetUnit.IsAlive() )
		{
			if (bWarnRobotsOnly && !TargetUnit.IsRobotic())
				continue;
			// I am friendly!
			bFriendlyFireAgainstUnits = true;
		}

		TargetDestructible = XComDestructibleActor(TargetActor);
		if(TargetDestructible != none && History.GetGameStateComponentForObjectID(TargetDestructible.ObjectID, class'XComGameState_ObjectiveInfo') != none && !bWarnRobotsOnly)
		{
			DestructibleState = XComGameState_Destructible(History.GetGameStateForObjectID(TargetDestructible.ObjectID));
			if(!DestructibleState.IsTargetable(FiringUnitTeam) && DestructibleState.Health > 0) // health < 0 == invincible
			{
				bFriendlyFireAgainstObjects = true;
			}
		}

		//Just to be pedantic, don't give up searching until we know that there's friendly-fire against both units and objects.
		//(In case something wants to specifically handle the "both" case)
		if (bFriendlyFireAgainstObjects && bFriendlyFireAgainstUnits)
			break;
	}
}

function GetProjectileTouchEvents(StateObjectReference PrimaryTarget, const array<Vector> TargetLocations, out array<ProjectileTouchEvent> TouchEvents, out vector TouchStart, out vector TouchEnd)
{
	local XComGameStateHistory History;
	local XComGameState_Unit SourceStateObject;
	local XComGameState_Unit TargetStateObject;
	local XGUnit SourceUnit;
	local XComWorldData WorldData;
	local XComPrecomputedPath ProjectilePath;

	local int OutCoverIndex;
	local UnitPeekSide OutPeekSide;
	local int OutRequiresLean;
	local int bCanSeeDefaultFromDefault;
	local bool bSteppingOut;

	
	if(UseGrenadePath())
	{
		ProjectilePath = `PRECOMPUTEDPATH;
		TouchEvents = ProjectilePath.TouchEvents;
		TouchStart = ProjectilePath.akKeyframes[0].vLoc;
		TouchEnd = ProjectilePath.GetEndPosition( );
	}
	else if(TargetLocations.Length > 0  && Ability != none)
	{
		History = `XCOMHISTORY;
		SourceStateObject = XComGameState_Unit(History.GetGameStateForObjectID(Ability.OwnerStateObject.ObjectID));
		TargetStateObject = XComGameState_Unit(History.GetGameStateForObjectID(PrimaryTarget.ObjectID));

		if( SourceStateObject != none )
		{
			WorldData = `XWORLD;

			SourceUnit = XGUnit(History.GetVisualizer(SourceStateObject.ObjectID));
			bSteppingOut = SourceUnit.GetStepOutCoverInfo(TargetStateObject, TargetLocations[0], OutCoverIndex, OutPeekSide, OutRequiresLean, bCanSeeDefaultFromDefault);
			TouchStart = SourceUnit.GetExitCoverPosition(OutCoverIndex, OutPeekSide, bSteppingOut);
			TouchStart.Z += 8.0f;

			TouchEnd = TargetLocations[0];
			WorldData.GenerateProjectileTouchList(SourceStateObject, TouchStart, TouchEnd, TouchEvents, false);
		}
	}
}


/// <summary>
// This is for making it so the targeting unit can still animate when off screen.  It's easy for the user to move 
// the targeting unit off screen, and without animation updates enabled, the targeting unit will not turn to 
// face the targeting cursor's location (leading to bugs such as TTP 9375).  mdomowicz 2015_08_25
/// </summary>
function EnableShooterSkelUpdatesWhenNotRendered(bool bEnable)
{
	FiringUnit.GetPawn().SetUpdateSkelWhenNotRendered(bEnable);
}

// some abilities, such as standard shot, will come from an OTS or other camera, and in this case we don't want the
// game to wait for the framing camera to arrive before allowing the visualization of the ability to continue. This
// function allows targeting methods to signal to the system that they do not want or need the game to wait.
static function bool ShouldWaitForFramingCamera()
{
	return true;
}

function bool ShouldUseMidpointCameraForTarget(int TargetID)
{
	local XComGameState_Unit TargetUnit;
	local XComGameState_Unit SourceUnit;
	local XComGameStateHistory History;
	local XComGameState_Effect EffectState;
	local StateObjectReference EffectRef;
	local XComGameState_Destructible Destructible;
	local vector SourceUnitLoc, TargetUnitLoc;
	local float VisRangeSq;

	History = `XCOMHISTORY;

	TargetUnit = XComGameState_Unit(History.GetGameStateForObjectID(TargetID));

	if( TargetUnit != None )
	{
		// if using squadsight (range greater than vis range), don't use midpoint
		SourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(Ability.OwnerStateObject.ObjectID));
		SourceUnitLoc = `XWORLD.GetPositionFromTileCoordinates(SourceUnit.TileLocation);
		TargetUnitLoc = `XWORLD.GetPositionFromTileCoordinates(TargetUnit.TileLocation);

		VisRangeSq = `METERSTOUNITS(SourceUnit.GetVisibilityRadius());
		VisRangeSq *= VisRangeSq;

		if( VSizeSq(SourceUnitLoc - TargetUnitLoc) > VisRangeSq )
		{
			return false;
		}

		foreach TargetUnit.AffectedByEffects(EffectRef)
		{
			EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if( EffectState != None && EffectState.GetX2Effect().ShouldUseMidpointCameraForTarget(Ability, TargetUnit) )
			{
				return true;
			}
		}
	}

	Destructible = XComGameState_Destructible(History.GetGameStateForObjectID(TargetID));
	if( Destructible != None )
	{
		return true;
	}

	return false;
}

defaultproperties
{
	ProjectileTimingStyle=""
	OrdnanceTypeName=""
}