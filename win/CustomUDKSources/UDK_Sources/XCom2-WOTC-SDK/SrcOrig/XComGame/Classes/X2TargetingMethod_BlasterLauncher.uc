class X2TargetingMethod_BlasterLauncher extends X2TargetingMethod;

var protected XCom3DCursor Cursor;
var protected XComPrecomputedPath GrenadePath;
var protected transient XComEmitter ExplosionEmitter;
var protected vector NewTargetLocation;
var protected bool bRestrictToSquadsightRange;
var protected XComGameState_Player AssociatedPlayerState;
var protected XGWeapon WeaponVisualizer;

function Init(AvailableAction InAction, int NewTargetIndex)
{
	local XComGameStateHistory History;
	local XComGameState_Item WeaponItem;
	local float TargetingRange;
	local X2WeaponTemplate WeaponTemplate;
	local X2AbilityTarget_Cursor CursorTarget;
	local X2AbilityTemplate AbilityTemplate;

	super.Init(InAction, NewTargetIndex);

	History = `XCOMHISTORY;

	// get the firing unit
	AssociatedPlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID));
	`assert(AssociatedPlayerState != none);

	// determine our targeting range
	WeaponItem = Ability.GetSourceWeapon();
	TargetingRange = Ability.GetAbilityCursorRangeMeters( );
	AbilityTemplate = Ability.GetMyTemplate( );

	// lock the cursor to that range
	Cursor = `Cursor;
	Cursor.m_fMaxChainedDistance = `METERSTOUNITS(TargetingRange);

	CursorTarget = X2AbilityTarget_Cursor(Ability.GetMyTemplate().AbilityTargetStyle);
	if (CursorTarget != none)
		bRestrictToSquadsightRange = CursorTarget.bRestrictToSquadsightRange;

	// show the grenade path
	WeaponTemplate = X2WeaponTemplate(WeaponItem.GetMyTemplate());
	WeaponVisualizer = XGWeapon(WeaponItem.GetVisualizer());

	// Tutorial Band-aid fix for missing visualizer due to cheat GiveItem
	if (WeaponVisualizer == none)
	{
		class'XGItem'.static.CreateVisualizer(WeaponItem);
		WeaponVisualizer = XGWeapon(WeaponItem.GetVisualizer());
		WeaponVisualizer.CreateEntity(WeaponItem);

		if (XComWeapon(WeaponVisualizer.m_kEntity) != none)
		{
			XComWeapon(WeaponVisualizer.m_kEntity).m_kPawn = FiringUnit.GetPawn();
		}
	}

	// Tutorial Band-aid #2 - Should look at a proper fix for this
	if (XComWeapon(WeaponVisualizer.m_kEntity).m_kPawn == none)
	{
		XComWeapon(WeaponVisualizer.m_kEntity).m_kPawn = FiringUnit.GetPawn();
	}

	XComWeapon(WeaponVisualizer.m_kEntity).bPreviewAim = true;

	GrenadePath = `PRECOMPUTEDPATH;	
	GrenadePath.ActivatePath(WeaponVisualizer.GetEntity(), FiringUnit.GetTeam(), WeaponTemplate.WeaponPrecomputedPathData);
	GrenadePath.m_bBlasterBomb = true;

	if (!AbilityTemplate.SkipRenderOfTargetingTemplate)
	{
		// setup the blast emitter
		ExplosionEmitter = `BATTLE.spawn(class'XComEmitter');
		if(AbilityIsOffensive)
		{
			ExplosionEmitter.SetTemplate(ParticleSystem(DynamicLoadObject("UI_Range.Particles.BlastRadius_Shpere", class'ParticleSystem')));
		}
		else
		{
			ExplosionEmitter.SetTemplate(ParticleSystem(DynamicLoadObject("UI_Range.Particles.BlastRadius_Shpere_Neutral", class'ParticleSystem')));
		}
		ExplosionEmitter.LifeSpan = 60 * 60 * 24 * 7; // never die (or at least take a week to do so)
	}
}

function Canceled()
{
	super.Canceled();

	// unlock the 3d cursor
	Cursor.m_fMaxChainedDistance = -1;

	// clean up the ui
	ExplosionEmitter.Destroy();
	GrenadePath.ClearPathGraphics();
	GrenadePath.m_bBlasterBomb = false;
	XComWeapon(WeaponVisualizer.m_kEntity).bPreviewAim = false;
	ClearTargetedActors();
}

function Committed()
{
	Canceled();
}

simulated protected function Vector GetSplashRadiusCenter()
{
	local vector Center;

	Center = GrenadePath.GetEndPosition();

	return Center;
}

simulated protected function DrawSplashRadius()
{
	local Vector Center;
	local float Radius;
	local LinearColor CylinderColor;

	Center = GetSplashRadiusCenter();
	Radius = Ability.GetAbilityRadius();
	
	/*
	if (!bValid || (m_bTargetMustBeWithinCursorRange && (fTest >= fRestrictedRange) )) {
		CylinderColor = MakeLinearColor(1, 0.2, 0.2, 0.2);
	} else if (m_iSplashHitsFriendliesCache > 0 || m_iSplashHitsFriendlyDestructibleCache > 0) {
		CylinderColor = MakeLinearColor(1, 0.81, 0.22, 0.2);
	} else {
		CylinderColor = MakeLinearColor(0.2, 0.8, 1, 0.2);
	}
	*/

	if(ExplosionEmitter != none)
	{
		ExplosionEmitter.SetLocation(Center); // Set initial location of emitter
		ExplosionEmitter.SetDrawScale(Radius / 48.0f);
		ExplosionEmitter.SetRotation( rot(0,0,1) );

		if( !ExplosionEmitter.ParticleSystemComponent.bIsActive )
		{
			ExplosionEmitter.ParticleSystemComponent.ActivateSystem();			
		}

		ExplosionEmitter.ParticleSystemComponent.SetMICVectorParameter(0, Name("RadiusColor"), CylinderColor);
		ExplosionEmitter.ParticleSystemComponent.SetMICVectorParameter(1, Name("RadiusColor"), CylinderColor);
	}
}

function Update(float DeltaTime)
{
	local array<Actor> CurrentlyMarkedTargets;
	local array<TTile> Tiles;

	NewTargetLocation = GrenadePath.GetEndPosition();

	if( NewTargetLocation != CachedTargetLocation )
	{		
		GetTargetedActors(NewTargetLocation, CurrentlyMarkedTargets, Tiles);
		CheckForFriendlyUnit(CurrentlyMarkedTargets);	
		MarkTargetedActors(CurrentlyMarkedTargets, (!AbilityIsOffensive) ? FiringUnit.GetTeam() : eTeam_None );
		DrawSplashRadius();
		DrawAOETiles(Tiles);
	}

	super.Update(DeltaTime);
}

function GetTargetLocations(out array<Vector> TargetLocations)
{
	TargetLocations.Length = 0;
	TargetLocations.AddItem(NewTargetLocation);
}

function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	local TTile TestLoc;
	if (TargetLocations.Length == 1)
	{
		if (bRestrictToSquadsightRange)
		{
			TestLoc = `XWORLD.GetTileCoordinatesFromPosition(TargetLocations[0]);
			if (!class'X2TacticalVisibilityHelpers'.static.CanSquadSeeLocation(AssociatedPlayerState.ObjectID, TestLoc))
				return 'AA_NotVisible';
		}
		return 'AA_Success';
	}
	return 'AA_NoTargets';
}

function int GetTargetIndex()
{
	return 0;
}

function bool GetAdditionalTargets(out AvailableTarget AdditionalTargets)
{
	Ability.GatherAdditionalAbilityTargetsForLocation(NewTargetLocation, AdditionalTargets);
	return true;
}

function bool GetCurrentTargetFocus(out Vector Focus)
{
	Focus = NewTargetLocation;
	return true;
}

/// <summary>
/// Returns true if this targeting method uses the precomputed path class to build a projectile path
/// </summary>
static function bool UseGrenadePath()
{
	return true;
}

defaultproperties
{
	ProjectileTimingStyle="Timing_BlasterLauncher"
	OrdnanceTypeName="Ordnance_BlasterLauncher"
}