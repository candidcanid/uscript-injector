class X2Ability_PsiOperativeAbilitySet extends X2Ability config(GameData_SoldierSkills);

var config int SOULFIRE_COOLDOWN;
var config int STASIS_COOLDOWN;
var config int INSANITY_COOLDOWN;
var config int INSPIRE_COOLDOWN;
var config float SOULSTEAL_MULTIPLIER;
var config float SOLACE_DISTANCE_SQ;
var config WeaponDamageValue SCHISM_DMG;
var config int DOMINATION_COOLDOWN;
var config int NULL_LANCE_COOLDOWN_PLAYER;
var config int NULL_LANCE_COOLDOWN_AI;
var config int NULL_LANCE_GLOBAL_COOLDOWN_AI;
var config int VOID_RIFT_COOLDOWN;
var config int VOID_RIFT_RADIUS;
var config int VOID_RIFT_RANGE;
var config int VOID_RIFT_INSANITY_CHANCE;
var config float VOID_RIFT_INSANITY_FX_VISUALIZATION_DELAY;
var config int PSI_OP_MIND_CONTROL_COOLDOWN_PLAYER;
var config int PSI_OP_MIND_CONTROL_LASTS_NUMBER_TURNS;

var privatewrite name FuseEventName;
var privatewrite name FusePostEventName;
var privatewrite name SoulStealEventName;
var privatewrite name SoulStealUnitValue;
var privatewrite name VoidRiftInsanityEventName;
var privatewrite name EndVoidRiftDurationFXEventName;
var privatewrite name VoidRiftDurationFXEffectName;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Soulfire());
	Templates.AddItem(Stasis());
	Templates.AddItem(Insanity());
	Templates.AddItem(Inspire());
	Templates.AddItem(SoulSteal());
	Templates.AddItem(SoulStealTriggered());
	Templates.AddItem(StasisShield());
	Templates.AddItem(Solace());
	Templates.AddItem(SolacePassive());
	Templates.AddItem(SolaceCleanse('SolaceCleanse', "img:///UILibrary_PerkIcons.UIPerk_solace", Sqrt(class'X2Ability_PsiOperativeAbilitySet'.default.SOLACE_DISTANCE_SQ)));
	Templates.AddItem(Sustain());
	Templates.AddItem(SustainTriggered());
	Templates.AddItem(Schism());
	Templates.AddItem(Fortress());
	Templates.AddItem(Fuse());
	Templates.AddItem(FusePostActivationConcealmentBreaker());
	Templates.AddItem(Domination());		
	Templates.AddItem(NullLance());
	Templates.AddItem(VoidRift());	
	Templates.AddItem(VoidRiftInsanity());
	Templates.AddItem(VoidRiftEndDurationFX());
	Templates.AddItem(PsiOperativeMindControlAbility());
	
	return Templates;
}

static function X2AbilityTemplate Soulfire()
{
	local X2AbilityTemplate                 Template;
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2Condition_UnitProperty          TargetProperty;
	local X2Effect_ApplyWeaponDamage        WeaponDamageEffect;
	local X2AbilityCooldown                 Cooldown;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Soulfire');

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_SQUADDIE_PRIORITY;

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.SOULFIRE_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	TargetProperty = new class'X2Condition_UnitProperty';
	TargetProperty.ExcludeRobotic = true;
	TargetProperty.FailOnNonUnits = true;
	TargetProperty.TreatMindControlledSquadmateAsHostile = true;
	Template.AbilityTargetConditions.AddItem(TargetProperty);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	WeaponDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	WeaponDamageEffect.bIgnoreBaseDamage = true;
	WeaponDamageEffect.DamageTag = 'Soulfire';
	WeaponDamageEffect.bBypassShields = true;
	WeaponDamageEffect.bIgnoreArmor = true;
	Template.AddTargetEffect(WeaponDamageEffect);

	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.Hostility = eHostility_Offensive;

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_soulfire";
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.bShowActivation = false;
	Template.CustomFireAnim = 'HL_Psi_ProjectileMedium';

	Template.ActivationSpeech = 'Mindblast';

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";
	Template.PostActivationEvents.AddItem(default.SoulStealEventName);

	Template.AssociatedPassives.AddItem('SoulSteal');

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'Soulfire'
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'Soulfire'

	return Template;
}

static function X2DataTemplate Stasis( Name TemplateName='Stasis' )
{
	local X2AbilityTemplate                 Template;
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2Effect_Stasis                   StasisEffect;
	local X2AbilityCooldown                 Cooldown;
	local X2Effect_RemoveEffects            RemoveEffects;

	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);

	Template.Hostility = eHostility_Offensive;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_stasis";
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	Template.AbilityCosts.AddItem(ActionPointCost);
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_SQUADDIE_PRIORITY;

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.STASIS_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	Template.AbilityTargetConditions.AddItem(new class'X2Condition_StasisTarget');
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	RemoveEffects = new class'X2Effect_RemoveEffects';
	RemoveEffects.EffectNamesToRemove.AddItem(class'X2Ability_Viper'.default.BindSustainedEffectName);
	Template.AddTargetEffect(RemoveEffects);

	StasisEffect = new class'X2Effect_Stasis';
	StasisEffect.BuildPersistentEffect(1, false, false, false, eGameRule_PlayerTurnBegin);
	StasisEffect.bUseSourcePlayerState = true;
	StasisEffect.bRemoveWhenTargetDies = true;          //  probably shouldn't be possible for them to die while in stasis, but just in case
	StasisEffect.SetDisplayInfo(ePerkBuff_Penalty, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage);
	Template.AddTargetEffect(StasisEffect);

	Template.AbilityTargetStyle = default.SingleTargetWithSelf;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
		
	Template.bShowActivation = true;
	Template.CustomFireAnim = 'HL_Psi_SelfCast';
	Template.ActivationSpeech = 'NullShield';

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = Stasis_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'Stasis'
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'Stasis'

	return Template;
}

function Stasis_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local XComGameState_Effect RemovedEffect;
	local VisualizationActionMetadata ActionMetadata, EmptyTrack;

	TypicalAbility_BuildVisualization(VisualizeGameState);
	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Effect', RemovedEffect)
	{
		if (RemovedEffect.bRemoved)
		{
			ActionMetadata = EmptyTrack;
			ActionMetadata.VisualizeActor = History.GetVisualizer(RemovedEffect.ApplyEffectParameters.SourceStateObjectRef.ObjectID);
			ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(RemovedEffect.ApplyEffectParameters.SourceStateObjectRef.ObjectID, , VisualizeGameState.HistoryIndex -1);
			ActionMetadata.StateObject_NewState = History.GetGameStateForObjectID(RemovedEffect.ApplyEffectParameters.SourceStateObjectRef.ObjectID);

			RemovedEffect.GetX2Effect().AddX2ActionsForVisualization_RemovedSource(VisualizeGameState, ActionMetadata, 'AA_Success', RemovedEffect);
		}
	}
}

static function X2AbilityTemplate SoulSteal()
{
	local X2AbilityTemplate         Template;

	Template = PurePassive('SoulSteal', "img:///UILibrary_PerkIcons.UIPerk_soulsteal", false, 'eAbilitySource_Psionic');
	Template.PrerequisiteAbilities.AddItem('Soulfire');
	Template.AdditionalAbilities.AddItem('SoulStealTriggered');

	return Template;
}

static function X2AbilityTemplate SoulStealTriggered()
{
	local X2AbilityTemplate                 Template;
	local X2AbilityTrigger_EventListener    EventListener;
	local X2Condition_UnitProperty          ShooterProperty;
	local X2Effect_SoulSteal                StealEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'SoulStealTriggered');

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_soulsteal";
	Template.Hostility = eHostility_Neutral;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';

	ShooterProperty = new class'X2Condition_UnitProperty';
	ShooterProperty.ExcludeAlive = false;
	ShooterProperty.ExcludeDead = true;
	ShooterProperty.ExcludeFriendlyToSource = false;
	ShooterProperty.ExcludeHostileToSource = true;
	ShooterProperty.ExcludeFullHealth = true;
	Template.AbilityShooterConditions.AddItem(ShooterProperty);

	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.SoulStealListener;
	EventListener.ListenerData.EventID = default.SoulStealEventName;
	EventListener.ListenerData.Filter = eFilter_Unit;
	Template.AbilityTriggers.AddItem(EventListener);

	StealEffect = new class'X2Effect_SoulSteal';
	StealEffect.UnitValueToRead = default.SoulStealUnitValue;
	Template.AddShooterEffect(StealEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.FrameAbilityCameraType = eCameraFraming_Never;
	Template.bShowActivation = true;
	Template.bSkipExitCoverWhenFiring = true;
	Template.bSkipFireAction = true;
// 	Template.CustomFireAnim = 'ADD_NO_Psi_CastAdditive';
// 	Template.ActionFireClass = class'X2Action_Fire_AdditiveAnim';

	return Template;
}

static function X2AbilityTemplate StasisShield()
{
	local X2AbilityTemplate         Template;

	Template = PurePassive('StasisShield', "img:///UILibrary_PerkIcons.UIPerk_stasisshield", false, 'eAbilitySource_Psionic');
	Template.PrerequisiteAbilities.AddItem('Stasis');

	return Template;
}

static function X2AbilityTemplate Solace()
{
	local X2AbilityTemplate             Template;
	local X2Effect_Solace               Effect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Solace');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_solace";
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	Template.AbilityMultiTargetStyle = new class'X2AbilityMultiTarget_AllAllies';

	Effect = new class'X2Effect_Solace';
	Effect.BuildPersistentEffect(1, true, false);
	Effect.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,, Template.AbilitySourceName);
	Template.AddMultiTargetEffect(Effect);

	Template.AdditionalAbilities.AddItem('SolaceCleanse');
	Template.AdditionalAbilities.AddItem('SolacePassive');

	Template.bSkipFireAction = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

static function X2AbilityTemplate SolacePassive()
{
	return PurePassive('SolacePassive', "img:///UILibrary_PerkIcons.UIPerk_solace", , 'eAbilitySource_Psionic');
}

static function X2AbilityTemplate SolaceCleanse(name TemplateName,
												string TemplateIconImage,
												float TileRange)
{
	local X2AbilityTemplate                     Template;
	local X2AbilityTrigger_EventListener        EventListener;
	local X2Condition_UnitProperty              DistanceCondition;
	local X2Effect_RemoveEffects                MentalEffectRemovalEffect;
	local X2Effect_RemoveEffects                MindControlRemovalEffect;
	local X2Condition_UnitProperty              EnemyCondition;
	local X2Condition_UnitProperty              FriendCondition;


	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);

	Template.IconImage = TemplateIconImage;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);

	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventID = 'UnitMoveFinished';
	EventListener.ListenerData.Filter = eFilter_None;
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.SolaceCleanseListener;
	Template.AbilityTriggers.AddItem(EventListener);

	//Naming confusion: CreateMindControlRemoveEffects removes everything _except_ mind control, and is used when mind-controlling an enemy.
	//We want to remove all those other status effects on friendly units; we want to remove mind-control itself from enemy units.
	//(Enemy units with mind-control will be back on our team once it's removed.)
	MentalEffectRemovalEffect = class'X2StatusEffects'.static.CreateMindControlRemoveEffects();
	MentalEffectRemovalEffect.DamageTypes.Length = 0;		//	don't let an immunity to "mental" effects resist this cleanse
	FriendCondition = new class'X2Condition_UnitProperty';
	FriendCondition.ExcludeFriendlyToSource = false;
	FriendCondition.ExcludeHostileToSource = true;
	MentalEffectRemovalEffect.TargetConditions.AddItem(FriendCondition);
	Template.AddTargetEffect(MentalEffectRemovalEffect);

	MindControlRemovalEffect = new class'X2Effect_RemoveEffects';
	MindControlRemovalEffect.EffectNamesToRemove.AddItem(class'X2Effect_MindControl'.default.EffectName);
	EnemyCondition = new class'X2Condition_UnitProperty';
	EnemyCondition.ExcludeFriendlyToSource = true;
	EnemyCondition.ExcludeHostileToSource = false;
	MindControlRemovalEffect.TargetConditions.AddItem(EnemyCondition);
	Template.AddTargetEffect(MindControlRemovalEffect);


	DistanceCondition = new class'X2Condition_UnitProperty';
	DistanceCondition.RequireWithinRange = true;
	DistanceCondition.WithinRange = TileRange * class'XComWorldData'.const.WORLD_StepSize;
	DistanceCondition.ExcludeFriendlyToSource = false;
	DistanceCondition.ExcludeHostileToSource = false;
	Template.AbilityTargetConditions.AddItem(DistanceCondition);

	Template.bSkipFireAction = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

static function X2AbilityTemplate Sustain()
{
	local X2AbilityTemplate             Template;
	local X2Effect_Sustain              SustainEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Sustain');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_sustain";
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.bIsPassive = true;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	SustainEffect = new class'X2Effect_Sustain';
	SustainEffect.BuildPersistentEffect(1, true, true);
	SustainEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,, Template.AbilitySourceName);
	Template.AddTargetEffect(SustainEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	// Note: no visualization on purpose!

	Template.AdditionalAbilities.AddItem('SustainTriggered');

	return Template;
}

static function X2DataTemplate SustainTriggered()
{
	local X2AbilityTemplate                 Template;
	local X2Effect_Stasis                   StasisEffect;
	local X2AbilityTrigger_EventListener    EventTrigger;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'SustainTriggered');

	Template.Hostility = eHostility_Neutral;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_sustain";
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	//	check that the unit is still alive.
	//	it's possible that multiple event listeners responded to the same event, and some of those other listeners
	//	went ahead and killed the unit before we got to trigger sustain.
	//	it would look weird to do the sustain visualization and then have the unit die, so just don't trigger sustain.
	//	e.g. a unit with a homing mine on it that takes a kill shot wants to have the death stopped, but the
	//	homing mine explosion can trigger before the sustain trigger goes off, killing the unit before it would be sustained
	//	and making things look really weird. now the unit will just die without "sustaining" the corpse.
	//	-jbouscher
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);

	StasisEffect = new class'X2Effect_Stasis';
	StasisEffect.BuildPersistentEffect(1, false, false, false, eGameRule_PlayerTurnBegin);
	StasisEffect.bUseSourcePlayerState = true;
	StasisEffect.bRemoveWhenTargetDies = true;          //  probably shouldn't be possible for them to die while in stasis, but just in case
	StasisEffect.SetDisplayInfo(ePerkBuff_Penalty, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage);
	StasisEffect.StunStartAnim = 'HL_PsiSustainStart';
	StasisEffect.bSkipFlyover = true;
	Template.AddTargetEffect(StasisEffect);

	EventTrigger = new class'X2AbilityTrigger_EventListener';
	EventTrigger.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventTrigger.ListenerData.EventID = class'X2Effect_Sustain'.default.SustainEvent;
	EventTrigger.ListenerData.Filter = eFilter_Unit;
	EventTrigger.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_Self;
	Template.AbilityTriggers.AddItem(EventTrigger);

	Template.PostActivationEvents.AddItem(class'X2Effect_Sustain'.default.SustainTriggeredEvent);
		
	Template.bSkipFireAction = true;
	Template.FrameAbilityCameraType = eCameraFraming_Never;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

static function X2AbilityTemplate Insanity()
{
	local X2AbilityTemplate             Template;
	local X2AbilityCost_ActionPoints    ActionPointCost;
	local X2Condition_UnitProperty      UnitPropertyCondition;
	local X2Condition_UnitImmunities	UnitImmunityCondition;
	local X2Effect_PersistentStatChange DisorientedEffect;
	local X2Effect_MindControl          MindControlEffect;
	local X2Effect_RemoveEffects        MindControlRemoveEffects;
	local X2Effect_Panicked             PanicEffect;
	local X2AbilityCooldown             Cooldown;
	local X2Effect_ApplyWeaponDamage    RuptureEffect;
	local X2Condition_AbilityProperty   SchismCondition;
	local X2AbilityToHitCalc_StatCheck_UnitVsUnit StatCheck;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Insanity');

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.INSANITY_COOLDOWN;
	Template.AbilityCooldown = Cooldown;
	
	StatCheck = new class'X2AbilityToHitCalc_StatCheck_UnitVsUnit';
	StatCheck.BaseValue = 50;
	Template.AbilityToHitCalc = StatCheck;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.FailOnNonUnits = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);	
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	UnitImmunityCondition = new class'X2Condition_UnitImmunities';
	UnitImmunityCondition.AddExcludeDamageType('Mental');
	UnitImmunityCondition.bOnlyOnCharacterTemplate = true;
	Template.AbilityTargetConditions.AddItem(UnitImmunityCondition);

	//  Disorient effect for 1 unblocked psi hit
	DisorientedEffect = class'X2StatusEffects'.static.CreateDisorientedStatusEffect();
	DisorientedEffect.iNumTurns = 2;
	DisorientedEffect.MinStatContestResult = 1;
	DisorientedEffect.MaxStatContestResult = 1;     
	DisorientedEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(DisorientedEffect);

	//  Longer Disorient effect for 2 unblocked psi hits
	DisorientedEffect = class'X2StatusEffects'.static.CreateDisorientedStatusEffect();
	DisorientedEffect.iNumTurns = 3;
	DisorientedEffect.MinStatContestResult = 2;
	DisorientedEffect.MaxStatContestResult = 2;     
	DisorientedEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(DisorientedEffect);
	
	//  Panic effect for 3-4 unblocked psi hits
	PanicEffect = class'X2StatusEffects'.static.CreatePanickedStatusEffect();
	PanicEffect.MinStatContestResult = 3;
	PanicEffect.MaxStatContestResult = 4;
	PanicEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(PanicEffect);

	//  Mind control effect for 5+ unblocked psi hits
	MindControlEffect = class'X2StatusEffects'.static.CreateMindControlStatusEffect(1, false, false);
	MindControlEffect.MinStatContestResult = 5;
	MindControlEffect.MaxStatContestResult = 0;
	MindControlEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(MindControlEffect);

	MindControlRemoveEffects = class'X2StatusEffects'.static.CreateMindControlRemoveEffects();
	MindControlRemoveEffects.MinStatContestResult = 5;
	MindControlRemoveEffects.MaxStatContestResult = 0;
	Template.AddTargetEffect(MindControlRemoveEffects);

	//  Rupture effect if the caster has Schism
	RuptureEffect = new class'X2Effect_ApplyWeaponDamage';
	RuptureEffect.EffectDamageValue = default.SCHISM_DMG;
	RuptureEffect.MinStatContestResult = 1;
	RuptureEffect.MaxStatContestResult = 0;
	RuptureEffect.bIgnoreArmor = true;
	SchismCondition = new class'X2Condition_AbilityProperty';
	SchismCondition.OwnerHasSoldierAbilities.AddItem('Schism');
	RuptureEffect.TargetConditions.AddItem(SchismCondition);
	Template.AddTargetEffect(RuptureEffect);

	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	Template.CustomFireAnim = 'HL_Psi_MindControl';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";

	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_insanity";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_CORPORAL_PRIORITY;

	Template.ActivationSpeech = 'Insanity';

	// This action is considered 'hostile' and can be interrupted!
	Template.Hostility = eHostility_Offensive;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'Insanity'
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'Insanity'
	
	return Template;
}

static function X2AbilityTemplate Inspire()
{
	local X2AbilityTemplate				Template;
	local X2AbilityCost_ActionPoints	ActionPointCost;
	local X2Effect_GrantActionPoints	ActionPointEffect;
	local X2Effect_Persistent			ActionPointPersistEffect;
	local X2Condition_UnitProperty      TargetCondition;
	local X2AbilityCooldown             Cooldown;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Inspire');

	// Icon Properties
	Template.DisplayTargetHitChance = true;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';                                       // color of the icon
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_inspire";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_CORPORAL_PRIORITY;
	Template.Hostility = eHostility_Defensive;
	Template.bLimitTargetIcons = true;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;	
	
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.INSPIRE_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	TargetCondition = new class'X2Condition_UnitProperty';
	TargetCondition.ExcludeHostileToSource = true;
	TargetCondition.ExcludeFriendlyToSource = false;
	TargetCondition.RequireSquadmates = true;
	TargetCondition.FailOnNonUnits = true;
	TargetCondition.ExcludeDead = true;
	TargetCondition.ExcludeRobotic = true;
	TargetCondition.ExcludeUnableToAct = true;
	Template.AbilityTargetConditions.AddItem(TargetCondition);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	ActionPointEffect = new class'X2Effect_GrantActionPoints';
	ActionPointEffect.NumActionPoints = 1;
	ActionPointEffect.PointType = class'X2CharacterTemplateManager'.default.StandardActionPoint;
	ActionPointEffect.bSelectUnit = true;
	Template.AddTargetEffect(ActionPointEffect);

	// A persistent effect for the effects code to attach a duration to
	ActionPointPersistEffect = new class'X2Effect_Persistent';
	ActionPointPersistEffect.EffectName = 'Inspiration';
	ActionPointPersistEffect.BuildPersistentEffect( 1, false, true, false, eGameRule_PlayerTurnEnd );
	ActionPointPersistEffect.bRemoveWhenTargetDies = true;
	Template.AddTargetEffect(ActionPointPersistEffect);

	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	
	Template.ActivationSpeech = 'Inspire';

	Template.bShowActivation = true;
	Template.CustomFireAnim = 'HL_Psi_ProjectileMedium';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'Inspire'
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'Inspire'

	return Template;
}

static function X2AbilityTemplate Schism()
{
	local X2AbilityTemplate         Template;

	Template = PurePassive('Schism', "img:///UILibrary_PerkIcons.UIPerk_schism", false, 'eAbilitySource_Psionic');
	Template.PrerequisiteAbilities.AddItem('Insanity');

	return Template;
}

static function X2AbilityTemplate Fortress()
{
	local X2AbilityTemplate             Template;
	local X2Effect_Persistent           PersistentEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Fortress');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_fortress";
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	PersistentEffect = new class'X2Effect_Fortress';
	PersistentEffect.BuildPersistentEffect(1, true, false);
	PersistentEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,, Template.AbilitySourceName);
	Template.AddTargetEffect(PersistentEffect);

	Template.bSkipFireAction = true;
	Template.bSkipPerkActivationActions = true; // we'll trigger this perk manually based on tile movement
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

static function X2AbilityTemplate Fuse()
{
	local X2AbilityTemplate             Template;
	local X2AbilityCost_ActionPoints    ActionPointCost;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Fuse');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_fuse";
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_MAJOR_PRIORITY;
	Template.Hostility = eHostility_Offensive;
	Template.bLimitTargetIcons = true;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);	
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	Template.AbilityTargetConditions.AddItem(new class'X2Condition_FuseTarget');	
	Template.AddShooterEffectExclusions();

	Template.PostActivationEvents.AddItem(default.FuseEventName);
	Template.PostActivationEvents.AddItem(default.FusePostEventName);

	Template.bShowActivation = true;
	Template.CustomFireAnim = 'HL_Psi_SelfCast';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.TargetingMethod = class'X2TargetingMethod_Fuse';
	Template.CinescriptCameraType = "Psionic_FireAtUnit";
	Template.DamagePreviewFn = FuseDamagePreview;

	//Retain concealment when activating Fuse - then break it after the explosions have occurred.
	Template.ConcealmentRule = eConceal_Always;
	Template.AdditionalAbilities.AddItem('FusePostActivationConcealmentBreaker');
//BEGIN AUTOGENERATED CODE: Template Overrides 'Fuse'
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'Fuse'

	return Template;
}

static function X2AbilityTemplate FusePostActivationConcealmentBreaker()
{
	local X2AbilityTemplate             Template;
	local X2AbilityTrigger_EventListener EventListener;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'FusePostActivationConcealmentBreaker');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_fuse";
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Offensive;

	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityToHitCalc = default.DeadEye;

	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_Self;
	EventListener.ListenerData.EventID = default.FusePostEventName;
	EventListener.ListenerData.Filter = eFilter_Unit;
	Template.AbilityTriggers.AddItem(EventListener);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	//No visualization. Concealment break will trigger its own change container.
//BEGIN AUTOGENERATED CODE: Template Overrides 'FusePostActivationConcealmentBreaker'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'FusePostActivationConcealmentBreaker'

	return Template;
}

function bool FuseDamagePreview(XComGameState_Ability AbilityState, StateObjectReference TargetRef, out WeaponDamageValue MinDamagePreview, out WeaponDamageValue MaxDamagePreview, out int AllowsShield)
{
	local XComGameStateHistory History;
	local XComGameState_Ability FuseTargetAbility;
	local XComGameState_Unit TargetUnit;
	local StateObjectReference EmptyRef, FuseRef;

	History = `XCOMHISTORY;
	TargetUnit = XComGameState_Unit(History.GetGameStateForObjectID(TargetRef.ObjectID));
	if (TargetUnit != none)
	{
		if (class'X2Condition_FuseTarget'.static.GetAvailableFuse(TargetUnit, FuseRef))
		{
			FuseTargetAbility = XComGameState_Ability(History.GetGameStateForObjectID(FuseRef.ObjectID));
			if (FuseTargetAbility != None)
			{
				//  pass an empty ref because we assume the ability will use multi target effects.
				FuseTargetAbility.GetDamagePreview(EmptyRef, MinDamagePreview, MaxDamagePreview, AllowsShield);
				return true;
			}
		}
	}
	return false;
}

static function X2AbilityTemplate Domination()
{
	local X2AbilityTemplate             Template;
	local X2AbilityCost_ActionPoints    ActionPointCost;
	local X2Condition_UnitProperty      UnitPropertyCondition;
	local X2Effect_MindControl          MindControlEffect;
	local X2Effect_StunRecover			StunRecoverEffect;
	local X2Condition_UnitEffects       EffectCondition;
	local X2AbilityCharges              Charges;
	local X2AbilityCost_Charges         ChargeCost;
	local X2AbilityCooldown             Cooldown;
	local X2Condition_UnitImmunities	UnitImmunityCondition;
	local X2AbilityToHitCalc_StatCheck_UnitVsUnit StatCheck;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Domination');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_domination";
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_MAJOR_PRIORITY;
	Template.Hostility = eHostility_Offensive;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Charges = new class'X2AbilityCharges';
	Charges.InitialCharges = 1;
	Template.AbilityCharges = Charges;

	ChargeCost = new class'X2AbilityCost_Charges';
	ChargeCost.NumCharges = 1;
	ChargeCost.bOnlyOnHit = true;
	Template.AbilityCosts.AddItem(ChargeCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.DOMINATION_COOLDOWN;
	Cooldown.bDoNotApplyOnHit = true;
	Template.AbilityCooldown = Cooldown;
	
	StatCheck = new class'X2AbilityToHitCalc_StatCheck_UnitVsUnit';
	StatCheck.BaseValue = 50;
	Template.AbilityToHitCalc = StatCheck;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.FailOnNonUnits = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);	
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	EffectCondition = new class'X2Condition_UnitEffects';
	EffectCondition.AddExcludeEffect(class'X2Effect_MindControl'.default.EffectName, 'AA_UnitIsMindControlled');
	Template.AbilityTargetConditions.AddItem(EffectCondition);

	UnitImmunityCondition = new class'X2Condition_UnitImmunities';
	UnitImmunityCondition.AddExcludeDamageType('Mental');
	UnitImmunityCondition.bOnlyOnCharacterTemplate = true;
	Template.AbilityTargetConditions.AddItem(UnitImmunityCondition);

	//  mind control target
	MindControlEffect = class'X2StatusEffects'.static.CreateMindControlStatusEffect(1, false, true);
	Template.AddTargetEffect(MindControlEffect);

	StunRecoverEffect = class'X2StatusEffects'.static.CreateStunRecoverEffect();
	Template.AddTargetEffect(StunRecoverEffect);

	Template.AddTargetEffect(class'X2StatusEffects'.static.CreateMindControlRemoveEffects());

	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	Template.ActivationSpeech = 'Domination';
	Template.SourceMissSpeech = 'SoldierFailsControl';

	Template.CustomFireAnim = 'HL_Psi_MindControl';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'Domination'
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'Domination'
	
	return Template;
}

static function X2AbilityTemplate NullLance()
{
	local X2AbilityTemplate					Template;
	local X2AbilityTarget_Cursor			CursorTarget;
	local X2AbilityMultiTarget_Line         LineMultiTarget;
	local X2Condition_UnitProperty          TargetCondition;
	local X2AbilityCost_ActionPoints        ActionCost;
	local X2Effect_ApplyWeaponDamage        DamageEffect;
	local X2AbilityCooldown_PerPlayerType	Cooldown;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'NullLance');

	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.Hostility = eHostility_Offensive;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_nulllance";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_COLONEL_PRIORITY;

	Template.CustomFireAnim = 'HL_Psi_ProjectileHigh';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;

	ActionCost = new class'X2AbilityCost_ActionPoints';
	ActionCost.iNumPoints = 1;   // Updated 8/18/15 to 1 action point only per Jake request.  
	ActionCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionCost);

	Cooldown = new class'X2AbilityCooldown_PerPlayerType';
	Cooldown.iNumTurns = default.NULL_LANCE_COOLDOWN_PLAYER;
	Cooldown.iNumTurnsForAI = default.NULL_LANCE_COOLDOWN_AI;
	cooldown.NumGlobalTurns = default.NULL_LANCE_GLOBAL_COOLDOWN_AI;
	Template.AbilityCooldown = Cooldown;

	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);	
	Template.AbilityToHitCalc = default.DeadEye;

	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.FixedAbilityRange = 15;
	Template.AbilityTargetStyle = CursorTarget;

	LineMultiTarget = new class'X2AbilityMultiTarget_Line';
	Template.AbilityMultiTargetStyle = LineMultiTarget;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	TargetCondition = new class'X2Condition_UnitProperty';
	TargetCondition.ExcludeFriendlyToSource = false;
	TargetCondition.ExcludeDead = true;
	Template.AbilityMultiTargetConditions.AddItem(TargetCondition);

	DamageEffect = new class'X2Effect_ApplyWeaponDamage';
	DamageEffect.bIgnoreBaseDamage = true;
	DamageEffect.DamageTag = 'NullLance';
	DamageEffect.bIgnoreArmor = true;
	Template.AddMultiTargetEffect(DamageEffect);

	Template.TargetingMethod = class'X2TargetingMethod_Line';
	Template.CinescriptCameraType = "Psionic_FireAtLocation";

	Template.ActivationSpeech = 'NullLance';

	Template.bOverrideAim = true;
	Template.bUseSourceLocationZToAim = true;

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'NullLance'
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'NullLance'

	return Template;
}

static function X2AbilityTemplate VoidRift()
{
	local X2AbilityTemplate                 Template;
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2AbilityTarget_Cursor            CursorTarget;
	local X2AbilityMultiTarget_Radius       RadiusMultiTarget;
	local X2AbilityCooldown                 Cooldown;
	local X2Effect_ApplyWeaponDamage        DamageEffect;
	local X2Effect_TriggerEvent             InsanityEvent;
	local X2Effect_PerkAttachForFX          DurationFXEffect;
	local X2Effect_TriggerEvent             EndDurationFXEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'VoidRift');

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.VOID_RIFT_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.bRestrictToSquadsightRange = true;
	CursorTarget.FixedAbilityRange = default.VOID_RIFT_RANGE;
	Template.AbilityTargetStyle = CursorTarget;

	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = default.VOID_RIFT_RADIUS;
	RadiusMultiTarget.bIgnoreBlockingCover = true;
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	DurationFXEffect = new class 'X2Effect_PerkAttachForFX';
	DurationFXEffect.BuildPersistentEffect(1, false, true, , eGameRule_PlayerTurnEnd);
	DurationFXEffect.EffectName = default.VoidRiftDurationFXEffectName;
	Template.AddShooterEffect(DurationFXEffect);

	DamageEffect = new class'X2Effect_ApplyWeaponDamage';
	DamageEffect.bIgnoreBaseDamage = true;
	DamageEffect.DamageTag = 'VoidRift';
	DamageEffect.bIgnoreArmor = true;
	Template.AddMultiTargetEffect(DamageEffect);

	InsanityEvent = new class'X2Effect_TriggerEvent';
	InsanityEvent.TriggerEventName = default.VoidRiftInsanityEventName;
	InsanityEvent.ApplyChance = default.VOID_RIFT_INSANITY_CHANCE;
	Template.AddMultiTargetEffect(InsanityEvent);

	EndDurationFXEffect = new class'X2Effect_TriggerEvent';
	EndDurationFXEffect.TriggerEventName = default.EndVoidRiftDurationFXEventName;
	Template.AddShooterEffect(EndDurationFXEffect);

	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_COLONEL_PRIORITY;
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_voidrift";
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.bShowActivation = true;
	Template.CustomFireAnim = 'HL_Psi_MindControl';

	Template.TargetingMethod = class'X2TargetingMethod_VoidRift';

	Template.ActivationSpeech = 'VoidRift';

	Template.AdditionalAbilities.AddItem('VoidRiftInsanity');
	Template.AdditionalAbilities.AddItem('VoidRiftEndDurationFX');
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtLocation";

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'VoidRift'
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
//END AUTOGENERATED CODE: Template Overrides 'VoidRift'

	return Template;
}

static function X2AbilityTemplate VoidRiftInsanity()
{
	local X2AbilityTemplate             Template;
	local X2Condition_UnitProperty      UnitPropertyCondition;
	local X2Effect_PersistentStatChange DisorientedEffect;
	local X2Effect_MindControl          MindControlEffect;
	local X2Effect_RemoveEffects        MindControlRemoveEffects;
	local X2Effect_Panicked             PanicEffect;
	local X2Effect_ApplyWeaponDamage    RuptureEffect;
	local X2Condition_AbilityProperty   SchismCondition;
	local X2Condition_UnitType			UnitTypeCondition;
	local X2AbilityTrigger_EventListener EventListener;
	local X2AbilityToHitCalc_StatCheck_UnitVsUnit StatCheck;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'VoidRiftInsanity');
	
	StatCheck = new class'X2AbilityToHitCalc_StatCheck_UnitVsUnit';
	StatCheck.BaseValue = 50;
	Template.AbilityToHitCalc = StatCheck;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.FailOnNonUnits = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);

	UnitTypeCondition = new class'X2Condition_UnitType';
	UnitTypeCondition.ExcludeTypes.AddItem('ChosenAssassin');
	UnitTypeCondition.ExcludeTypes.AddItem('ChosenWarlock');
	UnitTypeCondition.ExcludeTypes.AddItem('ChosenSniper');
	Template.AbilityTargetConditions.AddItem(UnitTypeCondition);

	//  Disorient effect for 1 unblocked psi hit
	DisorientedEffect = class'X2StatusEffects'.static.CreateDisorientedStatusEffect();
	DisorientedEffect.iNumTurns = 2;
	DisorientedEffect.MinStatContestResult = 1;
	DisorientedEffect.MaxStatContestResult = 1;     
	DisorientedEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(DisorientedEffect);

	//  Longer Disorient effect for 2 unblocked psi hits
	DisorientedEffect = class'X2StatusEffects'.static.CreateDisorientedStatusEffect();
	DisorientedEffect.iNumTurns = 3;
	DisorientedEffect.MinStatContestResult = 2;
	DisorientedEffect.MaxStatContestResult = 2;     
	DisorientedEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(DisorientedEffect);
	
	//  Panic effect for 3-4 unblocked psi hits
	PanicEffect = class'X2StatusEffects'.static.CreatePanickedStatusEffect();
	PanicEffect.MinStatContestResult = 3;
	PanicEffect.MaxStatContestResult = 4;
	PanicEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(PanicEffect);

	//  Mind control effect for 5+ unblocked psi hits
	MindControlEffect = class'X2StatusEffects'.static.CreateMindControlStatusEffect(1, false, false);
	MindControlEffect.MinStatContestResult = 5;
	MindControlEffect.MaxStatContestResult = 0;
	MindControlEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(MindControlEffect);

	MindControlRemoveEffects = class'X2StatusEffects'.static.CreateMindControlRemoveEffects();
	MindControlRemoveEffects.MinStatContestResult = 5;
	MindControlRemoveEffects.MaxStatContestResult = 0;
	Template.AddTargetEffect(MindControlRemoveEffects);

	//  Rupture effect if the caster has Schism
	RuptureEffect = new class'X2Effect_ApplyWeaponDamage';
	RuptureEffect.EffectDamageValue = default.SCHISM_DMG;
	RuptureEffect.MinStatContestResult = 1;
	RuptureEffect.MaxStatContestResult = 0;
	RuptureEffect.bIgnoreArmor = true;
	SchismCondition = new class'X2Condition_AbilityProperty';
	SchismCondition.OwnerHasSoldierAbilities.AddItem('Schism');
	RuptureEffect.TargetConditions.AddItem(SchismCondition);
	Template.AddTargetEffect(RuptureEffect);

	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	
	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.EventID = default.VoidRiftInsanityEventName;
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.Filter = eFilter_Unit;
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.VoidRiftInsanityListener;
	Template.AbilityTriggers.AddItem(EventListener);

	Template.CustomFireAnim = 'HL_Psi_MindControl';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";

	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_insanity";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_CORPORAL_PRIORITY;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Offensive;
//BEGIN AUTOGENERATED CODE: Template Overrides 'VoidRiftInsanity'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'VoidRiftInsanity'
	
	Template.PostActivationEvents.AddItem(default.EndVoidRiftDurationFXEventName);

	return Template;
}

static function X2AbilityTemplate VoidRiftEndDurationFX()
{
	local X2AbilityTemplate             Template;
	local X2Effect_RemoveEffects        VoidRiftRemoveEffects;
	local X2AbilityTrigger_EventListener EventListener;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'VoidRiftEndDurationFX');
	
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	
	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.EventID = default.EndVoidRiftDurationFXEventName;
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.Filter = eFilter_Unit;
	EventListener.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_VoidRiftEndDurrationFX;
	Template.AbilityTriggers.AddItem(EventListener);

	VoidRiftRemoveEffects = new class'X2Effect_RemoveEffects';
	VoidRiftRemoveEffects.EffectNamesToRemove.AddItem(default.VoidRiftDurationFXEffectName);
	Template.AddShooterEffect(VoidRiftRemoveEffects);

	Template.bSkipFireAction = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_insanity";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_CORPORAL_PRIORITY;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	
	return Template;
}

static function X2DataTemplate PsiOperativeMindControlAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2AbilityCooldown Cooldown;
	local X2Condition_UnitProperty UnitPropertyCondition;
	local X2Condition_UnitImmunities UnitImmunityCondition;
	local X2Condition_UnitEffects EffectCondition;
	local X2Effect_MindControl MindControlEffect;
	local X2Effect_RemoveEffects MindControlRemoveEffects;
	local X2AbilityTarget_Single SingleTarget;
	local X2AbilityToHitCalc_StatCheck_UnitVsUnit StatCheck;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'PsiOperativeMindControl');

	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_adventpsiwitch_mindcontrol";
	Template.Hostility = eHostility_Offensive;
	Template.bShowActivation = true;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.PSI_OP_MIND_CONTROL_COOLDOWN_PLAYER;
	Template.AbilityCooldown = Cooldown;

	StatCheck = new class'X2AbilityToHitCalc_StatCheck_UnitVsUnit';
	StatCheck.BaseValue = 50;
	Template.AbilityToHitCalc = StatCheck;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	EffectCondition = new class'X2Condition_UnitEffects';
	EffectCondition.AddExcludeEffect(class'X2Effect_MindControl'.default.EffectName, 'AA_UnitIsMindControlled');
	Template.AbilityShooterConditions.AddItem(EffectCondition);

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.ExcludeRobotic = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	UnitImmunityCondition = new class'X2Condition_UnitImmunities';
	UnitImmunityCondition.AddExcludeDamageType('Mental');
	UnitImmunityCondition.bOnlyOnCharacterTemplate = true;
	Template.AbilityTargetConditions.AddItem(UnitImmunityCondition);

	EffectCondition = new class'X2Condition_UnitEffects';
	EffectCondition.AddExcludeEffect(class'X2Effect_MindControl'.default.EffectName, 'AA_UnitIsMindControlled');
	Template.AbilityTargetConditions.AddItem(EffectCondition);

	// MindControl effect for 1 or more unblocked psi hit
	MindControlEffect = class'X2StatusEffects'.static.CreateMindControlStatusEffect(default.PSI_OP_MIND_CONTROL_LASTS_NUMBER_TURNS);
	MindControlEffect.MinStatContestResult = 1;
	MindControlEffect.DamageTypes.AddItem('Psi');
	Template.AddTargetEffect(MindControlEffect);

	MindControlRemoveEffects = class'X2StatusEffects'.static.CreateMindControlRemoveEffects();
	MindControlRemoveEffects.MinStatContestResult = 1;
	Template.AddTargetEffect(MindControlRemoveEffects);
	// MindControl effect for 1 or more unblocked psi hit

	SingleTarget = new class'X2AbilityTarget_Single';
	Template.AbilityTargetStyle = SingleTarget;

	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	// Unlike in other cases, in TypicalAbility_BuildVisualization, the MissSpeech is used on the Target!
	Template.TargetMissSpeech = 'SoldierResistsMindControl';

	Template.CustomFireAnim = 'HL_Psi_MindControl';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";

	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
//BEGIN AUTOGENERATED CODE: Template Overrides 'PsiOperativeMindControl'
	Template.bFrameEvenWhenUnitIsHidden = true;
//END AUTOGENERATED CODE: Template Overrides 'PsiOperativeMindControl'

	return Template;
}

DefaultProperties
{
	FuseEventName="FuseTriggered"
	FusePostEventName="FusePostTriggered"
	SoulStealEventName="SoulStealTriggered"
	SoulStealUnitValue="SoulStealAmount"
	VoidRiftInsanityEventName="VoidRiftInsanityTriggered"
	EndVoidRiftDurationFXEventName="EndVoidRiftDurationFXEvent"
	VoidRiftDurationFXEffectName="VoidRiftDurationFXEffect"
}
