//-----------------------------------------------------------
// Used by the visualizer system to control a Visualization Actor
//-----------------------------------------------------------
class X2Action_MoveClimbWall extends X2Action_Move;

var vector  Source;

function Init()
{
	super.Init();
	PathTileIndex = FindPathTileIndex();
}

function ParsePathSetParameters(int InPathIndex, const out vector InDestination, const out vector InSource, float InDistance)
{
	PathIndex = InPathIndex;	
	Destination = InDestination;
	Source = InSource;
	Distance = InDistance;
}

simulated state Executing
{
Begin:

	CompleteAction();
}

DefaultProperties
{
}
