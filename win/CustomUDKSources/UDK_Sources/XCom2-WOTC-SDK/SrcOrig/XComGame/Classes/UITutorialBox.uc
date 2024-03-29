//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UITutorialBox.uc
//  AUTHOR:  Brit Steiner - 9/11/2015
//  PURPOSE: This file corresponds to the tutorial center popup box
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UITutorialBox extends UIScreen;

var string Title;
var string Desc;
var string ButtonHelp;
var string ImagePath;

//----------------------------------------------------------------------------
// MEMBERS

simulated function OnInit()
{
	local UIPanel TutorialButtonContainer;
	local UIButton ConfirmButton;

	// ----------------------------

	if( XComTacticalCheatManager(`XCOMGRI.GetALocalPlayerController().CheatManager) != none &&
	   XComTacticalCheatManager(`XCOMGRI.GetALocalPlayerController().CheatManager).bDisableTutorialPopups )
	{
		bIsVisible = false; 
		super.OnInit();
		CloseScreen();
		return; 
	}

	// ----------------------------

	super.OnInit();

	`SOUNDMGR.PlaySoundEvent("TacticalUI_Tutorial_Popup");

	TutorialButtonContainer = spawn(class'UIPanel', self).InitPanel('TutorialButton');
	ConfirmButton = Spawn(class'UIButton', TutorialButtonContainer).InitButton('Button', , OnConfirmButtonClicked);
	ConfirmButton.SetStyle(eUIButtonStyle_HOTLINK_BUTTON);
	ConfirmButton.SetGamepadIcon(class 'UIUtilities_Input'.static.GetAdvanceButtonIcon());
	ConfirmButton.DisableNavigation();
	TutorialbuttonContainer.DisableNavigation();

	MC.BeginFunctionOp("UpdateInfo");
	MC.QueueString(Title);
	MC.QueueString(class'UIUtilities_Input'.static.InsertPCIcons(Desc));
	MC.QueueString(ImagePath);
	MC.QueueString(ButtonHelp == "" ? class'UIUtilities_Text'.default.m_strGenericConfirm : ButtonHelp);
	MC.EndOp();

	// If autotesting, auto-accept in a few moments
	if (WorldInfo.Game.MyAutoTestManager != none)
	{
		SetTimer(4.0, false, nameof(CloseScreen));
	}
}

simulated function OnConfirmButtonClicked(UIButton Button)
{
	CloseScreen();
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;
	switch( cmd )
	{
`if(`notdefined(FINAL_RELEASE))
	case class'UIUtilities_Input'.const.FXS_KEY_TAB:
`endif
	case class'UIUtilities_Input'.const.FXS_BUTTON_A:
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
		CloseScreen();
		return true;
	}

	return super.OnUnrealCommand(cmd, arg);
}

simulated function CloseScreen()
{
	super.CloseScreen();
	`SOUNDMGR.PlaySoundEvent("TacticalUI_Tutorial_Popup_Exit");
}

//==============================================================================

defaultproperties
{
	Package = "/ package/gfxTutorialBox/TutorialBox";

	InputState = eInputState_Consume;
	bConsumeMouseEvents = true;
}