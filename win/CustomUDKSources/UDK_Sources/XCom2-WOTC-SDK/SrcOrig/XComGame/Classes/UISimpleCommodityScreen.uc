class UISimpleCommodityScreen extends UIInventory;

var array<Commodity>		arrItems;
var int						iSelectedItem;
var array<StateObjectReference> m_arrRefs;

var bool		m_bShowButton;
var bool		m_bInfoOnly;
var EUIState	m_eMainColor;
var EUIConfirmButtonStyle m_eStyle;
var int ConfirmButtonX;
var int ConfirmButtonY;

var public localized String m_strBuy;

simulated function OnPurchaseClicked(UIList kList, int itemIndex)
{
	// Implement in subclasses
}

simulated function GetItems()
{
	// Implement in subclasses
}

//-------------- UI LAYOUT --------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// Move and resize list to accommodate label
	List.OnItemDoubleClicked = OnPurchaseClicked;

	SetBuiltLabel("");

	GetItems();

	SetChooseResearchLayout();
	PopulateData();
	UpdateNavHelp(); // bsg-jrebar (4/20/17): Update on Init instead of receive focus
}

simulated function PopulateData()
{
	local Commodity Template;
	local int i;

	List.ClearItems();
	PopulateItemCard();
	
	for(i = 0; i < arrItems.Length; i++)
	{
		Template = arrItems[i];
		if(i < m_arrRefs.Length)
		{
			Spawn(class'UIInventory_ListItem', List.itemContainer).InitInventoryListCommodity(Template, m_arrRefs[i], GetButtonString(i), m_eStyle, ConfirmButtonX, ConfirmButtonY);
		}
		else
		{
			Spawn(class'UIInventory_ListItem', List.itemContainer).InitInventoryListCommodity(Template, , GetButtonString(i), m_eStyle, ConfirmButtonX, ConfirmButtonY);
		}
	}

	if(List.ItemCount > 0)
	{
		List.SetSelectedIndex(0);
		if( bUseSimpleCard )
			PopulateSimpleCommodityCard(UIInventory_ListItem(List.GetItem(0)).ItemComodity, UIInventory_ListItem(List.GetItem(0)).ItemRef);
		else
			PopulateResearchCard(UIInventory_ListItem(List.GetItem(0)).ItemComodity, UIInventory_ListItem(List.GetItem(0)).ItemRef);

		List.Navigator.SetSelected(List.GetItem(0));
	}

	if(List.ItemCount == 0 && m_strEmptyListTitle != "")
	{
		TitleHeader.SetText(m_strTitle, m_strEmptyListTitle);
		SetCategory("");
	}
}

simulated function int GetItemIndex(Commodity Item)
{
	local int i;

	for(i = 0; i < arrItems.Length; i++)
	{
		if(arrItems[i] == Item)
		{
			return i;
		}
	}

	return -1;
}

//-------------- GAME DATA HOOKUP --------------------------------------------------------
//simulated function String GetItemString(int ItemIndex)
//{
//	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
//	{
//		return arrItems[ItemIndex].Title;
//	}
//	else
//	{
//		return "";
//	}
//}

//simulated function String GetItemImage(int ItemIndex)
//{
//	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
//	{
//		return arrItems[ItemIndex].Image;
//	}
//	else
//	{
//		return "";
//	}
//}

//simulated function String GetItemCostString(int ItemIndex)
//{
//	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
//	{
//		return class'UIUtilities_Strategy'.static.GetStrategyCostString(arrItems[ItemIndex].Cost, arrItems[ItemIndex].CostScalars);
//	}
//	else
//	{
//		return "";
//	}
//}

//simulated function String GetItemReqString(int ItemIndex)
//{
//	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
//	{
//		return class'UIUtilities_Strategy'.static.GetStrategyReqString(arrItems[ItemIndex].Requirements);
//	}
//	else
//	{
//		return "";
//	}
//}

//simulated function String GetItemDurationString(int ItemIndex)
//{
//	if (ItemIndex > -1 && ItemIndex < arrItems.Length)
//	{
//		return class'UIUtilities_Text'.static.GetTimeRemainingString(arrItems[ItemIndex].OrderHours);
//	}
//	else
//	{
//		return "";
//	}
//}

//simulated function String GetItemDescString(int ItemIndex)
//{
//	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
//	{
//		return arrItems[ItemIndex].Desc;
//	}
//	else
//	{
//		return "";
//	}
//}

simulated function bool NeedsAttention(int ItemIndex)
{
	// Implement in subclasses
	return false;
}
simulated function bool ShouldShowGoodState(int ItemIndex)
{
	// Implement in subclasses
	return false;
}

simulated function bool CanAffordItem(int ItemIndex)
{
	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
	{
		return XComHQ.CanAffordCommodity(arrItems[ItemIndex]);
	}
	else
	{
		return false;
	}
}

simulated function bool MeetsItemReqs(int ItemIndex)
{
	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
	{
		return XComHQ.MeetsCommodityRequirements(arrItems[ItemIndex]);
	}
	else
	{
		return false;
	}
}

simulated function bool IsItemPurchased(int ItemIndex)
{
	// Implement in subclasses
	return false;
}
//simulated function bool ShouldShowCostPanel()
//{
//	return !IsInfoOnly() && GetItemCostString(iSelectedItem) != "";
//}
//
//simulated function bool ShouldShowReqPanel()
//{
//	return !IsInfoOnly() && GetItemReqString(iSelectedItem) != "";
//}
//
//simulated function bool ShouldShowDurationPanel()
//{
//	return !IsInfoOnly() && arrItems[iSelectedItem].OrderHours > 0;
//}

//simulated function EUIState GetDurationColor(int ItemIndex)
//{
//	return eUIState_Good;
//}

//simulated function bool HasButton()
//{
//	return m_bShowButton;
//}

simulated function String GetButtonString(int ItemIndex)
{
	return m_strBuy;
}

//simulated function EUIState GetMainColor()
//{
//	return m_eMainColor;
//}

//simulated function bool IsInfoOnly()
//{
//	return m_bInfoOnly;
//}

// bsg-jrebar (4/20/17): Override Inventory versions to look if can afford before select
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repeats only occur with arrow keys

	bHandled = super.OnUnrealCommand(cmd, arg);

	if (bHandled)
	{
		if (List.GetSelectedItem() != none)
			iSelectedItem = List.GetItemIndex(List.GetSelectedItem());
	}
	else
	{
		if (`ISCONTROLLERACTIVE && CanAffordItem(iSelectedItem) && !IsItemPurchased(iSelectedItem))
		{
			switch (cmd)
			{
			case class'UIUtilities_Input'.const.FXS_BUTTON_A :
				OnPurchaseClicked(List, iSelectedItem);
				bHandled = true;
				break;
			}
		}
	}

	return bHandled;
}

simulated function UpdateNavHelp()
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;

	NavHelp.ClearButtonHelp();
	NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
	NavHelp.AddBackButton(CloseScreen);

	if(`ISCONTROLLERACTIVE && CanAffordItem(iSelectedItem) && !IsItemPurchased(iSelectedItem))
	{
		NavHelp.AddSelectNavHelp();
	}
}

simulated function PlayNegativeSound()
{
	if(!`ISCONTROLLERACTIVE)
			class'UIUtilities_Sound'.static.PlayNegativeSound();
}
// bsg-jrebar (4/20/17): end

defaultproperties
{
	bAutoSelectFirstNavigable = false
	m_bShowButton = true
	m_bInfoOnly = false
	m_eMainColor = eUIState_Normal
	m_eStyle = eUIConfirmButtonStyle_Default //word button
	ConfirmButtonX = 12
}	ConfirmButtonY = 0