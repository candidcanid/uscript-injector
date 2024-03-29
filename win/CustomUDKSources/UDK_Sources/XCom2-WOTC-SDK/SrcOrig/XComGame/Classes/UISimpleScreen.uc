class UISimpleScreen extends UIScreen;

enum ERectAnchor
{
	eRectAnchor_TopLeft,
	eRectAnchor_TopCenter,
	eRectAnchor_TopRight,
	eRectAnchor_CenterLeft,
	eRectAnchor_Center,
	eRectAnchor_CenterRight,
	eRectAnchor_BottomLeft,
	eRectAnchor_BottomCenter,
	eRectAnchor_BottomRight,
};

var localized String m_strBack;
var localized String m_strContinue;
var localized String m_strOK;
var localized String m_strAccept;
var localized String m_strCancel;
var localized String m_strIgnore;
var localized String m_strNotNow;
var localized String m_strTellMeMore;

delegate OnClickedDelegate(UIButton Button);
delegate ActionCallback(Name eAction);
delegate OnItemSelectedCallback(UIList listControl, int itemIndex);

//-------------- HELPER FUNCS --------------------------------------------------------
simulated function UIBGBox AddBG(TRect rPos, EUIState eUIStateColor, optional name InitName, optional UIPanel Parent)
{
	local UIBGBox BGBox;

	BGBox = Spawn(class'UIBGBox', (Parent != none ? Parent : self)).InitBG(InitName, rPos.fLeft, rPos.fTop, RectWidth(rPos), RectHeight(rPos));
	BGBox.SetBGColorState(eUIStateColor);
	BGBox.SetAlpha(0.8f);

	return BGBox;
}

simulated function UIBGBox UpdateBG(name InitName, EUIState eUIStateColor)
{
	local UIBGBox BGBox;

	BGBox = UIBGBox(GetChildByName(InitName));

	if( BGBox != none )
	{
		BGBox.SetBGColorState(eUIStateColor);
	}

	return BGBox;
}

simulated function UIPanel AddFullscreenBG(optional float fAlpha = 0.5f)
{
	local UIPanel Panel;

	Panel = Spawn(class'UIPanel', self).InitPanel('ScreenBG', class'UIUtilities_Controls'.const.MC_GenericPixel);
	Panel.SetPosition(-200, -200).SetSize(2500, 1500);
	Panel.SetColor(class'UIUtilities_Colors'.static.LinearColorToFlashHex(MakeLinearColor(0, 0, 0, fAlpha)));
	Panel.SetAlpha(fAlpha);

	return Panel;
}

simulated function UIPanel AddFillRect(TRect rPos, LinearColor clrPanel, optional name InitName, optional UIPanel Parent)
{
	local UIPanel Panel;

	Panel = Spawn(class'UIPanel', (Parent != none ? Parent : self)).InitPanel(InitName, class'UIUtilities_Controls'.const.MC_GenericPixel);
	Panel.SetPosition(rPos.fLeft, rPos.fTop).SetSize(RectWidth(rPos), RectHeight(rPos));
	Panel.SetColor(class'UIUtilities_Colors'.static.LinearColorToFlashHex(clrPanel));
	Panel.SetAlpha(clrPanel.A);

	return Panel;
}

simulated function UIPanel UpdateFillRect(name InitName, LinearColor clrPanel)
{
	local UIPanel Panel;

	Panel = GetChildByName(InitName);
	if( Panel != none )
	{
		Panel.SetColor(class'UIUtilities_Colors'.static.LinearColorToFlashHex(clrPanel));
		Panel.SetAlpha(clrPanel.A);
	}

	return Panel;
}

simulated function UIX2PanelHeader AddHeader(TRect rPos, String strTitle, LinearColor clrHeader, optional String strLabel, optional name InitName, optional UIPanel Parent)
{
	local UIX2PanelHeader Header;
	Header = Spawn(class'UIX2PanelHeader', (Parent != none ? Parent : self));
	Header.InitPanelHeader(InitName, strTitle, strLabel);
	Header.SetHeaderWidth(RectWidth(rPos));
	Header.SetPosition(rPos.fLeft, rPos.fTop);
	Header.SetColor(class'UIUtilities_Colors'.static.LinearColorToFlashHex(clrHeader));
	Header.SetAlpha(clrHeader.A);

	return Header;
}

simulated function UIImage AddImage(TRect rPos, String ImagePath, optional EUIState eBorderColor, optional name InitName, optional UIPanel Parent)
{
	local UIImage Image;

	AddBG(rPos, eBorderColor);
	rPos = PadRect(rPos, 2);
	Image = Spawn(class'UIImage', (Parent != none ? Parent : self)).InitImage(InitName, ImagePath);
	Image.SetPosition(rPos.fLeft, rPos.fTop).SetSize(RectWidth(rPos), RectHeight(rPos));

	return Image;
}

simulated function UIImage AddImageNoBG(TRect rPos, String ImagePath, optional name InitName, optional UIPanel Parent)
{
	local UIImage Image;

	rPos = PadRect(rPos, 2);
	Image = Spawn(class'UIImage', (Parent != none ? Parent : self)).InitImage(InitName, ImagePath);
	Image.SetPosition(rPos.fLeft, rPos.fTop).SetSize(RectWidth(rPos), RectHeight(rPos));

	return Image;
}

simulated function UIImage UpdateImage(name InitName, String ImagePath)
{
	local UIImage Image;

	Image = UIImage(GetChildByName(InitName));

	if( Image != none )
	{
		Image.LoadImage(ImagePath);
	}
	
	return Image;
}

simulated function UIText AddText(TRect rPos, String strText, optional name InitName, optional UIPanel Parent)
{
	local UIText TextWidget;

	TextWidget = Spawn(class'UIText', (Parent != none ? Parent : self)).InitText(InitName, class'UIUtilities_Text'.static.GetColoredText(strText, eUIState_Normal, 25));
	TextWidget.SetPosition(rPos.fLeft, rPos.fTop).SetSize(RectWidth(rPos), RectHeight(rPos));
	TextWidget.SetHtmlText(class'UIUtilities_Text'.static.AlignCenter(TextWidget.Text));

	return TextWidget;
}
simulated function UIText AddUncenteredText(TRect rPos, String strText, optional name InitName, optional UIPanel Parent)
{
	local UIText TextWidget;

	TextWidget = Spawn(class'UIText', (Parent != none ? Parent : self)).InitText(InitName, class'UIUtilities_Text'.static.GetColoredText(strText, eUIState_Normal, 25));
	TextWidget.SetPosition(rPos.fLeft, rPos.fTop).SetSize(RectWidth(rPos), RectHeight(rPos));

	return TextWidget;
}
simulated function UIText UpdateText(name InitName, String strText)
{
	local UIText TextWidget;

	TextWidget = UIText(GetChildByName(InitName));
	if( TextWidget != none )
	{
		TextWidget.SetText(class'UIUtilities_Text'.static.GetColoredText(strText, eUIState_Normal, 25));
		TextWidget.SetHtmlText(class'UIUtilities_Text'.static.AlignCenter(TextWidget.Text));
	}

	return TextWidget;
}

simulated function UIText AddTitle(TRect rPos, String strText, EUIState ColorState, int FontSize, optional name InitName, optional UIPanel Parent)
{
	local UIText TextWidget;

	TextWidget = Spawn(class'UIText', (Parent != none ? Parent : self)).InitText(InitName, class'UIUtilities_Text'.static.GetColoredText(strText, ColorState, FontSize), true);
	TextWidget.SetPosition(rPos.fLeft, rPos.fTop).SetSize(RectWidth(rPos), RectHeight(rPos));
	TextWidget.SetHtmlText(class'UIUtilities_Text'.static.AlignCenter(TextWidget.Text));

	return TextWidget;
}

simulated function UIText AddUncenteredTitle(TRect rPos, String strText, EUIState ColorState, int FontSize, optional name InitName, optional UIPanel Parent)
{
	local UIText TextWidget;

	TextWidget = Spawn(class'UIText', (Parent != none ? Parent : self)).InitText(InitName, class'UIUtilities_Text'.static.GetColoredText(strText, ColorState, FontSize), true);
	TextWidget.SetPosition(rPos.fLeft, rPos.fTop).SetSize(RectWidth(rPos), RectHeight(rPos));

	return TextWidget;
}

simulated function UIText UpdateTitle(name InitName, String strText, EUIState ColorState, int FontSize, optional bool bUncentered = false)
{
	local UIText TextWidget;

	TextWidget = UIText(GetChildByName(InitName));

	if( TextWidget != none )
	{
		TextWidget.SetText(class'UIUtilities_Text'.static.GetColoredText(strText, ColorState, FontSize));

		if(!bUncentered)
		{
			TextWidget.SetHtmlText(class'UIUtilities_Text'.static.AlignCenter(TextWidget.Text));
		}
	}

	return TextWidget;
}

simulated function UIButton AddButton(TRect rPos, String strText, delegate<OnClickedDelegate> OnClicked, optional name InitName, optional UIPanel Parent)
{
	local UIButton Button;

	Button = Spawn(class'UIButton', (Parent != none ? Parent : self)).InitButton(InitName, class'UIUtilities_Text'.static.GetSizedText(strText, 25), OnClicked, eUIButtonStyle_HOTLINK_BUTTON);
	rPos = HSubRect(rPos, 0.25f, 0.75f);
	Button.SetPosition(rPos.fLeft, rPos.fTop);

	return Button;
}

simulated function UIList AddList(TRect rPos, String strTitle, delegate<OnItemSelectedCallback> OnClicked, optional name InitName, optional UIPanel Parent)
{
	local UIList List;
	local TRect rTitle;

	List = Spawn(class'UIList', (Parent != none ? Parent : self)).InitList(InitName, rPos.fLeft, rPos.fTop, RectWidth(rPos), RectHeight(rPos));
	List.ItemPadding = 10;
	List.OnItemClicked = OnClicked;

	rTitle = MakeRect(rPos.fLeft, rPos.fTop - 40, RectWidth(rPos)*0.75, 40);
	AddTitle(rTitle, strTitle, eUIState_Normal, 30);

	return List;
}

simulated function AddListItem(UIList List, String strText, optional String strCost, optional String strReq, optional bool bMeetsReqs, optional bool bCanAfford, optional bool bIsPurchased)
{
	UISimpleListItem(List.CreateItem(class'UISimpleListItem')).InitListItem(strText, List.Width, 50, strCost, strReq, bMeetsReqs, bCanAfford, bIsPurchased);
}

simulated function AddBackButton()
{
	local TRect rBack;
	// Back
	rBack = AnchorRect(MakeRect(0, 0, 50, 20), eRectAnchor_BottomLeft, 25);
	AddButton(rBack, m_strBack, OnBackClicked);
}

simulated function OnBackClicked(UIButton button)
{
	CloseScreen();
	class'UIUtilities_Sound'.static.PlayCloseSound();
}
simulated function PlayOpenSound()
{
	class'UIUtilities_Sound'.static.PlayOpenSound();
}
simulated function PlayCloseSound()
{
	class'UIUtilities_Sound'.static.PlayCloseSound();
}
simulated function PlayNegativeSound()
{
	class'UIUtilities_Sound'.static.PlayNegativeSound();
}

simulated function String ColorString(String InString, EUIState eColor)
{
	return class'UIUtilities_Text'.static.GetColoredText(InString, eColor);
}

simulated function AddLineBreak(out String BodyString)
{
	BodyString $= "\n";
}

simulated function AddLine(out String BodyString, String AddString)
{
	BodyString $= AddString;
	BodyString $= "\n";
}

simulated function TRect MakeRect(float fLeft, float fTop, float fWidth, float fHeight)
{
	local TRect Rect;

	Rect.fLeft = fLeft;
	Rect.fTop = fTop;
	Rect.fRight = fLeft + fWidth;
	Rect.fBottom = fTop + fHeight;

	return Rect;
}

simulated function TRect PadRect(TRect InRect, float fPadding)
{
	local TRect Rect;

	Rect.fLeft = InRect.fLeft + fPadding;
	Rect.fTop = InRect.fTop + fPadding;
	Rect.fRight = InRect.fRight - fPadding;
	Rect.fBottom = InRect.fBottom - fPadding;

	return Rect;
}

simulated function TRect HSubRect(TRect InRect, float fPercentLeft, float fPercentRight)
{
	local TRect Rect;

	Rect.fTop = InRect.fTop;
	Rect.fBottom = InRect.fBottom;

	Rect.fLeft = InRect.fLeft + RectWidth(InRect) * fPercentLeft;
	Rect.fRight = InRect.fLeft + RectWidth(InRect) * fPercentRight;

	return Rect;
}

simulated function TRect VSubRect(TRect InRect, float fPercentTop, float fPercentBottom)
{
	local TRect Rect;

	Rect.fLeft = InRect.fLeft;
	Rect.fRight = InRect.fRight;

	Rect.fTop = InRect.fTop + RectHeight(InRect) * fPercentTop;
	Rect.fBottom = InRect.fTop + RectHeight(InRect) * fPercentBottom;

	return Rect;
}

simulated function TRect VSubRectPixels(TRect InRect, float fPercentTop, int iPixelHeight)
{
	local TRect Rect;

	Rect.fLeft = InRect.fLeft;
	Rect.fRight = InRect.fRight;

	Rect.fTop = InRect.fTop + RectHeight(InRect) * fPercentTop;
	Rect.fBottom = Rect.fTop + iPixelHeight;

	return Rect;
}

simulated function TRect HSubRectPixels(TRect InRect, float fPercentLeft, int iPixelWidth)
{
	local TRect Rect;

	Rect.fTop = InRect.fTop;
	Rect.fBottom = InRect.fBottom;

	Rect.fLeft = InRect.fLeft + RectWidth(InRect) * fPercentLeft;
	Rect.fRight = Rect.fLeft + iPixelWidth;

	return Rect;
}

simulated function TRect SubRect(TRect InRect, float fPercentLeft, float fPercentTop, float fPercentRight, float fPercentBottom)
{
	local TRect Rect;

	Rect.fLeft = InRect.fLeft + RectWidth(InRect) * fPercentLeft;
	Rect.fTop = InRect.fTop + RectHeight(InRect) * fPercentTop;
	Rect.fRight = InRect.fLeft + RectWidth(InRect) * fPercentRight;
	Rect.fBottom = InRect.fTop + RectHeight(InRect) * fPercentBottom;

	return Rect;
}

// Create an exact copy placed immediately below
simulated function TRect VCopyRect(TRect InRect, optional int iPixelOffset, optional int iNewHeight = -1)
{
	local TRect Rect;
	local int iHeight;

	iHeight = iNewHeight == -1 ? int(RectHeight(InRect)) : iNewHeight;

	Rect = InRect;

	Rect.fTop = InRect.fBottom + iPixelOffset;
	Rect.fBottom = Rect.fTop + iHeight;

	return Rect;
}

// Create an exact copy placed immediately to the right
simulated function TRect HCopyRect(TRect InRect, optional int iPixelOffset, optional int iNewWidth = -1)
{
	local TRect Rect;
	local int iWidth;

	iWidth = iNewWidth == -1 ? int(RectWidth(InRect)) : iNewWidth;

	Rect = InRect;

	Rect.fLeft = InRect.fRight + iPixelOffset;
	Rect.fRight = Rect.fLeft + iWidth;

	return Rect;
}

simulated function TRect AnchorRect(TRect InRect, ERectAnchor eAnchor, optional int Padding)
{
	local TRect Rect;

	Rect = InRect;

	switch(eAnchor)
	{
	case eRectAnchor_CenterLeft:
	case eRectAnchor_TopLeft:
	case eRectAnchor_BottomLeft:
		Rect.fLeft = 0 + Padding;
		break;
	case eRectAnchor_Center:
	case eRectAnchor_TopCenter:
	case eRectAnchor_BottomCenter:
		Rect.fLeft = 1920 / 2 - RectWidth(InRect) / 2;
		break;
	case eRectAnchor_CenterRight:
	case eRectAnchor_TopRight:
	case eRectAnchor_BottomRight:
		Rect.fLeft = 1920 - (RectWidth(InRect) + Padding);
		break;
	}

	Rect.fRight = Rect.fLeft + RectWidth(InRect);

	switch(eAnchor)
	{
	case eRectAnchor_TopLeft:
	case eRectAnchor_TopCenter:
	case eRectAnchor_TopRight:
		Rect.fTop = 0 + Padding;
		break;
	case eRectAnchor_CenterLeft:
	case eRectAnchor_Center:
	case eRectAnchor_CenterRight:
		Rect.fTop = 1080 / 2 - RectHeight(InRect) / 2;
		break;
	case eRectAnchor_BottomLeft:
	case eRectAnchor_BottomCenter:
	case eRectAnchor_BottomRight:
		Rect.fTop = 1080 - (RectHeight(InRect) + Padding);
		break;
	}

	Rect.fBottom = Rect.fTop + RectHeight(InRect);

	return Rect;
}

simulated function float RectWidth(TRect Rect, optional float fPercent = 1.0f)
{
	return (Rect.fRight - Rect.fLeft) * fPercent;
}

simulated function float RectHeight(TRect Rect, optional float fPercent = 1.0f)
{
	return (Rect.fBottom - Rect.fTop) * fPercent;
}

simulated function AddThresholdBar(TRect rPanel, int iTotal, int iFilled, LinearColor clrBar, optional name InitName)
{
	local int i;
	local float fSegmentPct;
	local TRect rSegment;

	fSegmentPct = 1.0f / iTotal;

	for( i = 0; i < iTotal; i++ )
	{
		rSegment = PadRect(HSubRect(rPanel, i*fSegmentPct, (i + 1)*fSegmentPct), 5);
		clrBar.A = i < iFilled ? 1.0f : 0.2f;

		AddFillRect(rSegment, clrBar, name(String(InitName)$"ThresholdBar"$i));
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if(!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	bHandled = true;

	switch(cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A:
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
		//TODO: Selection + Confirmation 
		bHandled = false;
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
		CloseScreen();
		break;
	default:
		bHandled = false;
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

//==============================================================================

defaultproperties
{
	InputState = eInputState_Consume;
}
