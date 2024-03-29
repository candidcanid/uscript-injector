/**
 * Copyright 1998-2011 Epic Games, Inc. All Rights Reserved.
 */
class Prefab extends Object
	native(Prefab);

/** Version number of this prefab. */
var() editconst const int						PrefabVersion; // FIRAXIS jboswell

/** Array of archetypes, one for each object in the prefab. */
var() editconst	const array<Object>				PrefabArchetypes; // FIRAXIS jboswell

/** Array of archetypes that used to be in this Prefab, but no longer are. */
var() const array<Object>				RemovedArchetypes; // FIRAXIS jboswell

/** The Kismet sequence that associated with this Prefab. */
var		const PrefabSequence			PrefabSequence;

/** Snapshot of Prefab used for thumbnail in the browser. */
var		editoronly const Texture2D		PrefabPreview;

// FIRAXIS BEGIN jboswell
var(Object) name Tag;
// FIRAXIS END

cpptext
{
	// UObject interface

	/**
	 * Returns a one line description of an object for viewing in the thumbnail view of the generic browser
	 */
	virtual FString GetDesc();

	/**
	 * Called after the data for this prefab has been loaded from disk.  Removes any NULL elements from the PrefabArchetypes array.
	 */
	virtual void PostLoad();

	// Prefab interface
	/**
	 * Fixes up object references within a group of archetypes.  For any references which refer
	 * to an actor from the original set, replaces that reference with a reference to the archetype
	 * class itself.
	 *
	 * @param	ArchetypeBaseMap	map of original actor instances to archetypes
	 * @param	bNullPrivateRefs	should we null references to any private objects
	 */
	static void ResolveInterDependencies( TMap<UObject*,UObject*>& ArchetypeBaseMap, UBOOL bNullPrivateRefs );

	/** Utility for copying a USequence from the level into a Prefab in a package, including fixing up references. */
	void CopySequenceIntoPrefab(USequence* InPrefabSeq, TMap<UObject*,UObject*>& InstanceToArchetypeMap);
}
