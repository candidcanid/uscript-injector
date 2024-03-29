/*******************************************************************************
 * XGBaseEntity generated by Eliot.UELib using UE Explorer.
 * Eliot.UELib ? 2009-2015 Eliot van Uytfanghe. All rights reserved.
 * http://eliotvu.com
 *
 * All rights belong to their respective owners.
 *******************************************************************************/
class XGBaseEntity extends XGEntity;

enum EBaseModel
{
    eBaseModel_HQ,
    eBaseModel_Outpost,
    eBaseModel_MAX
};

enum EBaseAnimation
{
    eBaseAnim_Appearing,
    eBaseAnim_Idle,
    eBaseAnim_MAX
};

function Vector2D GetCoords(){}
function bool IsHQ(){}
function EBaseModel GetBaseModel(){}
function EBaseAnimation GetAnim(){}

defaultproperties
{
}