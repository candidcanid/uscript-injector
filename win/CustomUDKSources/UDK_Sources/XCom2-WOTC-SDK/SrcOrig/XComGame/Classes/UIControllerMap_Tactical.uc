//=============================================================================
//  Gamepad/controller layout user interface for xcom
//=============================================================================
class UIControllerMap_Tactical extends UIControllerMap;

/* ???TMH - DEPRECATE 
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;
	bHandled = true;

	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	switch( cmd )
	{
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_BUTTON_B: 
			Movie.Pres.PopState();
			break;

		default:
			bHandled = false;
			break;
	}

	return bHandled;
}

//=====================================================================
// 		LAYOUT FUNCTIONS:
//=====================================================================

function BuildGamepad()
{
	//NOTE: Anything that you don't want to show, set it to blank / empty string

	titleS1 = m_sControllerMap;
	titleS2 = m_sBattlescape;

	UIGamePad[0].icon = class'UIUtilities_Input'.const.ICON_RT_R2;
	UIGamePad[0].label = m_sAimWeapon;

	UIGamePad[1].icon = class'UIUtilities_Input'.const.ICON_RB_R1; 
	UIGamePad[1].label = m_sNextUnit;

	UIGamePad[2].icon = class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE;
	UIGamePad[2].label = m_sEndTurn;

	UIGamePad[3].icon = class'UIUtilities_Input'.const.ICON_B_CIRCLE; 
	UIGamePad[3].label = m_sTurnToCursor;

	UIGamePad[4].icon = class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE; 
	UIGamePad[4].label = m_sInventory;

	UIGamePad[5].icon = class'UIUtilities_Input'.const.ICON_A_X; 
	UIGamePad[5].label = m_sMoveToCursor;

	UIGamePad[6].icon = class'UIUtilities_Input'.const.ICON_RSTICK;
	UIGamePad[6].label = m_sCameraControl;

	UIGamePad[7].icon = class'UIUtilities_Input'.const.ICON_START;
	UIGamePad[7].label = m_sPauseGame;

	UIGamePad[8].icon = class'UIUtilities_Input'.const.ICON_BACK_SELECT; 
	UIGamePad[8].label = m_sHelp;

	UIGamePad[9].icon = class'UIUtilities_Input'.const.ICON_DPAD_VERTICAL;
	UIGamePad[9].label = m_sStandCrouch;

	UIGamePad[10].icon = class'UIUtilities_Input'.const.ICON_DPAD_HORIZONTAL; 
	UIGamePad[10].label = m_sZoom;

	UIGamePad[11].icon = class'UIUtilities_Input'.const.ICON_LSTICK; 
	UIGamePad[11].label = m_sMoveCursor;

	UIGamePad[12].icon = class'UIUtilities_Input'.const.ICON_LB_L1; 
	UIGamePad[12].label = m_sPrevUnit;

	UIGamePad[13].icon = class'UIUtilities_Input'.const.ICON_LT_L2; 
	UIGamePad[13].label = m_sActionMenu;
}

defaultproperties
{
}
*/