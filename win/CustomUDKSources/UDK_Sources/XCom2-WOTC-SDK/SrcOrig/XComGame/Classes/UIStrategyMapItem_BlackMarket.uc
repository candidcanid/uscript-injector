//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIStrategyMapItem_BlackMarket
//  AUTHOR:  Mark Nauta -- 08/2014
//  PURPOSE: This file represents a black market spot on the StrategyMap.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIStrategyMapItem_BlackMarket extends UIStrategyMapItem;

var public localized String m_strScanToOpenLabel;
var public localized String m_strTooltipClosedMarket;
var public localized String m_strTooltipOpenMarket;

var UIScanButton ScanButton;

simulated function UIStrategyMapItem InitMapItem(out XComGameState_GeoscapeEntity Entity)
{
	// Spawn the children BEFORE the super.Init because inside that super, it will trigger UpdateFlyoverText and other functions
	// which may assume these children already exist. 
	
	super.InitMapItem(Entity);

	ScanButton = Spawn(class'UIScanButton', self).InitScanButton();
	ScanButton.SetX(25); //This location is to stop overlapping 3D art.
	ScanButton.SetY(-30);
	ScanButton.SetButtonIcon("");
	ScanButton.SetDefaultDelegate(OnDefaultClicked);
	ScanButton.SetFactionDelegate(OnFactionClicked);
	ScanButton.SetButtonType(eUIScanButtonType_BlackMarket);
	ScanButton.OnSizeRealized = OnButtonSizeRealized;

	return self;
}
simulated function OnButtonSizeRealized()
{
	ScanButton.SetX(-ScanButton.Width / 2.0);
}

function UpdateFromGeoscapeEntity(const out XComGameState_GeoscapeEntity GeoscapeEntity)
{
	local XComGameState_BlackMarket BlackMarketState;
	local string ScanTitle;
	local string ScanTimeValue;
	local string ScanTimeLabel;
	local string ScanInfo;
	local int DaysRemaining;

	if( !bIsInited ) return; 

	super.UpdateFromGeoscapeEntity(GeoscapeEntity);

	if (IsAvengerLandedHere())
		ScanButton.Expand();
	else
		ScanButton.DefaultState();

	BlackMarketState = GetBlackMarket();
	
	ScanTitle = GetBlackMarketTitle();

	if (!BlackMarketState.bIsOpen)
	{
		DaysRemaining = BlackMarketState.GetNumScanDaysRemaining();
		ScanTimeValue = string(DaysRemaining);
		ScanTimeLabel = class'UIUtilities_Text'.static.GetDaysString(DaysRemaining);
		ScanInfo = m_strScanToOpenLabel;
		ScanButton.AnimateIcon(`GAME.GetGeoscape().IsScanning() && IsAvengerLandedHere());
		ScanButton.SetScanMeter(BlackMarketState.GetScanPercentComplete());
		ScanButton.SetButtonIcon("");
		ScanButton.ShowScanIcon(true);
	}
	else
	{
		ScanButton.SetButtonIcon(class'UIUtilities_Image'.const.MissionIcon_BlackMarket);
		ScanButton.ShowScanIcon(false);
	}

	ScanButton.SetText(ScanTitle, ScanInfo, ScanTimeValue, ScanTimeLabel);
	ScanButton.Realize();
}

function OnDefaultClicked()
{
	GetBlackMarket().AttemptSelectionCheckInterruption();
}

function OnFactionClicked()
{
	if( Movie.Pres.ScreenStack.GetScreen(class'UIBlackMarket') == none )
		GetBlackMarket().DisplayBlackMarket();
}

simulated function XComGameState_BlackMarket GetBlackMarket()
{
	return XComGameState_BlackMarket(`XCOMHISTORY.GetGameStateForObjectID(GeoscapeEntityRef.ObjectID));
}

function string GetBlackMarketTitle()
{
	return (MapPin_Header);
}

function GenerateTooltip(string tooltipHTML)
{
	super.GenerateTooltip(GetTooltipText());
	Movie.Pres.m_kTooltipMgr.TextTooltip.SetMouseDelegates(CachedTooltipID, RefreshTooltip);
}

function string GetTooltipText()
{
	return (GetBlackMarket().bIsOpen) ? m_strTooltipOpenMarket : m_strTooltipClosedMarket;
}
function RefreshTooltip(UITooltip refToThisTooltip)
{
	UITextTooltip(refToThisTooltip).SetText(GetTooltipText());
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
			if (GetBlackMarket().bIsOpen)
			{
				OnFactionClicked();
			}
			else
			{
				ScanButton.ClickButtonScan();
			}
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

	ScanButton.SetY(70.0 * (1.0 - FClamp(ZoomLevel, 0.0, 0.95)));
}
defaultproperties
{
	bProcessesMouseEvents = false; 
}