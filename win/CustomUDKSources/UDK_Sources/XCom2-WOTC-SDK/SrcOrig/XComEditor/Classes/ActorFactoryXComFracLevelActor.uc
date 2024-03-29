class ActorFactoryXComFracLevelActor extends ActorFactoryFracturedStaticMesh
	native;

cpptext
{
	virtual AActor* CreateActor( const FVector* const Location, const FRotator* const Rotation, const class USeqAct_ActorFactory* const ActorFactoryData );
	virtual void AutoFillFields(USelection* Selection);
	virtual FString GetMenuName();
	virtual UBOOL CanCreateActor(FString& OutErrorMsg, UBOOL bFromAssetOnly = FALSE );
	virtual void PostReplaceActor(AActor *OldActor, AActor *NewActor);
}

defaultproperties
{
	MenuName="Add XComFracLevelActor"
	NewActorClass=class'XComGame.XComFracLevelActor'
}
