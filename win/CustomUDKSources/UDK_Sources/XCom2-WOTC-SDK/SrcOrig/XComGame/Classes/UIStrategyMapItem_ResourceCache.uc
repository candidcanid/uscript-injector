//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIStrategyMapItem_ResourceCache
//  AUTHOR:  Sam Batista -- 08/2014
//  PURPOSE: This file represents a resource cache spot on the StrategyMap.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIStrategyMapItem_ResourceCache extends UIStrategyMapItem;

var UIScanButton ScanButton;

simulated function UIStrategyMapItem InitMapItem(out XComGameState_GeoscapeEntity Entity)
{
	// Spawn the children BEFORE the super.Init because inside that super, it will trigger UpdateFlyoverText and other functions
	// which may assume these children already exist. 
	
	super.InitMapItem(Entity);

	ScanButton = Spawn(class'UIScanButton', self).InitScanButton();
	ScanButton.SetY(15);
	ScanButton.SetButtonIcon("");
	ScanButton.SetDefaultDelegate(OnDefaultClicked);
	ScanButton.SetButtonType(eUIScanButtonType_Supplies);
	ScanButton.OnSizeRealized = OnButtonSizeRealized;
	
	return self;
}
simulated function OnButtonSizeRealized()
{
	ScanButton.SetX(-ScanButton.Width / 2.0);
}

function UpdateFromGeoscapeEntity(const out XComGameState_GeoscapeEntity GeoscapeEntity)
{
	local string ScanTitle;
	local string ScanTimeValue;
	local string ScanTimeLabel;
	local string ScanInfo;
	local int DaysRemaining;

	if( !bIsInited ) return; 

	super.UpdateFromGeoscapeEntity(GeoscapeEntity);

	if( IsAvengerLandedHere() )
		ScanButton.Expand();
	else
		ScanButton.DefaultState();


	ScanTitle = MapPin_Header;
	DaysRemaining = GetCache().GetNumScanDaysRemaining();
	ScanTimeValue = string(DaysRemaining);
	ScanTimeLabel = class'UIUtilities_Text'.static.GetDaysString(DaysRemaining);
	ScanInfo = GetCache().GetTotalResourceAmount();

	ScanButton.SetText(ScanTitle, ScanInfo, ScanTimeValue, ScanTimeLabel);
	ScanButton.AnimateIcon(`GAME.GetGeoscape().IsScanning() && IsAvengerLandedHere());
	ScanButton.SetScanMeter(GetCache().GetScanPercentComplete());
	ScanButton.Realize();
}

function OnDefaultClicked()
{
	GetCache().AttemptSelectionCheckInterruption();
}

simulated function XComGameState_ResourceCache GetCache()
{
	return XComGameState_ResourceCache(`XCOMHISTORY.GetGameStateForObjectID(GeoscapeEntityRef.ObjectID));
}

simulated function OnReceiveFocus()
{
	ScanButton.OnReceiveFocus();
}

simulated function OnLoseFocus()
{
	ScanButton.OnLoseFocus();
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return true;
	}

	switch(cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A:
		if (IsAvengerLandedHere())
		{
			ScanButton.ClickButtonScan();
		}
		else
		{
			OnDefaultClicked();
		}

		return true;		
	}

	return super.OnUnrealCommand(cmd, arg);
}

simulated function bool IsSelectable()
{
	return true;
}

simulated function SetZoomLevel(float ZoomLevel)
{
	super.SetZoomLevel(ZoomLevel);

	ScanButton.SetY(30.0 * (1.0 - FClamp(ZoomLevel, 0.0, 0.95)));
}
defaultproperties
{
	bProcessesMouseEvents = false;
}