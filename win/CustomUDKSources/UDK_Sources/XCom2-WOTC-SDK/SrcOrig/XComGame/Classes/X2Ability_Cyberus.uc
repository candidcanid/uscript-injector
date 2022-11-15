//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2Ability_Cyberus extends X2Ability
	config(GameData_SoldierSkills);

var localized string TeleportSuperpositionText;

var config int TELEPORT_LOCAL_COOLDOWN;
var config int TELEPORT_GLOBAL_COOLDOWN;
var config float TELEPORT_DAMAGE_RADIUS_METERS;
var config int TELEPORT_ENVIRONMENT_DAMAGE_AMOUNT;
var config int MALFUNCTION_LOCAL_COOLDOWN;
var config int MALFUNCTION_GLOBAL_COOLDOWN;
var config StatCheck MALFUNCTION_SOURCE_CHECK;
var config StatCheck MALFUNCTION_TARGET_CHECK;
var config int MALFUNCTION_TILE_WIDTH;
var config int MALFUNCTION_TILE_LENGTH;
var config int SUPERPOSITION_MAX_TILE_RADIUS;
var config int SUPERPOSITION_MIN_TILE_RADIUS;
var config int CYBERUS_TELEPORT_RANGE;
var config int PSI_BOMB_LOCAL_COOLDOWN;
var config int PSI_BOMB_GLOBAL_COOLDOWN;
var config int PSI_BOMB_RADIUS_METERS;
var config int PSI_BOMB_RANGE_METERS;
var config StatCheck PSI_BOMB_SOURCE_CHECK;
var config StatCheck PSI_BOMB_TARGET_CHECK;
var config float PSI_BOMB_STAGE1_START_WARNING_FX_SEC;
var config float PSI_BOMB_STAGE2_START_EXPLOSION_FX_SEC;
var config float PSI_BOMB_STAGE2_NOTIFY_TARGETS_SEC;

var config int TELEPORTMP_LOCAL_COOLDOWN;

var name CyberusTemplateName;

var name Stage1PsiBombEffectName;
var name PsiBombTriggerName;
var name DamageTeleportDamageChainIndexName;

var private name CyberusForcedDeadName;
var privatewrite name OriginalCyberusValueName;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	
	Templates.AddItem(CreateTeleportAbility());
	Templates.AddItem(CreateTriggerSuperpositionDamageListenerAbility());
	Templates.AddItem(CreateSuperpositionAbility());
	Templates.AddItem(PurePassive('Superposition', "img:///UILibrary_PerkIcons.UIPerk_codex_superposition"));
	Templates.AddItem(PurePassive('TechVulnerability', "img:///UILibrary_PerkIcons.UIPerk_codex_techvulnerability"));
	Templates.AddItem(CreatePsiBombStage1Ability());
	Templates.AddItem(CreatePsiBombStage2Ability());
	Templates.AddItem(CreateImmunitiesAbility());

	// MP Versions of Abilities
	Templates.AddItem(CreateTeleportMPAbility());
	Templates.AddItem(CreateTriggerSuperpositionDamageListenerMPAbility());
	
	return Templates;
}

static function X2DataTemplate CreateTeleportAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2AbilityCooldown_LocalAndGlobal Cooldown;
	local X2AbilityTarget_Cursor CursorTarget;
	local X2AbilityMultiTarget_Radius RadiusMultiTarget;
	local X2AbilityTrigger_PlayerInput InputTrigger;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Teleport');

	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_AlwaysShow;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_codex_teleport";

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown_LocalAndGlobal';
	Cooldown.iNumTurns = default.TELEPORT_LOCAL_COOLDOWN;
	Cooldown.NumGlobalTurns = default.TELEPORT_GLOBAL_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.TargetingMethod = class'X2TargetingMethod_Teleport';

	InputTrigger = new class'X2AbilityTrigger_PlayerInput';
	Template.AbilityTriggers.AddItem(InputTrigger);

	Template.AbilityToHitCalc = default.DeadEye;

	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.bRestrictToSquadsightRange = true;
//	CursorTarget.FixedAbilityRange = default.CYBERUS_TELEPORT_RANGE;     // yes there is.
	Template.AbilityTargetStyle = CursorTarget;

	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = 0.25; // small amount so it just grabs one tile
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	// Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	//// Damage Effect
	Template.AbilityMultiTargetConditions.AddItem(default.LivingTargetUnitOnlyProperty);
	//TeleportDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	//TeleportDamageEffect.EffectDamageValue = class'X2Item_DefaultWeapons'.default.CYBERUS_TELEPORT_BASEDAMAGE;
	//TeleportDamageEffect.EnvironmentalDamageAmount = default.TELEPORT_ENVIRONMENT_DAMAGE_AMOUNT;
	//TeleportDamageEffect.EffectDamageValue.DamageType = 'Melee';
	//Template.AddMultiTargetEffect(TeleportDamageEffect);

	Template.ModifyNewContextFn = Teleport_ModifyActivatedAbilityContext;
	Template.BuildNewGameStateFn = Teleport_BuildGameState;
	Template.BuildVisualizationFn = Teleport_BuildVisualization;
	Template.CinescriptCameraType = "Cyberus_Teleport";
//BEGIN AUTOGENERATED CODE: Template Overrides 'Teleport'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'Teleport'

	return Template;
}

static simulated function Teleport_ModifyActivatedAbilityContext(XComGameStateContext Context)
{
	local XComGameState_Unit UnitState;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameStateHistory History;
	local PathPoint NextPoint, EmptyPoint;
	local PathingInputData InputData;
	local XComWorldData World;
	local vector NewLocation;
	local TTile NewTileLocation;

	History = `XCOMHISTORY;
	World = `XWORLD;

	AbilityContext = XComGameStateContext_Ability(Context);
	`assert(AbilityContext.InputContext.TargetLocations.Length > 0);
	
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));

	// Build the MovementData for the path
	// First posiiton is the current location
	InputData.MovementTiles.AddItem(UnitState.TileLocation);

	NextPoint.Position = World.GetPositionFromTileCoordinates(UnitState.TileLocation);
	NextPoint.Traversal = eTraversal_Teleport;
	NextPoint.PathTileIndex = 0;
	InputData.MovementData.AddItem(NextPoint);

	// Second posiiton is the cursor position
	`assert(AbilityContext.InputContext.TargetLocations.Length == 1);

	NewLocation = AbilityContext.InputContext.TargetLocations[0];
	NewTileLocation = World.GetTileCoordinatesFromPosition(NewLocation);
	NewLocation = World.GetPositionFromTileCoordinates(NewTileLocation);

	NextPoint = EmptyPoint;
	NextPoint.Position = NewLocation;
	NextPoint.Traversal = eTraversal_Landing;
	NextPoint.PathTileIndex = 1;
	InputData.MovementData.AddItem(NextPoint);
	InputData.MovementTiles.AddItem(NewTileLocation);

    //Now add the path to the input context
	InputData.MovingUnitRef = UnitState.GetReference();
	AbilityContext.InputContext.MovementPaths.AddItem(InputData);
}

static simulated function XComGameState Teleport_BuildGameState(XComGameStateContext Context)
{
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;
	local XComGameStateContext_Ability AbilityContext;
	local vector NewLocation;
	local TTile NewTileLocation;
	local XComWorldData World;
	local X2EventManager EventManager;
	local int LastElementIndex;

	World = `XWORLD;
	EventManager = `XEVENTMGR;

	//Build the new game state frame
	NewGameState = TypicalAbility_BuildGameState(Context);

	AbilityContext = XComGameStateContext_Ability(NewGameState.GetContext());	
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AbilityContext.InputContext.SourceObject.ObjectID));

	LastElementIndex = AbilityContext.InputContext.MovementPaths[0].MovementData.Length - 1;

	// Set the unit's new location
	// The last position in MovementData will be the end location
	`assert(LastElementIndex > 0);
	NewLocation = AbilityContext.InputContext.MovementPaths[0].MovementData[LastElementIndex].Position;
	NewTileLocation = World.GetTileCoordinatesFromPosition(NewLocation);
	UnitState.SetVisibilityLocation(NewTileLocation);

	AbilityContext.ResultContext.bPathCausesDestruction = MoveAbility_StepCausesDestruction(UnitState, AbilityContext.InputContext, 0, AbilityContext.InputContext.MovementPaths[0].MovementTiles.Length - 1);
	MoveAbility_AddTileStateObjects(NewGameState, UnitState, AbilityContext.InputContext, 0, AbilityContext.InputContext.MovementPaths[0].MovementTiles.Length - 1);

	EventManager.TriggerEvent('ObjectMoved', UnitState, UnitState, NewGameState);
	EventManager.TriggerEvent('UnitMoveFinished', UnitState, UnitState, NewGameState);

	//Return the game state we have created
	return NewGameState;
}

simulated function Teleport_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local XComGameStateContext_Ability  AbilityContext;
	local StateObjectReference InteractingUnitRef;
	local X2AbilityTemplate AbilityTemplate;
	local VisualizationActionMetadata EmptyTrack, ActionMetadata;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
	local int i, j;
	local XComGameState_WorldEffectTileData WorldDataUpdate;
	local X2Action_MoveTurn MoveTurnAction;
	local X2VisualizerInterface TargetVisualizerInterface;
	
	History = `XCOMHISTORY;

	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	InteractingUnitRef = AbilityContext.InputContext.SourceObject;

	AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(AbilityContext.InputContext.AbilityTemplateName);

	//****************************************************************************************
	//Configure the visualization track for the source
	//****************************************************************************************
	ActionMetadata = EmptyTrack;
	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
	ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

	SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, AbilityContext));
	SoundAndFlyOver.SetSoundAndFlyOverParameters(None, AbilityTemplate.LocFlyOverText, '', eColor_Bad);

	// Turn to face the target action. The target location is the center of the ability's radius, stored in the 0 index of the TargetLocations
	MoveTurnAction = X2Action_MoveTurn(class'X2Action_MoveTurn'.static.AddToVisualizationTree(ActionMetadata, AbilityContext));
	MoveTurnAction.m_vFacePoint = AbilityContext.InputContext.TargetLocations[0];

	// move action
	class'X2VisualizerHelpers'.static.ParsePath(AbilityContext, ActionMetadata);

		
	//****************************************************************************************

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_WorldEffectTileData', WorldDataUpdate)
	{
		ActionMetadata = EmptyTrack;
		ActionMetadata.VisualizeActor = none;
		ActionMetadata.StateObject_NewState = WorldDataUpdate;
		ActionMetadata.StateObject_OldState = WorldDataUpdate;

		for (i = 0; i < AbilityTemplate.AbilityTargetEffects.Length; ++i)
		{
			AbilityTemplate.AbilityTargetEffects[i].AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, AbilityContext.FindTargetEffectApplyResult(AbilityTemplate.AbilityTargetEffects[i]));
		}

			}

	//****************************************************************************************
	//Configure the visualization track for the targets
	//****************************************************************************************
	for( i = 0; i < AbilityContext.InputContext.MultiTargets.Length; ++i )
	{
		InteractingUnitRef = AbilityContext.InputContext.MultiTargets[i];
		ActionMetadata = EmptyTrack;
		ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
		ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
		ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

		class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, AbilityContext);
		for( j = 0; j < AbilityContext.ResultContext.MultiTargetEffectResults[i].Effects.Length; ++j )
		{
			AbilityContext.ResultContext.MultiTargetEffectResults[i].Effects[j].AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, AbilityContext.ResultContext.MultiTargetEffectResults[i].ApplyResults[j]);
		}

		TargetVisualizerInterface = X2VisualizerInterface(ActionMetadata.VisualizeActor);
		if( TargetVisualizerInterface != none )
		{
			//Allow the visualizer to do any custom processing based on the new game state. For example, units will create a death action when they reach 0 HP.
			TargetVisualizerInterface.BuildAbilityEffectsVisualization(VisualizeGameState, ActionMetadata);
		}
	}
}

static function X2AbilityTemplate CreateTriggerSuperpositionDamageListenerAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_EventListener EventListener;
	local X2Effect_RunBehaviorTree RetractBehaviorEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'TriggerSuperpositionDamageListener');
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.bDontDisplayInAbilitySummary = true;

	Template.AdditionalAbilities.AddItem('TriggerSuperposition');

	// This ability fires when the unit takes damage
	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventID = 'UnitTakeEffectDamage';
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_DamagedTeleport;
	EventListener.ListenerData.Filter = eFilter_Unit;
	Template.AbilityTriggers.AddItem(EventListener);

	Template.AbilityTargetStyle = default.SelfTarget;

	RetractBehaviorEffect = new class'X2Effect_RunBehaviorTree';
	RetractBehaviorEffect.BehaviorTreeName = 'TryTriggerSuperposition';
	Template.AddTargetEffect(RetractBehaviorEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}

// Create Clone
// Teleport
static function X2AbilityTemplate CreateSuperpositionAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_EventListener EventListener;
	local X2Condition_UnitProperty UnitPropertyCondition;
	local array<name> SkipExclusions;
	local X2Condition_UnitEffects ExcludeEffects;
	
	`CREATE_X2ABILITY_TEMPLATE(Template, 'TriggerSuperposition');

	Template.bDontDisplayInAbilitySummary = true;
	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_codex_superposition";

	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventID = 'UnitMoveFinished';
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_DamagedTeleport;
	EventListener.ListenerData.Filter = eFilter_Unit;
	EventListener.ListenerData.Priority = 10000;    // Really low priority to ensure other listeners occur before this one
	Template.AbilityTriggers.AddItem(EventListener);

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;

	// The unit must be alive and not stunned
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeAlive = false;
	UnitPropertyCondition.ExcludeStunned = true;
	Template.AbilityShooterConditions.AddItem(UnitPropertyCondition);

	SkipExclusions.AddItem(class'X2StatusEffects'.default.BurningName);
	Template.AddShooterEffectExclusions(SkipExclusions);

	ExcludeEffects = new class'X2Condition_UnitEffects';
	ExcludeEffects.AddExcludeEffect(class'X2Effect_MindControl'.default.EffectName, 'AA_UnitIsMindControlled');
	Template.AbilityShooterConditions.AddItem(ExcludeEffects);

	Template.bSkipFireAction = true;
	Template.ModifyNewContextFn = Superposition_ModifyActivatedAbilityContext;
	Template.BuildNewGameStateFn = Superposition_BuildGameState;
	Template.BuildVisualizationFn = Superposition_BuildVisualization;
	Template.CinescriptCameraType = "Cyberus_Superposition";
//BEGIN AUTOGENERATED CODE: Template Overrides 'TriggerSuperposition'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'TriggerSuperposition'

	return Template;
}

simulated function Superposition_ModifyActivatedAbilityContext(XComGameStateContext Context)
{
	local XComGameState_Unit UnitState;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameStateHistory History;
	local PathPoint NextPoint, EmptyPoint;
	local XGUnit UnitVisualizer;
	local PathingInputData InputData;
	local XComCoverPoint CoverPoint;
	local XComWorldData World;
	local TTile TempTile;
	local bool bCoverPointFound;

	History = `XCOMHISTORY;
	World = `XWORLD;

	AbilityContext = XComGameStateContext_Ability(Context);
	
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
	//UnitState = XComGameState_Unit(AbilityContext.AssociatedState.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
	`assert(UnitState != none);

	// Build the MovementData for the path
	UnitVisualizer = XGUnit(UnitState.GetVisualizer());

	// First posiiton is the current location
	InputData.MovementTiles.AddItem(UnitState.TileLocation);

	NextPoint.Position = World.GetPositionFromTileCoordinates(UnitState.TileLocation);
	NextPoint.Traversal = eTraversal_Teleport;
	NextPoint.PathTileIndex = 0;
	InputData.MovementData.AddItem(NextPoint);

	// Second posiiton: Currently selected from WorldData's get closest cover function but doesn't
	// weigh the value of cover points
	bCoverPointFound = UnitVisualizer.m_kBehavior.PickRandomCoverLocation(NextPoint.Position, default.SUPERPOSITION_MIN_TILE_RADIUS, default.SUPERPOSITION_MAX_TILE_RADIUS);
	TempTile = World.GetTileCoordinatesFromPosition(NextPoint.Position);

	if( !bCoverPointFound )
	{
		CoverPoint.TileLocation =  World.FindClosestValidLocation(NextPoint.Position, false, false, false);
		TempTile = World.GetTileCoordinatesFromPosition(CoverPoint.TileLocation);
	}

	NextPoint = EmptyPoint;
	World.GetFloorPositionForTile(TempTile, NextPoint.Position);
	NextPoint.Traversal = eTraversal_Landing;
	NextPoint.PathTileIndex = 1;
	InputData.MovementData.AddItem(NextPoint);
	InputData.MovementTiles.AddItem(TempTile);

	//Now add the path to the input context
	InputData.MovingUnitRef = UnitState.GetReference();
	AbilityContext.InputContext.MovementPaths.AddItem(InputData);
}

simulated function XComGameState Superposition_BuildGameState(XComGameStateContext Context)
{
	local XComGameState NewGameState;
	local XComGameState_Unit OldUnitState, UnitState, SpawnedCodexUnit;
	local XComGameStateContext_Ability AbilityContext;
	local vector NewLocation;
	local TTile NewTileLocation;
	local XComWorldData World;
	local X2EventManager EventManager;
	local XComAISpawnManager SpawnManager;
	local int SourceUnitHP, HalfHP;
	local StateObjectReference NewUnitRef;
	local int LastElementIndex;
	local XComGameState_AIGroup OldGroup;
	local UnitValue OriginalCodexObjectIDValue;
	local float OriginalCodexObjectID;

	World = `XWORLD;
	EventManager = `XEVENTMGR;
	SpawnManager = `SPAWNMGR;

	//Build the new game state frame
	NewGameState = TypicalAbility_BuildGameState(Context);

	AbilityContext = XComGameStateContext_Ability(NewGameState.GetContext());
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AbilityContext.InputContext.SourceObject.ObjectID));
	OldUnitState = UnitState;
	
	if( OldUnitState != none )
	{
		// Do Superposition
		LastElementIndex = AbilityContext.InputContext.MovementPaths[0].MovementData.Length - 1;

		// Set the unit's new location
		// The last position in MovementData will be the end location
		`assert(LastElementIndex > 0);
		NewLocation = AbilityContext.InputContext.MovementPaths[0].MovementData[LastElementIndex].Position;
		NewTileLocation = World.GetTileCoordinatesFromPosition(NewLocation);
		UnitState.SetVisibilityLocation(NewTileLocation);

		AbilityContext.ResultContext.bPathCausesDestruction = MoveAbility_StepCausesDestruction(UnitState, AbilityContext.InputContext, 0, LastElementIndex);
		MoveAbility_AddTileStateObjects(NewGameState, UnitState, AbilityContext.InputContext, 0, LastElementIndex);

		EventManager.TriggerEvent('ObjectMoved', UnitState, UnitState, NewGameState);
		EventManager.TriggerEvent('UnitMoveFinished', UnitState, UnitState, NewGameState);

		SourceUnitHP = UnitState.GetCurrentStat(eStat_HP);

		if( SourceUnitHP > 1 )
		{
			HalfHP = SourceUnitHP / 2;  // Rounds down so that the original gets the extra HP on odd values
			SourceUnitHP = SourceUnitHP - HalfHP;

			UnitState.SetCurrentStat(eStat_HP, SourceUnitHP);

			// Remove the tile block of the original Codex
			World.ClearTileBlockedByUnitFlag(UnitState);

			// Spawn the Clone
			NewLocation = AbilityContext.InputContext.MovementPaths[0].MovementData[0].Position;
			OldGroup = UnitState.GetGroupMembership();
			NewUnitRef = SpawnManager.CreateUnit(NewLocation, UnitState.GetMyTemplateName(), OldUnitState.GetTeam(), false, false, NewGameState, , , , , OldGroup.ObjectID);
			SpawnedCodexUnit = XComGameState_Unit(NewGameState.GetGameStateForObjectID(NewUnitRef.ObjectID));
			SpawnedCodexUnit.SetCurrentStat(eStat_HP, HalfHP);
			SpawnedCodexUnit.bTriggerRevealAI = false;

			// Make sure the Codex doesn't spawn with any action points this turn
			SpawnedCodexUnit.ActionPoints.Length = 0;

			UnitState.SetUnitFloatValue(class'X2Effect_SpawnUnit'.default.SpawnedUnitValueName, NewUnitRef.ObjectID, eCleanup_BeginTurn);

			// The newly spawned codex needs to be branded with the group's original Codex ID
			OriginalCodexObjectID = UnitState.ObjectID;
			if(UnitState.GetUnitValue(default.OriginalCyberusValueName, OriginalCodexObjectIDValue))
			{
				// If the UnitState has a value for OriginalCyberusValueName, use that since it is the original Codex of the group
				OriginalCodexObjectID = OriginalCodexObjectIDValue.fValue;
			}

			SpawnedCodexUnit.SetUnitFloatValue(default.OriginalCyberusValueName, OriginalCodexObjectID, eCleanup_BeginTactical);
			SpawnedCodexUnit.SetUnitFloatValue('NewSpawnedUnit', 1, eCleanup_BeginTactical);
		}
	}

	//Return the game state we have created
	return NewGameState;
}

// Camera looks at Codex
// Show the clone flyover
// Animate the clone with its stay animation
// Animate the original with its go animation
// Camera moves to teleport location
// Animate the original in with teleport stop
simulated function Superposition_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local XComGameStateContext_Ability  AbilityContext;
	local StateObjectReference InteractingUnitRef;
	local X2AbilityTemplate AbilityTemplate;
	local VisualizationActionMetadata EmptyTrack, ActionMetadata, OriginalCodexMetadata;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
	local XComGameState_Unit UnitState, SpawnedUnit;
	local UnitValue SpawnedUnitValue;
	local X2Action_SuperpositionUnitStay ShowUnitAction;
	local XGUnit OriginalCodex;
	local X2Action_CameraLookAt LookAtAction;	
	local X2Action_SuperpositionUnitGo MoveOriginalCodexAction;
	local X2Action_UpdateFOW FOWAction;
	
	History = `XCOMHISTORY;

	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	InteractingUnitRef = AbilityContext.InputContext.SourceObject;

	AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(AbilityContext.InputContext.AbilityTemplateName);

	//****************************************************************************************
	//Configure the visualization track for the source
	//****************************************************************************************
	OriginalCodexMetadata = EmptyTrack;
	OriginalCodexMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	OriginalCodexMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
	OriginalCodexMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

	// Get the original Codex
	UnitState = XComGameState_Unit(OriginalCodexMetadata.StateObject_NewState);

	// Get the spawned Codex
	UnitState.GetUnitValue(class'X2Effect_SpawnUnit'.default.SpawnedUnitValueName, SpawnedUnitValue);
	SpawnedUnit = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(SpawnedUnitValue.fValue));

	UnitState = XComGameState_Unit(OriginalCodexMetadata.StateObject_NewState);
	LookAtAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(OriginalCodexMetadata, VisualizeGameState.GetContext(), false, OriginalCodexMetadata.LastActionAdded));
	LookAtAction.UseTether = false;
	LookAtAction.LookAtObject = UnitState;
	LookAtAction.BlockUntilActorOnScreen = true;

	SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(OriginalCodexMetadata, AbilityContext));
	if (SpawnedUnit != none)
	{
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, AbilityTemplate.LocFlyOverText, '', eColor_Bad);
	}
	else
	{
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, TeleportSuperpositionText, '', eColor_Bad);
	}

	OriginalCodex = XGUnit(OriginalCodexMetadata.VisualizeActor);

	//****************************************************************************************
	//Configure the visualization track for the targets
	//****************************************************************************************
	if (SpawnedUnit != none)
	{
		// The Spawned unit should appear and play its change animation
		ActionMetadata = EmptyTrack;
		ActionMetadata.StateObject_OldState = SpawnedUnit;
		ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
		ActionMetadata.VisualizeActor = History.GetVisualizer(SpawnedUnit.ObjectID);

		ShowUnitAction = X2Action_SuperpositionUnitStay(class'X2Action_SuperpositionUnitStay'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, SoundAndFlyOver));
		ShowUnitAction.OriginalCodex = OriginalCodex;
	}

	// Ensure that the movement data is as expected
	`assert((AbilityContext.InputContext.MovementPaths.Length == 1) && (AbilityContext.InputContext.MovementPaths[0].MovementData.Length == 2));

	// Teleport out
	// Move the camera
	// Teleport in
	MoveOriginalCodexAction = X2Action_SuperpositionUnitGo(class'X2Action_SuperpositionUnitGo'.static.AddToVisualizationTree(OriginalCodexMetadata, AbilityContext, false, SoundAndFlyOver));
	MoveOriginalCodexAction.bWaitForSpawnedUnitStay = SpawnedUnit != none;
	MoveOriginalCodexAction.Destination = AbilityContext.InputContext.MovementPaths[0].MovementData[1].Position;

	FOWAction = X2Action_UpdateFOW( class'X2Action_UpdateFOW'.static.AddToVisualizationTree( OriginalCodexMetadata, AbilityContext ) );
	FOWAction.ForceUpdate = true;
}

static function X2AbilityTemplate CreatePsiBombStage1Ability()
{
	local X2AbilityTemplate Template;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2AbilityCooldown_LocalAndGlobal Cooldown;
	local X2AbilityMultiTarget_Radius RadiusMultiTarget;
	local X2Effect_MarkValidActivationTiles MarkTilesEffect;
	local X2AbilityTarget_Cursor CursorTarget;
	local X2Effect_DelayedAbilityActivation DelayedDimensionalRiftEffect;
	local X2Effect_DisableWeapon DisableWeapon;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'PsiBombStage1');

	Template.AdditionalAbilities.AddItem('PsiBombStage2');
	Template.TwoTurnAttackAbility = 'PsiBombStage2';
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_psibomb";

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.bShowActivation = true;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown_LocalAndGlobal';
	Cooldown.iNumTurns = default.PSI_BOMB_LOCAL_COOLDOWN;
	Cooldown.NumGlobalTurns = default.PSI_BOMB_GLOBAL_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = default.PSI_BOMB_RADIUS_METERS;
	RadiusMultiTarget.bIgnoreBlockingCover = true;
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	MarkTilesEffect = new class'X2Effect_MarkValidActivationTiles';
	MarkTilesEffect.AbilityToMark = 'PsiBombStage2';
	MarkTilesEffect.OnlyUseTargetLocation = true;
	Template.AddShooterEffect(MarkTilesEffect);

	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.bRestrictToSquadsightRange = true;
	CursorTarget.FixedAbilityRange = default.PSI_BOMB_RANGE_METERS;
	Template.AbilityTargetStyle = CursorTarget;

	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	//Effect on a successful test is adding the delayed marked effect to the target
	DelayedDimensionalRiftEffect = new class 'X2Effect_DelayedAbilityActivation';
	DelayedDimensionalRiftEffect.BuildPersistentEffect(1, false, false, , eGameRule_PlayerTurnBegin);
	DelayedDimensionalRiftEffect.EffectName = default.Stage1PsiBombEffectName;
	DelayedDimensionalRiftEffect.TriggerEventName = default.PsiBombTriggerName;
	DelayedDimensionalRiftEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true, , Template.AbilitySourceName);
	Template.AddShooterEffect(DelayedDimensionalRiftEffect);

	DisableWeapon = new class'X2Effect_DisableWeapon';
	DisableWeapon.TargetConditions.AddItem(default.LivingTargetUnitOnlyProperty);
	Template.AddMultiTargetEffect(DisableWeapon);

	Template.TargetingMethod = class'X2TargetingMethod_VoidRift';

	Template.CustomFireAnim = 'HL_Malfunction';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	Template.BuildVisualizationFn = PsiBombStage1_BuildVisualization;
	Template.BuildAffectedVisualizationSyncFn = PsiBombStage1_BuildAffectedVisualization;
	Template.CinescriptCameraType = "Codex_PsiBomb_Stage1";
	Template.DamagePreviewFn = PsiBombDamagePreview;
//BEGIN AUTOGENERATED CODE: Template Overrides 'PsiBombStage1'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'PsiBombStage1'

	return Template;
}

function bool PsiBombDamagePreview(XComGameState_Ability AbilityState, StateObjectReference TargetRef, out WeaponDamageValue MinDamagePreview, out WeaponDamageValue MaxDamagePreview, out int AllowsShield)
{
	local XComGameState_Unit AbilityOwner;
	local StateObjectReference PsiBombStage2Ref;
	local XComGameState_Ability PsiBombStage2Ability;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	AbilityOwner = XComGameState_Unit(History.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
	PsiBombStage2Ref = AbilityOwner.FindAbility('PsiBombStage2');
	PsiBombStage2Ability = XComGameState_Ability(History.GetGameStateForObjectID(PsiBombStage2Ref.ObjectID));
	if( PsiBombStage2Ability == none )
	{
		`RedScreenOnce("Unit has PsiBombStage1 but is missing PsiBombStage2. No es Bueno. -dslonneger @gameplay");
	}
	else
	{
		PsiBombStage2Ability.GetDamagePreview(TargetRef, MinDamagePreview, MaxDamagePreview, AllowsShield);
	}
	return true;
}

simulated function PsiBombStage1_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local XComGameStateContext_Ability Context;
	local StateObjectReference InteractingUnitRef;
	local X2VisualizerInterface Visualizer;
	local VisualizationActionMetadata CyberusBuildTrack, ActionMetadata, EmptyTrack;
	local X2Action_PlayEffect EffectAction;
	local X2Action_StartStopSound SoundAction;
	local XComGameState_Unit CyberusUnit;
	local XComWorldData World;
	local vector TargetLocation;
	local TTile TargetTile;
	local X2Action_TimedWait WaitAction;
	local X2Action_PlaySoundAndFlyOver SoundCueAction;
	local int i, j;
	local X2VisualizerInterface TargetVisualizerInterface;
	local X2Action_Fire_CloseUnfinishedAnim CloseFireAction;
	local XGUnit CodexUnit;
	local XComUnitPawn CodexPawn;
	local X2Action ExitCoverAction;

	History = `XCOMHISTORY;

	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	//Configure the visualization track for the shooter
	//****************************************************************************************
	InteractingUnitRef = Context.InputContext.SourceObject;
	CyberusBuildTrack.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	CyberusBuildTrack.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
	CyberusBuildTrack.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

	CyberusUnit = XComGameState_Unit(CyberusBuildTrack.StateObject_NewState);

	if( CyberusUnit != none )
	{
		World = `XWORLD;

		// Exit cover
		ExitCoverAction = class'X2Action_ExitCover'.static.AddToVisualizationTree(CyberusBuildTrack, Context);

		//If we were interrupted, insert a marker node for the interrupting visualization code to use. In the move path version above, it is expected for interrupts to be 
		//done during the move.
		if (Context.InterruptionStatus != eInterruptionStatus_None)
		{
			//Insert markers for the subsequent interrupt to insert into
			class'X2Action'.static.AddInterruptMarkerPair(CyberusBuildTrack, Context, ExitCoverAction);
		}

		class'X2Action_Fire_OpenUnfinishedAnim'.static.AddToVisualizationTree(CyberusBuildTrack, Context);

		// Wait to time the start of the warning FX
		WaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		WaitAction.DelayTimeSec = default.PSI_BOMB_STAGE1_START_WARNING_FX_SEC;

		// Display the Warning FX (convert to tile and back to vector because stage 2 is at the GetPositionFromTileCoordinates coord
		EffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		EffectAction.EffectName = "FX_Psi_Bomb.P_Psi_Bomb_Warning";

		TargetLocation = Context.InputContext.TargetLocations[0];
		TargetTile = World.GetTileCoordinatesFromPosition(TargetLocation);

		EffectAction.EffectLocation = World.GetPositionFromTileCoordinates(TargetTile);

		// Play Target Activate Sound
		SoundAction = X2Action_StartStopSound(class'X2Action_StartStopSound'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		SoundAction.Sound = new class'SoundCue';
		SoundAction.Sound.AkEventOverride = AkEvent'SoundX2CyberusFX.Cyberus_Psi_Bomb_Target_Activate';
		SoundAction.iAssociatedGameStateObjectId = CyberusUnit.ObjectID;
		SoundAction.bStartPersistentSound = true;
		SoundAction.bIsPositional = true;
		SoundAction.vWorldPosition = EffectAction.EffectLocation;

		// Play the sound cue
		SoundCueAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		SoundCueAction.SetSoundAndFlyOverParameters(SoundCue'SoundX2CyberusFX.Cyberus_Psi_Bomb_Target_Activate_Cue', "", '', eColor_Good);

		CloseFireAction = X2Action_Fire_CloseUnfinishedAnim(class'X2Action_Fire_CloseUnfinishedAnim'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		CloseFireAction.bNotifyTargets = true;

		Visualizer = X2VisualizerInterface(CyberusBuildTrack.VisualizeActor);
		if( Visualizer != none )
		{
			Visualizer.BuildAbilityEffectsVisualization(VisualizeGameState, CyberusBuildTrack);
		}

		class'X2Action_EnterCover'.static.AddToVisualizationTree(CyberusBuildTrack, Context);

		CodexUnit = XGUnit(CyberusBuildTrack.VisualizeActor);
		if( CodexUnit != none )
		{
			CodexPawn = CodexUnit.GetPawn();
			if( CodexPawn != none )
			{
				X2Action_SetWeapon(class'X2Action_SetWeapon'.static.AddToVisualizationTree(CyberusBuildTrack, Context)).WeaponToSet = XComWeapon(CodexPawn.Weapon);
			}
		}
		//****************************************************************************************

		//****************************************************************************************
		//Configure the visualization track for the targets
		//****************************************************************************************
		for( i = 0; i < Context.InputContext.MultiTargets.Length; ++i )
		{
			InteractingUnitRef = Context.InputContext.MultiTargets[i];
			if( InteractingUnitRef == CyberusUnit.GetReference() )
			{
				ActionMetadata = CyberusBuildTrack;
			}
			else
			{
				ActionMetadata = EmptyTrack;
				ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
				ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
				ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);
			}

			if( InteractingUnitRef != CyberusUnit.GetReference() )
			{
				class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
			}

			for( j = 0; j < Context.ResultContext.MultiTargetEffectResults[i].Effects.Length; ++j )
			{
				Context.ResultContext.MultiTargetEffectResults[i].Effects[j].AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, Context.ResultContext.MultiTargetEffectResults[i].ApplyResults[j]);
			}

			TargetVisualizerInterface = X2VisualizerInterface(ActionMetadata.VisualizeActor);
			if( TargetVisualizerInterface != none )
			{
				//Allow the visualizer to do any custom processing based on the new game state. For example, units will create a death action when they reach 0 HP.
				TargetVisualizerInterface.BuildAbilityEffectsVisualization(VisualizeGameState, ActionMetadata);
			}
		}

		TypicalAbility_AddEffectRedirects(VisualizeGameState, CyberusBuildTrack);
	}
}

simulated function PsiBombStage1_BuildAffectedVisualization(name EffectName, XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata )
{
	local XComGameStateContext_Ability Context;
	local X2Action_PlayEffect EffectAction;
	local X2Action_StartStopSound SoundAction;
	local XComGameState_Unit CyberusUnit;
	local XComWorldData World;
	local vector TargetLocation;
	local TTile TargetTile;
	
	if( !`XENGINE.IsMultiplayerGame() && EffectName == default.Stage1PsiBombEffectName )
	{
		Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
		CyberusUnit = XComGameState_Unit(ActionMetadata.StateObject_NewState);

		if( (Context == none) || (CyberusUnit == none) )
		{
			return;
		}

		World = `XWORLD;

		// Display the Warning FX (convert to tile and back to vector because stage 2 is at the GetPositionFromTileCoordinates coord
		EffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		EffectAction.EffectName = "FX_Psi_Bomb.P_Psi_Bomb_Warning";

		TargetLocation = Context.InputContext.TargetLocations[0];
		TargetTile = World.GetTileCoordinatesFromPosition(TargetLocation);

		EffectAction.EffectLocation = World.GetPositionFromTileCoordinates(TargetTile);

		// Play Target Activate Sound
		SoundAction = X2Action_StartStopSound(class'X2Action_StartStopSound'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		SoundAction.Sound = new class'SoundCue';
		SoundAction.Sound.AkEventOverride = AkEvent'SoundX2CyberusFX.Cyberus_Psi_Bomb_Target_Activate';
		SoundAction.iAssociatedGameStateObjectId = CyberusUnit.ObjectID;
		SoundAction.bStartPersistentSound = true;
		SoundAction.bIsPositional = true;
		SoundAction.vWorldPosition = EffectAction.EffectLocation;
	}
}

static function X2AbilityTemplate CreatePsiBombStage2Ability()
{
	local X2AbilityTemplate Template;
	local X2AbilityMultiTarget_Radius RadiusMultiTarget;
	local X2Condition_UnitProperty LivingTargetCondition;
	local X2AbilityTrigger_EventListener DelayedEventListener;
	local X2Effect_ApplyWeaponDamage RiftDamageEffect;
	local X2Effect_PerkAttachForFX FXEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'PsiBombStage2');

	Template.bDontDisplayInAbilitySummary = true;
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';

	Template.AbilityToHitCalc = default.DeadEye;

	LivingTargetCondition = new class'X2Condition_UnitProperty';
	LivingTargetCondition.ExcludeFriendlyToSource = false;
	LivingTargetCondition.ExcludeHostileToSource = false;
	LivingTargetCondition.ExcludeAlive = false;
	LivingTargetCondition.ExcludeDead = true;
	LivingTargetCondition.FailOnNonUnits = true;
	Template.AbilityMultiTargetConditions.AddItem(LivingTargetCondition);

	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = default.PSI_BOMB_RADIUS_METERS;
	RadiusMultiTarget.bIgnoreBlockingCover = true;
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	// TODO: This doesn't actually target self but needs an AbilityTargetStyle
	Template.AbilityTargetStyle = default.SelfTarget;

	// This ability fires when the event DelayedExecuteRemoved fires on this unit
	DelayedEventListener = new class'X2AbilityTrigger_EventListener';
	DelayedEventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	DelayedEventListener.ListenerData.EventID = default.PsiBombTriggerName;
	DelayedEventListener.ListenerData.Filter = eFilter_Unit;
	DelayedEventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_ValidAbilityLocation;
	Template.AbilityTriggers.AddItem(DelayedEventListener);

	// This effect is here to attach perk FX to
	FXEffect = new class'X2Effect_PerkAttachForFX';
	Template.AddShooterEffect(FXEffect);

	RiftDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	RiftDamageEffect.EffectDamageValue.DamageType = 'Psi';
	RiftDamageEffect.EffectDamageValue = class'X2Item_DefaultWeapons'.default.CYBERUS_PSI_BOMB_BASEDAMAGE;
	RiftDamageEffect.bIgnoreArmor = true;
	Template.AddMultiTargetEffect(RiftDamageEffect);

	Template.bSkipFireAction = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = PsiBombStage2_BuildVisualization;
	Template.CinescriptCameraType = "Codex_PsiBomb_Stage2";
//BEGIN AUTOGENERATED CODE: Template Overrides 'PsiBombStage2'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'PsiBombStage2'

	return Template;
}

simulated function PsiBombStage2_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local XComGameStateContext_Ability  Context;
	local StateObjectReference InteractingUnitRef;
	local X2AbilityTemplate AbilityTemplate;
	local VisualizationActionMetadata EmptyTrack;
	local VisualizationActionMetadata CyberusBuildTrack, ActionMetadata;
	local int i, j;
	local X2VisualizerInterface TargetVisualizerInterface;
	local XComGameState_EnvironmentDamage EnvironmentDamageEvent;
	local XComGameState_WorldEffectTileData WorldDataUpdate;
	local XComGameState_InteractiveObject InteractiveObject;
	local X2Action_PlayEffect EffectAction;
	local X2Action_StartStopSound SoundAction;
	local XComGameState_Unit CyberusUnit;
	local X2Action_TimedInterTrackMessageAllMultiTargets MultiTargetMessageAction;
	local X2Action_TimedWait WaitAction;

	History = `XCOMHISTORY;

	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	InteractingUnitRef = Context.InputContext.SourceObject;

	AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(Context.InputContext.AbilityTemplateName);

	//****************************************************************************************
	//Configure the visualization track for the source
	//****************************************************************************************
	CyberusBuildTrack = EmptyTrack;
	History.GetCurrentAndPreviousGameStatesForObjectID(InteractingUnitRef.ObjectID,
													   CyberusBuildTrack.StateObject_OldState, CyberusBuildTrack.StateObject_NewState,
													   eReturnType_Reference,
													   VisualizeGameState.HistoryIndex);
	CyberusBuildTrack.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

	CyberusUnit = XComGameState_Unit(CyberusBuildTrack.StateObject_OldState);

	if( CyberusUnit != none )
	{
		// Stop the Loop audio
		SoundAction = X2Action_StartStopSound(class'X2Action_StartStopSound'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		SoundAction.Sound = new class'SoundCue';
		SoundAction.Sound.AkEventOverride = AkEvent'SoundX2CyberusFX.Stop_CodexPsiBombLoop';
		SoundAction.iAssociatedGameStateObjectId = InteractingUnitRef.ObjectID;
		SoundAction.bIsPositional = true;
		SoundAction.bStopPersistentSound = true;

		// Stop the Warning FX
		EffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		EffectAction.EffectName = "FX_Psi_Bomb.P_Psi_Bomb_Warning";
		EffectAction.EffectLocation = Context.InputContext.TargetLocations[0];
		EffectAction.bStopEffect = true;

		// Play the Collapsing audio
		SoundAction = X2Action_StartStopSound(class'X2Action_StartStopSound'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		SoundAction.Sound = new class'SoundCue';
		SoundAction.Sound.AkEventOverride = AkEvent'SoundX2CyberusFX.Cyberus_Ability_Psi_Bomb_Collapse';
		SoundAction.bIsPositional = true;
		SoundAction.vWorldPosition = Context.InputContext.TargetLocations[0];

		// Play the Collapse FX
		EffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		EffectAction.EffectName = "FX_Psi_Bomb.P_Psi_Bomb_Build_Up";
		EffectAction.EffectLocation = Context.InputContext.TargetLocations[0];
		EffectAction.bWaitForCompletion = false;
		EffectAction.bWaitForCameraCompletion = false;

		// Wait to time the start of the explosion FX
		WaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		WaitAction.DelayTimeSec = default.PSI_BOMB_STAGE2_START_EXPLOSION_FX_SEC;

		// Play the Explosion audio
		SoundAction = X2Action_StartStopSound(class'X2Action_StartStopSound'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		SoundAction.Sound = new class'SoundCue';
		SoundAction.Sound.AkEventOverride = AkEvent'SoundX2AvatarFX.Avatar_Ability_Dimensional_Rift_Explode';
		SoundAction.bIsPositional = true;
		SoundAction.vWorldPosition = Context.InputContext.TargetLocations[0];

		// Play the Explosion FX
		EffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		EffectAction.EffectName = "FX_Psi_Bomb.P_Psi_Bomb_Explosion";
		EffectAction.EffectLocation = Context.InputContext.TargetLocations[0];

		// Notify multi targets of explosion
		MultiTargetMessageAction = X2Action_TimedInterTrackMessageAllMultiTargets(class'X2Action_TimedInterTrackMessageAllMultiTargets'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
		MultiTargetMessageAction.SendMessagesAfterSec = default.PSI_BOMB_STAGE2_NOTIFY_TARGETS_SEC;
	}
	//****************************************************************************************

	//****************************************************************************************
	//Configure the visualization track for the targets
	//****************************************************************************************
	for (i = 0; i < Context.InputContext.MultiTargets.Length; ++i)
	{
		InteractingUnitRef = Context.InputContext.MultiTargets[i];

		if( InteractingUnitRef == CyberusUnit.GetReference() )
		{
			ActionMetadata = CyberusBuildTrack;

			WaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(CyberusBuildTrack, Context));
			WaitAction.DelayTimeSec = default.PSI_BOMB_STAGE2_NOTIFY_TARGETS_SEC;
		}
		else
		{
			ActionMetadata = EmptyTrack;
			ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
			ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
			ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

			class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
		}

		for( j = 0; j < Context.ResultContext.MultiTargetEffectResults[i].Effects.Length; ++j )
		{
			Context.ResultContext.MultiTargetEffectResults[i].Effects[j].AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, Context.ResultContext.MultiTargetEffectResults[i].ApplyResults[j]);
		}

		TargetVisualizerInterface = X2VisualizerInterface(ActionMetadata.VisualizeActor);
		if( TargetVisualizerInterface != none )
		{
			//Allow the visualizer to do any custom processing based on the new game state. For example, units will create a death action when they reach 0 HP.
			TargetVisualizerInterface.BuildAbilityEffectsVisualization(VisualizeGameState, ActionMetadata);
		}
	}

	//****************************************************************************************
	//Configure the visualization tracks for the environment
	//****************************************************************************************
	foreach VisualizeGameState.IterateByClassType(class'XComGameState_EnvironmentDamage', EnvironmentDamageEvent)
	{
		ActionMetadata = EmptyTrack;
		ActionMetadata.VisualizeActor = none;
		ActionMetadata.StateObject_NewState = EnvironmentDamageEvent;
		ActionMetadata.StateObject_OldState = EnvironmentDamageEvent;

		//Wait until signaled by the shooter that the projectiles are hitting
		class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);

		for( i = 0; i < AbilityTemplate.AbilityMultiTargetEffects.Length; ++i )
		{
			AbilityTemplate.AbilityMultiTargetEffects[i].AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, 'AA_Success');	
		}

			}

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_WorldEffectTileData', WorldDataUpdate)
	{
		ActionMetadata = EmptyTrack;
		ActionMetadata.VisualizeActor = none;
		ActionMetadata.StateObject_NewState = WorldDataUpdate;
		ActionMetadata.StateObject_OldState = WorldDataUpdate;

		//Wait until signaled by the shooter that the projectiles are hitting
		class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);

		for( i = 0; i < AbilityTemplate.AbilityMultiTargetEffects.Length; ++i )
		{
			AbilityTemplate.AbilityMultiTargetEffects[i].AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, 'AA_Success');	
		}

			}
	//****************************************************************************************

	//Process any interactions with interactive objects
	foreach VisualizeGameState.IterateByClassType(class'XComGameState_InteractiveObject', InteractiveObject)
	{
		// Add any doors that need to listen for notification
		if( InteractiveObject.IsDoor() && InteractiveObject.HasDestroyAnim() && InteractiveObject.InteractionCount % 2 != 0 ) //Is this a closed door?
		{
			ActionMetadata = EmptyTrack;
			//Don't necessarily have a previous state, so just use the one we know about
			ActionMetadata.StateObject_OldState = InteractiveObject;
			ActionMetadata.StateObject_NewState = InteractiveObject;
			ActionMetadata.VisualizeActor = History.GetVisualizer(InteractiveObject.ObjectID);
			class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
			class'X2Action_BreakInteractActor'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);

					}
	}

	TypicalAbility_AddEffectRedirects(VisualizeGameState, CyberusBuildTrack);
}

static function X2AbilityTemplate CreateImmunitiesAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_UnitPostBeginPlay Trigger;
	local X2Effect_DamageImmunity DamageImmunity;
	
	`CREATE_X2ABILITY_TEMPLATE(Template, 'CodexImmunities');
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_immunities";

	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityTargetStyle = default.SelfTarget;

	Trigger = new class'X2AbilityTrigger_UnitPostBeginPlay';
	Template.AbilityTriggers.AddItem(Trigger);

	// Build the immunities
	DamageImmunity = new class'X2Effect_DamageImmunity';
	DamageImmunity.BuildPersistentEffect(1, true, true, true);
	DamageImmunity.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage,,,Template.AbilitySourceName);
	DamageImmunity.ImmuneTypes.AddItem('Fire');
	DamageImmunity.ImmuneTypes.AddItem('Poison');
	DamageImmunity.ImmuneTypes.AddItem(class'X2Item_DefaultDamageTypes'.default.ParthenogenicPoisonType);
	DamageImmunity.ImmuneTypes.AddItem('Acid');
	DamageImmunity.ImmuneTypes.AddItem(class'X2Item_DefaultDamageTypes'.default.KnockbackDamageType);
	Template.AddTargetEffect(DamageImmunity);

	Template.AddTargetEffect(new class'X2Effect_ShouldCodexDropLoot');

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}

// #######################################################################################
// -------------------- MP Abilities -----------------------------------------------------
// #######################################################################################

static function X2DataTemplate CreateTeleportMPAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2AbilityCooldown_LocalAndGlobal Cooldown;
	local X2AbilityTarget_Cursor CursorTarget;
	local X2AbilityMultiTarget_Radius RadiusMultiTarget;
	local X2AbilityTrigger_PlayerInput InputTrigger;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'TeleportMP');

	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_AlwaysShow;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_codex_teleport";
	Template.MP_PerkOverride = 'Teleport';

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown_LocalAndGlobal';
	Cooldown.iNumTurns = default.TELEPORTMP_LOCAL_COOLDOWN;
	Cooldown.NumGlobalTurns = default.TELEPORT_GLOBAL_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.TargetingMethod = class'X2TargetingMethod_Teleport';

	InputTrigger = new class'X2AbilityTrigger_PlayerInput';
	Template.AbilityTriggers.AddItem(InputTrigger);

	Template.AbilityToHitCalc = default.DeadEye;

	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.bRestrictToSquadsightRange = true;
	//	CursorTarget.FixedAbilityRange = default.CYBERUS_TELEPORT_RANGE;     // yes there is.
	Template.AbilityTargetStyle = CursorTarget;

	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = 0.25; // small amount so it just grabs one tile
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	// Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	//// Damage Effect
	Template.AbilityMultiTargetConditions.AddItem(default.LivingTargetUnitOnlyProperty);
	//TeleportDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	//TeleportDamageEffect.EffectDamageValue = class'X2Item_DefaultWeapons'.default.CYBERUS_TELEPORT_BASEDAMAGE;
	//TeleportDamageEffect.EnvironmentalDamageAmount = default.TELEPORT_ENVIRONMENT_DAMAGE_AMOUNT;
	//TeleportDamageEffect.EffectDamageValue.DamageType = 'Melee';
	//Template.AddMultiTargetEffect(TeleportDamageEffect);

	Template.ModifyNewContextFn = Teleport_ModifyActivatedAbilityContext;
	Template.BuildNewGameStateFn = Teleport_BuildGameState;
	Template.BuildVisualizationFn = Teleport_BuildVisualization;
	Template.CinescriptCameraType = "Cyberus_Teleport";
//BEGIN AUTOGENERATED CODE: Template Overrides 'TeleportMP'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'TeleportMP'

	return Template;
}

static function X2AbilityTemplate CreateTriggerSuperpositionDamageListenerMPAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_EventListener EventListener;
	local X2Effect_RunBehaviorTree RetractBehaviorEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'TriggerSuperpositionDamageListenerMP');
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.MP_PerkOverride = 'TriggerSuperpositionDamageListener';

	Template.bDontDisplayInAbilitySummary = true;

	Template.AdditionalAbilities.AddItem('TriggerSuperposition');

	// This ability fires when the unit takes damage
	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventID = 'UnitTakeEffectDamage';
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_DamagedByEnemyTeleport;
	EventListener.ListenerData.Filter = eFilter_Unit;
	Template.AbilityTriggers.AddItem(EventListener);

	Template.AbilityTargetStyle = default.SelfTarget;

	RetractBehaviorEffect = new class'X2Effect_RunBehaviorTree';
	RetractBehaviorEffect.BehaviorTreeName = 'TryTriggerSuperposition';
	Template.AddTargetEffect(RetractBehaviorEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}

defaultproperties
{
	CyberusTemplateName="Cyberus"
	CyberusForcedDeadName="CyberusForcedDead"
	Stage1PsiBombEffectName="Stage1PsiBombEffect"
	PsiBombTriggerName="PsiBombTrigger"
	DamageTeleportDamageChainIndexName="DamageTeleportDamageChainIndexName"
	OriginalCyberusValueName="OriginalCyberusValue"
}
