class X2Ability_Andromedon extends X2Ability
	config(GameData_SoldierSkills);

var config WeaponDamageValue ANDROMEDONROBOT_MELEEATTACK_BASEDAMAGE;
var config float BIG_DAMN_PUNCH_RANGE;
var config int BIG_DAMN_PUNCH_MELEE_MODIFIER;
var config float BIG_DAMN_PUNCH_ENVIRONMENT_DAMAGE_RADIUS;
var config float BIG_DAMN_PUNCH_ENVIRONMENT_DAMAGE_AMOUNT;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateAcidBlobAbility());
	Templates.AddItem(CreateSwitchToRobotAbility());
	Templates.AddItem(CreateImmunitiesAbility());
	Templates.AddItem(CreateBigDamnPunchAbility());
	Templates.AddItem(PurePassive('RobotBattlesuit', "img:///UILibrary_PerkIcons.UIPerk_andromedon_robotbattlesuit"));
	Templates.AddItem(PurePassive('WallSmash', "img:///UILibrary_PerkIcons.UIPerk_andromedon_wallsmash"));
	//Templates.AddItem(PurePassive('ShellLauncher', "img:///UILibrary_PerkIcons.UIPerk_andromedon_shelllauncher"));

	// MP Versions of Abilities
	Templates.AddItem(CreateSwitchToRobotMPAbility());
	Templates.AddItem(CreateBigDamnPunchMPAbility());

	return Templates;
}

static function X2AbilityTemplate CreateAcidBlobAbility()
{
	local X2AbilityTemplate Template;	
	local X2AbilityCost_Ammo AmmoCost;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2Effect_ApplyWeaponDamage WeaponEffect;
	local X2AbilityTarget_Cursor CursorTarget;
	local X2AbilityMultiTarget_Radius RadiusMultiTarget;
	local X2Condition_UnitProperty UnitPropertyCondition;
	local X2AbilityTrigger_PlayerInput InputTrigger;
	local X2AbilityCooldown Cooldown;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'AcidBlob');
	Template.bDontDisplayInAbilitySummary = false;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_andromedon_acidblob"; // TODO: This needs to be changed

	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_AlwaysShow;
	Template.bUseAmmoAsChargesForHUD = false;

	Template.TargetingMethod = class'X2TargetingMethod_Grenade';

	// Cooldown on the ability
	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = 3;
	Template.AbilityCooldown = Cooldown;
	
	AmmoCost = new class'X2AbilityCost_Ammo';
	AmmoCost.iAmmo = 1;
	Template.AbilityCosts.AddItem(AmmoCost);
	
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);
	
	Template.AbilityToHitCalc = default.DeadEye;
	
	WeaponEffect = new class'X2Effect_ApplyWeaponDamage';
	WeaponEffect.DamageTypes.AddItem('Acid');
	Template.AddMultiTargetEffect(WeaponEffect);
	Template.AddMultiTargetEffect(new class'X2Effect_ApplyAcidToWorld');
	Template.AddMultiTargetEffect(class'X2StatusEffects'.static.CreateAcidBurningStatusEffect(2, 1));
	
	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.bRestrictToWeaponRange = true;
	Template.AbilityTargetStyle = CursorTarget;

	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.bUseWeaponRadius = true;
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	Template.AbilityShooterConditions.AddItem(UnitPropertyCondition);

	InputTrigger = new class'X2AbilityTrigger_PlayerInput';
	Template.AbilityTriggers.AddItem(InputTrigger);

	Template.CustomFireAnim = 'FF_AcidBlob';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Andromedon_AcidBlob";

	// This action is considered 'hostile' and can be interrupted!
	Template.Hostility = eHostility_Offensive;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;

	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'AcidBlob'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'AcidBlob'

	return Template;
}

static function X2AbilityTemplate CreateSwitchToRobotAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_EventListener EventListener;
	local X2Condition_UnitValue UnitValue;
	local X2Effect_SetUnitValue SetUnitValEffect;
	local X2Effect_SwitchToRobot SwitchToRobotEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'SwitchToRobot');
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_andromedon_robotbattlesuit"; // TODO: This needs to be changed

	Template.bDontDisplayInAbilitySummary = true;
	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;	

	// This ability is only valid if there has not been another death explosion on the unit
	UnitValue = new class'X2Condition_UnitValue';
	UnitValue.AddCheckValue('InRobotMode', 1, eCheck_LessThan);
	Template.AbilityShooterConditions.AddItem(UnitValue);

	// This ability fires when the Andromedon dies
	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventID = 'UnitDied';
	EventListener.ListenerData.Filter = eFilter_Unit;
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_Self_VisualizeInGameState;
	EventListener.ListenerData.Priority = 45; //This ability must get triggered after the rest of the on-death listeners (namely, after mind-control effects get removed)
	Template.AbilityTriggers.AddItem(EventListener);

	// Targets the Andromedon unit so it can be replaced by the andromedon robot;
	Template.AbilityTargetStyle = default.SelfTarget;

	// Add dead eye to guarantee the explosion occurs
	Template.AbilityToHitCalc = default.DeadEye;

	// The target will now be turned into a robot
	SwitchToRobotEffect = new class'X2Effect_SwitchToRobot';
	SwitchToRobotEffect.BuildPersistentEffect(1);
	Template.AddTargetEffect(SwitchToRobotEffect);

	// Once this ability is fired, set the InRobotMode Unit Value so it will not happen again
	SetUnitValEffect = new class'X2Effect_SetUnitValue';
	SetUnitValEffect.UnitName = 'InRobotMode';
	SetUnitValEffect.NewValueToSet = 1;
	SetUnitValEffect.CleanupType = eCleanup_Never;
	Template.AddTargetEffect(SetUnitValEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = SwitchToRobot_BuildVisualization;
	Template.MergeVisualizationFn = SwitchToRobot_VisualizationMerge;
//BEGIN AUTOGENERATED CODE: Template Overrides 'SwitchToRobot'
	Template.FrameAbilityCameraType = eCameraFraming_Never;
//END AUTOGENERATED CODE: Template Overrides 'SwitchToRobot'

	return Template;
}

simulated function SwitchToRobot_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateContext_Ability Context;
	local XComGameStateHistory History;
	local VisualizationActionMetadata EmptyTrack, SpawnedUnitTrack, DeadUnitTrack;
	local XComGameState_Unit SpawnedUnit, DeadUnit;
	local UnitValue SpawnedUnitValue;
	local X2Effect_SwitchToRobot SwitchToRobotEffect;
	local XComGameState_Ability AbilityState;
	local X2AbilityTemplate AbilityTemplate;

	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	History = `XCOMHISTORY;

	DeadUnit = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(Context.InputContext.PrimaryTarget.ObjectID));
	`assert(DeadUnit != none);

	DeadUnit.GetUnitValue(class'X2Effect_SpawnUnit'.default.SpawnedUnitValueName, SpawnedUnitValue);

	// The Spawned unit should appear and play its change animation
	DeadUnitTrack = EmptyTrack;
	DeadUnitTrack.StateObject_OldState = DeadUnit;
	DeadUnitTrack.StateObject_NewState = DeadUnitTrack.StateObject_OldState;
	DeadUnitTrack.VisualizeActor = History.GetVisualizer(DeadUnit.ObjectID);

	// The Spawned unit should appear and play its change animation
	SpawnedUnitTrack = EmptyTrack;
	SpawnedUnitTrack.StateObject_OldState = History.GetGameStateForObjectID(SpawnedUnitValue.fValue, eReturnType_Reference, VisualizeGameState.HistoryIndex);
	SpawnedUnitTrack.StateObject_NewState = SpawnedUnitTrack.StateObject_OldState;
	SpawnedUnit = XComGameState_Unit(SpawnedUnitTrack.StateObject_NewState);
	`assert(SpawnedUnit != none);
	SpawnedUnitTrack.VisualizeActor = History.GetVisualizer(SpawnedUnit.ObjectID);

	// Only first target effect is X2Effect_SwitchToRobot
	SwitchToRobotEffect = X2Effect_SwitchToRobot(Context.ResultContext.TargetEffectResults.Effects[0]);

	if( SwitchToRobotEffect == none )
	{
		// This can happen due to replays. In replays, when moving Context visualizations forward the Context has not
		// been fully filled in.
		AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(Context.InputContext.AbilityRef.ObjectID));
		AbilityTemplate = AbilityState.GetMyTemplate();
		SwitchToRobotEffect = X2Effect_SwitchToRobot(AbilityTemplate.AbilityTargetEffects[0]);
	}

	if( SwitchToRobotEffect == none )
	{
		`RedScreenOnce("SwitchToRobot_BuildVisualization: Missing X2Effect_SwitchToRobot -dslonneger @gameplay");
	}
	else
	{
		SwitchToRobotEffect.AddSpawnVisualizationsToTracks(Context, SpawnedUnit, SpawnedUnitTrack, DeadUnit, DeadUnitTrack);
	}
}

static function SwitchToRobot_VisualizationMerge(X2Action BuildTree, out X2Action VisualizationTree)
{
	local X2Action DeathAction;		
	local X2Action BuildTreeStartNode, BuildTreeEndNode;	
	local XComGameStateVisualizationMgr LocalVisualizationMgr;

	LocalVisualizationMgr = `XCOMVISUALIZATIONMGR;

	DeathAction = LocalVisualizationMgr.GetNodeOfType(VisualizationTree, class'X2Action_AndromedonDeathAction', none, BuildTree.Metadata.StateObjectRef.ObjectID);
	if (DeathAction == none)
	{
		//Fall back to regular death action if we need to
		DeathAction = LocalVisualizationMgr.GetNodeOfType(VisualizationTree, class'X2Action_Death', none, BuildTree.Metadata.StateObjectRef.ObjectID);
	}
	BuildTreeStartNode = LocalVisualizationMgr.GetNodeOfType(BuildTree, class'X2Action_MarkerTreeInsertBegin');	
	BuildTreeEndNode = LocalVisualizationMgr.GetNodeOfType(BuildTree, class'X2Action_MarkerTreeInsertEnd');	
	LocalVisualizationMgr.InsertSubtree(BuildTreeStartNode, BuildTreeEndNode, DeathAction);
}

static function X2AbilityTemplate CreateImmunitiesAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_UnitPostBeginPlay Trigger;
	local X2Effect_DamageImmunity DamageImmunity;
	local X2Effect_OverrideDeathAction DeathActionEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'AndromedonImmunities');
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_absorption_fields"; // TODO: This needs to be changed

	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityTargetStyle = default.SelfTarget;

	Trigger = new class'X2AbilityTrigger_UnitPostBeginPlay';
	Template.AbilityTriggers.AddItem(Trigger);

	// Build the immunities
	DamageImmunity = new class'X2Effect_DamageImmunity';
	DamageImmunity.BuildPersistentEffect(1, true, false, true);
	DamageImmunity.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage,,,Template.AbilitySourceName);
	DamageImmunity.ImmuneTypes.AddItem('Fire');
	DamageImmunity.ImmuneTypes.AddItem('Poison');
	DamageImmunity.ImmuneTypes.AddItem('Acid');
	DamageImmunity.ImmuneTypes.AddItem(class'X2Item_DefaultDamageTypes'.default.KnockbackDamageType);
	DamageImmunity.ImmuneTypes.AddItem(class'X2Item_DefaultDamageTypes'.default.ParthenogenicPoisonType);

	Template.AddTargetEffect(DamageImmunity);

	DeathActionEffect = new class'X2Effect_OverrideDeathAction';
	DeathActionEffect.BuildPersistentEffect(1, true, false, true);
	DeathActionEffect.DeathActionClass = class'X2Action_AndromedonDeathAction';
	DeathActionEffect.EffectName = 'AndromedonDeathOverride';
	DeathActionEffect.bPersistThroughTacticalGameEnd = true;
	Template.AddTargetEffect(DeathActionEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}

static function X2DataTemplate CreateBigDamnPunchAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2AbilityToHitCalc_StandardMelee MeleeHitCalc;
	local X2Condition_UnitProperty UnitPropertyCondition;
	local X2Effect_ApplyWeaponDamage PhysicalDamageEffect;
	local X2AbilityMultiTarget_Radius RadiusMultiTarget;
	local X2Effect_Knockback KnockbackEffect;
	local X2AbilityTarget_MovingMelee MeleeTarget;
	local array<name> SkipExclusions;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'BigDamnPunch');
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_muton_punch"; // TODO: Change this icon

	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.Hostility = eHostility_Offensive;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	MeleeTarget = new class'X2AbilityTarget_MovingMelee';
	MeleeTarget.MovementRangeAdjustment = 1;
	Template.AbilityTargetStyle = MeleeTarget;

	Template.TargetingMethod = class'X2TargetingMethod_MeleePath';

	MeleeHitCalc = new class'X2AbilityToHitCalc_StandardMelee';
	MeleeHitCalc.BuiltInHitMod = default.BIG_DAMN_PUNCH_MELEE_MODIFIER;
	Template.AbilityToHitCalc = MeleeHitCalc;

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	Template.AbilityShooterConditions.AddItem(UnitPropertyCondition);
	
	// Punch may be used if disoriented
	SkipExclusions.AddItem(class'X2AbilityTemplateManager'.default.DisorientedName);
	Template.AddShooterEffectExclusions(SkipExclusions);

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.RequireWithinRange = true;
	UnitPropertyCondition.WithinRange = default.BIG_DAMN_PUNCH_RANGE;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);
	
	Template.AbilityTargetConditions.AddItem(default.MeleeVisibilityCondition);

	PhysicalDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	PhysicalDamageEffect.EffectDamageValue = class'X2Item_DefaultWeapons'.default.ANDROMEDONROBOT_MELEEATTACK_BASEDAMAGE;
	PhysicalDamageEffect.EffectDamageValue.DamageType = 'Melee';
	// This also deals environmental damage
	PhysicalDamageEffect.EnvironmentalDamageAmount = default.BIG_DAMN_PUNCH_ENVIRONMENT_DAMAGE_AMOUNT;
	Template.AddTargetEffect(PhysicalDamageEffect);

	KnockbackEffect = new class'X2Effect_Knockback';
	KnockbackEffect.KnockbackDistance = 5; //Knockback 5 meters
	KnockbackEffect.OnlyOnDeath = false;
	Template.AddTargetEffect(KnockbackEffect);

	// Radius target for the world damage
	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = default.BIG_DAMN_PUNCH_ENVIRONMENT_DAMAGE_RADIUS;
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	Template.AbilityTriggers.AddItem(new class'X2AbilityTrigger_PlayerInput');
	Template.AbilityTriggers.AddItem(new class'X2AbilityTrigger_EndOfMove');

	Template.CustomFireAnim = 'FF_Melee';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Andromedon_FistStrike";
	Template.bOverrideMeleeDeath = true;

	// This action is considered 'hostile' and can be interrupted!
	Template.Hostility = eHostility_Offensive;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
//BEGIN AUTOGENERATED CODE: Template Overrides 'BigDamnPunch'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'BigDamnPunch'
	
	return Template;
}

// #######################################################################################
// -------------------- MP Abilities -----------------------------------------------------
// #######################################################################################

static function X2AbilityTemplate CreateSwitchToRobotMPAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_EventListener EventListener;
	local X2Condition_UnitValue UnitValue;
	local X2Effect_SetUnitValue SetUnitValEffect;
	local X2Effect_SwitchToRobot SwitchToRobotEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'SwitchToRobotMP');
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_andromedon_robotbattlesuit"; // TODO: This needs to be changed
	Template.MP_PerkOverride = 'SwitchToRobot';

	Template.bDontDisplayInAbilitySummary = true;
	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	// This ability is only valid if there has not been another death explosion on the unit
	UnitValue = new class'X2Condition_UnitValue';
	UnitValue.AddCheckValue('InRobotMode', 1, eCheck_LessThan);
	Template.AbilityShooterConditions.AddItem(UnitValue);

	// This ability fires when the Andromedon dies
	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventID = 'UnitDied';
	EventListener.ListenerData.Filter = eFilter_Unit;
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_Self_VisualizeInGameState;
	EventListener.ListenerData.Priority = 45; //This ability must get triggered after the rest of the on-death listeners (namely, after mind-control effects get removed)
	Template.AbilityTriggers.AddItem(EventListener);

	// Targets the Andromedon unit so it can be replaced by the andromedon robot;
	Template.AbilityTargetStyle = default.SelfTarget;

	// Add dead eye to guarantee the explosion occurs
	Template.AbilityToHitCalc = default.DeadEye;

	// The target will now be turned into a robot
	SwitchToRobotEffect = new class'X2Effect_SwitchToRobot';
	SwitchToRobotEffect.UnitToSpawnName = 'AndromedonRobotMP';
	SwitchToRobotEffect.BuildPersistentEffect(1);
	Template.AddTargetEffect(SwitchToRobotEffect);

	// Once this ability is fired, set the InRobotMode Unit Value so it will not happen again
	SetUnitValEffect = new class'X2Effect_SetUnitValue';
	SetUnitValEffect.UnitName = 'InRobotMode';
	SetUnitValEffect.NewValueToSet = 1;
	SetUnitValEffect.CleanupType = eCleanup_Never;
	Template.AddTargetEffect(SetUnitValEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = SwitchToRobot_BuildVisualization;
	//Template.MergeVisualizationFn = SwitchToRobot_VisualizationActionMetadataInsert;

	return Template;
}

// For the robot
static function X2DataTemplate CreateBigDamnPunchMPAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2AbilityToHitCalc_StandardMelee MeleeHitCalc;
	local X2Condition_UnitProperty UnitPropertyCondition;
	local X2Effect_ApplyWeaponDamage PhysicalDamageEffect;
	local X2AbilityMultiTarget_Radius RadiusMultiTarget;
	//local X2Effect_Knockback KnockbackEffect;
	local X2AbilityTarget_MovingMelee MeleeTarget;
	local array<name> SkipExclusions;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'BigDamnPunchMP');
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_muton_punch"; // TODO: Change this icon
	Template.MP_PerkOverride = 'BigDamnPunch';

	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.Hostility = eHostility_Offensive;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	MeleeTarget = new class'X2AbilityTarget_MovingMelee';
	Template.AbilityTargetStyle = MeleeTarget;

	Template.TargetingMethod = class'X2TargetingMethod_MeleePath';

	MeleeHitCalc = new class'X2AbilityToHitCalc_StandardMelee';
	MeleeHitCalc.BuiltInHitMod = default.BIG_DAMN_PUNCH_MELEE_MODIFIER;
	Template.AbilityToHitCalc = MeleeHitCalc;

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	Template.AbilityShooterConditions.AddItem(UnitPropertyCondition);
	
	// Punch may be used if disoriented
	SkipExclusions.AddItem(class'X2AbilityTemplateManager'.default.DisorientedName);
	Template.AddShooterEffectExclusions(SkipExclusions);

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);

	Template.AbilityTargetConditions.AddItem(default.MeleeVisibilityCondition);

	PhysicalDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	PhysicalDamageEffect.EffectDamageValue = class'X2Item_DefaultWeapons'.default.ANDROMEDONROBOTMP_MELEEATTACK_BASEDAMAGE;
	PhysicalDamageEffect.EffectDamageValue.DamageType = 'Melee';
	// This also deals environmental damage
	PhysicalDamageEffect.EnvironmentalDamageAmount = default.BIG_DAMN_PUNCH_ENVIRONMENT_DAMAGE_AMOUNT;
	Template.AddTargetEffect(PhysicalDamageEffect);

	//KnockbackEffect = new class'X2Effect_Knockback';
	//KnockbackEffect.KnockbackDistance = 5; //Knockback 5 meters
	//Template.AddTargetEffect(KnockbackEffect);

	// Radius target for the world damage
	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = default.BIG_DAMN_PUNCH_ENVIRONMENT_DAMAGE_RADIUS;
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	Template.AbilityTriggers.AddItem(new class'X2AbilityTrigger_PlayerInput');
	Template.AbilityTriggers.AddItem(new class'X2AbilityTrigger_EndOfMove');

	Template.CustomFireAnim = 'FF_Melee';
	Template.BuildNewGameStateFn = TypicalMoveEndAbility_BuildGameState;
	Template.BuildInterruptGameStateFn = TypicalMoveEndAbility_BuildInterruptGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Andromedon_FistStrike";
	Template.bOverrideMeleeDeath = true;

	// This action is considered 'hostile' and can be interrupted!
	Template.Hostility = eHostility_Offensive;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
//BEGIN AUTOGENERATED CODE: Template Overrides 'BigDamnPunchMP'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'BigDamnPunchMP'

	return Template;
}
