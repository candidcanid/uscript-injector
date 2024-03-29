/**********************************************************************

Filename    :   GFxFSCmdHandler.uc
Content     :   Unreal Scaleform GFx integration

Copyright   :   (c) 2006-2007 Scaleform Corp. All Rights Reserved.

Portions of the integration code is from Epic Games as identified by Perforce annotations.
Copyright 2010 Epic Games, Inc. All rights reserved.

Notes       :   Since 'ucc' will prefix all class names with 'U'
                there is not conflict with GFx file / class naming.

Licensees may use this file in accordance with the valid Scaleform
Commercial License Agreement provided with the software.

This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING 
THE WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR ANY PURPOSE.

GFxFSCmdHandler handles fscommand() calls from ActionScript, calling the 
FSCommand script event.
**********************************************************************/

class GFxFSCmdHandler extends Object
    native abstract;
   
/** 
  * Called when receive an fscommand() call from ActionScript
  * @PARAM movie:  The movie which generated the fscommand().
  * @PARAM cmd:  The command
  * @PARAM Arg:  The arguments
  */
event bool FSCommand(GFxMoviePlayer movie, GFxEvent_FSCommand Event, string cmd, string Arg);