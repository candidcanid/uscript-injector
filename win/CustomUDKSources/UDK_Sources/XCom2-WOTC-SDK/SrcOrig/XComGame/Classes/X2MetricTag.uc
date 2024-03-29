//---------------------------------------------------------------------------------------
//  FILE:    X2MetricTag.uc
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2MetricTag extends XGLocalizeTag
	native(Core);

native function bool Expand(string InString, out string OutString);

event ExpandHandler(string InString, out string OutString)
{
	local XComGameState_Analytics Analytics;

	Analytics = XComGameState_Analytics(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_Analytics'));
	OutString = Analytics.GetValueAsString(InString);
}

DefaultProperties
{
	Tag = "Metric";
}
