/**
 * SceneCaptureComponent
 *
 * Base class for scene recording components
 *
 * Copyright 1998-2011 Epic Games, Inc. All Rights Reserved.
 */
class SceneCaptureComponent extends ActorComponent
	native
	abstract
	hidecategories(Object)
	dependson(PostProcessVolume);

/** Turn the scene capture on/off */
var(Capture) bool bEnabled;

/** toggle scene post-processing */
var(Capture) bool bEnablePostProcess;
/** toggle fog */
var(Capture) bool bEnableFog;
/** toggle screen space reflections. */
var(Capture) bool bEnableSSReflections;
/** toggle ambient */
var(Capture) bool bEnableAmbient;
/** toggle SSAO */
var(Capture) bool bEnableSSAO;
/** tells the capture component to write out translucency alpha into alpha channel of render target (opaque set to 1) */
var(Capture) bool bEnableAlphaMask;
/** whether to clear color and depth or not */
var(Capture) bool bForceNoClear; // FIRAXIS
/** whether to resolve or not */
var(Capture) bool bForceNoResolve; // FIRAXIS
/** whether this si the scene capture for the edge effect */
var(Capture) bool bIsXComEdgeCapture; // FIRAXIS
/** skip any rendering of static primitives - an optimization */
var(Capture) bool bDynamicOnly;
/** background color */
var(Capture) color ClearColor;

// draw modes - based on ESceneViewMode
enum ESceneCaptureViewMode
{
	// lit/shadowed scene
	SceneCapView_Lit,
	// no shadows or lights
	SceneCapView_Unlit,
	// lit/unshadowed scene
	SceneCapView_LitNoShadows,
	// depth of scene
	SceneCapView_Depth, //FIRAXIS ADDITION
	// wireframe
	SceneCapView_Wire
};
/** how to draw the scene */
var(Capture) ESceneCaptureViewMode ViewMode;
/** NOT IMPLEMENTED! level-of-detail setting */
var(Capture) int SceneLOD;

// FIRAXIS addition jshopf
// How many times to capture the scene (for problems with renders of materials that use the target)
var(Capture) int m_nRenders;

/**
 * rate to capture the scene,
 * TimeBetweenCaptures = Max( 1/FrameRate, DeltaTime),
 * if the FrameRate is 0 then the scene is captured only once
 */
var(Capture) const float FrameRate;
/** Chain of post process effects for this post process view */
var(Capture) PostProcessChain PostProcess;
/** If TRUE then use the main scene's post process settings when capturing */
var(Capture) bool bUseMainScenePostProcessSettings;
/** If bUseMainScenePostProcessSettings is FALSE, then use this settings object instead. */
var(Capture) PostProcessSettingsObject PostProcessSetting;

/** if true, skip updating the scene capture if the users of the texture have not been rendered recently */
var(Capture) bool bSkipUpdateIfTextureUsersOccluded;
/** if true, skip updating the scene capture if the Owner of the component has not been rendered recently */
var(Capture) bool bSkipUpdateIfOwnerOccluded;
/** if > 0, skip updating the scene capture if the Owner is further than this many units away from the viewer */
var(Capture) float MaxUpdateDist;

/** if > 0, sets a maximum render distance override.  Can be used to cull distant objects from a reflection if
   the reflecting plane is in an enclosed area like a hallway or room */
var(Capture) float MaxViewDistanceOverride;

/** The lower the number, the sooner this capture is placed in the queue for each frame for rendering. Usefull to ensure a certain capture render before another. */
var(Capture) int RenderPriority;

/** If we're forcing an aspect ratio, this is the aspect ratio to force in proj matrix calculation */
var float m_fConstrainedAspectRatio; // FIRAXIS

/** if true, skip the depth prepass when rendering the scene capture.
    The prepass CPU cost is not worth the GPU savings when the scene capture is small. */
var bool bSkipRenderingDepthPrepass;

/** 
 * if > 0, skip streaming texture updates for the scene capture if the Owner is further than this many units away from the viewer.
 * if == 0, then view information for this scene capture is not used by texture streaming manager for updates.
 */
var(Capture) float MaxStreamingUpdateDist;

//FIRAXIS ADDITION
var(Capture) RenderChannelContainer RenderChannels;

// Update ConvertColorWriteMaskToByte() if you change this enum
enum ECaptureWriteMask {
	eCaptureWriteMask_RED,
	eCaptureWriteMask_GREEN,
	eCaptureWriteMask_BLUE,
	eCaptureWriteMask_ALPHA,
	eCaptureWriteMask_RGB,
	eCaptureWriteMask_RGBA,
	eCaptureWriteMask_RB,
	eCaptureWriteMask_GA
};

var(Capture) ECaptureWriteMask ColorWriteMask;

var(Capture) bool bCaptureVertexColors;
//FIRAXIS END

// transients

/** ptr to the scene capture probe */
var private const transient native pointer CaptureInfo{FCaptureSceneInfo};
/** pointer to the persistent view state for this scene capture */
var private const transient native pointer ViewState{FSceneViewStateInterface};

/**  Stores post-process scene proxies created from the post process chain that are eventually copied to the scene view. */
var native noimport transient duplicatetransient const array<pointer> PostProcessProxies{class FPostProcessSceneProxy};

cpptext
{
protected:

	/**
	* Constructor
	*/
	USceneCaptureComponent();

	// UActorComponent interface.

	/**
	* Adds a capture proxy for this component to the scene
	*/
	virtual void Attach();

	/**
	* Removes a capture proxy for thsi component from the scene
	*/
	virtual void Detach( UBOOL bWillReattach = FALSE );

	virtual void UpdateTransform();

	/**
	* Tick the component to handle updates
	*/
	virtual void Tick(FLOAT DeltaTime);

	virtual void FinishDestroy();

public:
	/**
	* Create a new probe with info needed to render the scene
	*/
	virtual class FSceneCaptureProbe* CreateSceneCaptureProbe() { return NULL; }

	/**
	* Map the various capture view settings to show flags.
	*/
	virtual EShowFlags GetSceneShowFlags();
}

/** modifies the value of FrameRate */
native final function SetFrameRate(float NewFrameRate);

/** 
  * Enable or disable this SceneCaptureComponent.
  */
simulated native final function SetEnabled(bool bEnable);

event CaptureFinished()
{}

defaultproperties
{
	ViewMode=SceneCapView_LitNoShadows
	bForceNoClear=false // FIRAXIS
	bForceNoResolve=false // FIRAXIS
	bIsXComEdgeCapture=false // FIRAXIS
	bEnableAlphaMask=false
	bEnableSSAO=false
	bDynamicOnly=false // FIRAXIS
	ClearColor=(R=0,G=0,B=0,A=255)
	FrameRate=30
	bEnabled=true
	MaxViewDistanceOverride=0.0
	bSkipRenderingDepthPrepass=false
	m_nRenders=0 // FIRAXIS addition jshopf
	ColorWriteMask=eCaptureWriteMask_RGBA

	m_fConstrainedAspectRatio=-1;
	RenderPriority = 0;
	bCaptureVertexColors=false

	RenderChannels=(MainScene=true,UnitVisibility=false,RainCollisionStatic=false,RainCollisionDynamic=false,Occluded=false,Occluded2=false,SecondaryScene=false,XenoformGrass=false)
}
