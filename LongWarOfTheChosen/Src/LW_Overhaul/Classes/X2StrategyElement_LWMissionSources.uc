//---------------------------------------------------------------------------------------
//  FILE:    X2StrategyElement_LWMissionSources.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//  PURPOSE: Defines new categories of mission sources to be generated by the Overhaul AlienActivity system
//---------------------------------------------------------------------------------------
class X2StrategyElement_LWMissionSources extends X2StrategyElement config(LW_Overhaul);

struct MissionTypeSitRepExclusions
{
	var string MissionType;
	var array<string> SitRepNames;
};

struct SitRepChance
{
	var name SitRepName;
	var float Chance;    // 0.0 - 1.0 (percentage chance)
	var int Priority;       // Used for sorting, lower number == earlier in the array
};

// LWOTC: Base chance for a mission to have a sit rep
var config float SIT_REP_CHANCE;
var config float DARK_EVENT_SIT_REP_CHANCE;
var config int NUM_SITREPS_TO_ROLL; // allow configuring the number of additional sitreps to roll (assuming you can roll other sitreps)
var config int NUM_DARK_EVENT_SITREPS_TO_ROLL; // allow configuring the number of DE  sitreps to roll.
var config bool ROLL_ADITIONAL_SITREPS_WITH_SPECIAL_SITREP; //allow rolling additional sitreps even if a special sitrep is rolled.

// Special sit reps that are rolled separately from the standard mechanism
// to ensure that they occur more frequently than they would otherwise do.
var config array<SitRepChance> SPECIAL_SIT_REPS;

// LWOTC: Prevent certain sit reps on various mission types. A sit rep of
// '*' means "all sit reps".
var config array<MissionTypeSitRepExclusions> MISSION_TYPE_SIT_REP_EXCLUSIONS;

var const array<name> AlienRulerSitRepNames;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> MissionSources;

	MissionSources.AddItem(CreateGenericMissionSourceTemplate());

	return MissionSources;
}

static function X2DataTemplate CreateGenericMissionSourceTemplate()
{
	local X2MissionSourceTemplate Template;
	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_LWSGenericMissionSource');
	Template.bShowRewardOnPin = true;
	Template.bSkipRewardsRecap = true;
	Template.bDisconnectRegionOnFail = false;
	Template.OnSuccessFn = GenericMissionSourceOnSuccess;
	Template.OnFailureFn = GenericMissionSourceOnFailure;
	Template.OnExpireFn = GenericMissionSourceOnExpire; // shouldn't need this, since missions won't expire in base-game manner and call this
	//Template.MissionImage = "img:///UILibrary_StrategyImages.X2StrategyMap.Alert_Supply_Raid"; // mission image now drawn from activity
	Template.GetMissionDifficultyFn = GenericGetMissionDifficulty;

	//Create and spawn aren't needed for these because missions are directly spawned out of the Alien Activity
	//Template.CreateMissionsFn = CreateGenericMissionSourceMission;
	//Template.SpawnMissionsFn = SpawnGenericMissionSourceMission;
	Template.MissionPopupFn = none; //popup drawn separately from activity
	Template.GetOverworldMeshPathFn = GetGenericMissionSourceOverworldMeshPath;
	Template.WasMissionSuccessfulFn = GenericWasMissionSuccessful;

	// LWOTC: Critical for allowing large numbers of enemies on missions!
	Template.bIgnoreDifficultyCap = true;

	Template.bBlockSitrepDisplay = false;
	Template.GetSitRepsFn = GetValidSitReps;
	return Template;
}

function bool GenericWasMissionSuccessful(XComGameState_BattleData BattleDataState)
{
	local XComGameStateHistory History;
	local XComGameState_MissionSite MissionState;
	local XComGameState_LWAlienActivity AlienActivity;

	History = `XCOMHISTORY;
	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleDataState.m_iMissionID));
	AlienActivity = class'XComGameState_LWAlienActivityManager'.static.FindAlienActivityByMission(MissionState);

	if(AlienActivity.GetMyTemplate().WasMissionSuccessfulFn != none)
		return AlienActivity.GetMyTemplate().WasMissionSuccessfulFn(AlienActivity, MissionState, BattleDataState);

	return (BattleDataState.OneStrategyObjectiveCompleted());
}

static function string GetGenericMissionSourceOverworldMeshPath(XComGameState_MissionSite MissionState)
{
	local XComGameState_LWAlienActivity AlienActivity;

	AlienActivity = class'XComGameState_LWAlienActivityManager'.static.FindAlienActivityByMission(MissionState);
	return AlienActivity.GetOverworldMeshPath(MissionState);
}

static function GenericMissionSourceOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_LWAlienActivity AlienActivity;

	AlienActivity = class'XComGameState_LWAlienActivityManager'.static.FindAlienActivityByMission(MissionState);
	if(AlienActivity.GetMyTemplate().OnMissionSuccessFn != none)
	{
		AlienActivity = XComGameState_LWAlienActivity(NewGameState.CreateStateObject(class'XComGameState_LWAlienActivity', AlienActivity.ObjectID));
		AlienActivity.GetMyTemplate().OnMissionSuccessFn(AlienActivity, MissionState, NewGameState);
	}
	SpawnPointOfInterest(NewGameState, MissionState);
}

static function GenericMissionSourceOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_LWAlienActivity AlienActivity;

	if (MissionState.POIToSpawn.ObjectID > 0)
	{
		class'XComGameState_HeadquartersResistance'.static.DeactivatePOI(NewGameState, MissionState.POIToSpawn);
	}
	AlienActivity = class'XComGameState_LWAlienActivityManager'.static.FindAlienActivityByMission(MissionState);
	if(AlienActivity.GetMyTemplate().OnMissionFailureFn != none)
	{
		AlienActivity = XComGameState_LWAlienActivity(NewGameState.CreateStateObject(class'XComGameState_LWAlienActivity', AlienActivity.ObjectID));
		AlienActivity.GetMyTemplate().OnMissionFailureFn(AlienActivity, MissionState, NewGameState);
	}
}

//this should never get called, but we'll keep it here just in case
static function GenericMissionSourceOnExpire(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_LWAlienActivity AlienActivity;

	AlienActivity = class'XComGameState_LWAlienActivityManager'.static.FindAlienActivityByMission(MissionState);
	if(AlienActivity.GetMyTemplate().OnMissionFailureFn != none)
	{
		AlienActivity = XComGameState_LWAlienActivity(NewGameState.CreateStateObject(class'XComGameState_LWAlienActivity', AlienActivity.ObjectID));
		AlienActivity.GetMyTemplate().OnMissionFailureFn(AlienActivity, MissionState, NewGameState);
		//AlienActivity.GetMyTemplate().OnMissionExpireFn(AlienActivity, MissionState, NewGameState);
	}
}

static function int GenericGetMissionDifficulty(XComGameState_MissionSite MissionState)
{
	return MissionState.SelectedMissionData.AlertLevel != 0 ? MissionState.SelectedMissionData.AlertLevel :
			class'XComGameState_LWAlienActivityManager'.static.GetMissionAlertLevel(MissionState);
}

//**********************************************
//---------        SIT REPS!          ----------
//**********************************************

// Implementation based on X2StrategyElement_DefaultMissionSources.GetSitrepsGeneric()
//
// Gets a list of sit reps that can be applied to the given mission. It checks for
// any dark events that are active that might add a sit rep and if there are, rolls
// for one of those (so you might get 0 or 1 dark event sit reps).
//
// Next, it checks a list of special, limited sit reps such as Alien-Ruler ones. This
// is used to typically handle sit reps with restrictions that mean the card manager
// approach rarely picks them.
//
// Finally, if no special sit rep has been selected, the function then does a standard
// roll for any other sit rep that's available using the standard card manager approach.
static function array<name> GetValidSitReps(XComGameState_MissionSite MissionState)
{
	local X2CardManager CardMgr;
	local X2SitRepTemplateManager SitRepMgr;
	local X2DataTemplate DataTemplate;
	local X2SitRepTemplate SitRepTemplate;
	local XComLWTuple ValidationData;
	local array<name> ActiveSitReps, ActiveSitRepDarkEvents;
	local string SitRepLabel;
	local name SitRepName;
	local bool AddMoreSitReps, ShouldApplySitreps;
	local int i,j;

	CardMgr = class'X2CardManager'.static.GetCardManager();
	SitRepMgr = class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager();
	ActiveSitReps.Length = 0;
	AddMoreSitReps = true;

	// Create SitRep Deck, have to do each time in case more were added
	foreach SitRepMgr.IterateTemplates(DataTemplate, class'X2StrategyElement_DefaultMissionSources'.static.StrategySitrepsFilter)
	{
		SitRepTemplate = X2SitRepTemplate(DataTemplate);
		CardMgr.AddCardToDeck('SitReps', string(SitRepTemplate.DataName));
	}

	// LWOTC: Find any active dark events that have associated sit reps and
	// then roll for each of them. Pick *one* out of any successful rolls.
	ActiveSitRepDarkEvents = GetActiveSitRepDarkEvents(MissionState);
	
	for(j=0; j<default.NUM_DARK_EVENT_SITREPS_TO_ROLL; j++)
	{
		SitRepName = PickActiveDarkEventSitRep(ActiveSitRepDarkEvents, MissionState);
		if (SitRepName != '')
			ActiveSitReps.AddItem(SitRepName);
			ActiveSitRepDarkEvents.RemoveItem(SitRepName); //remove it from the active array so we don't roll it twice in a row, and the array gets rebuilt anyways every time this is called.
	}

	SitRepName = PickSpecialSitRep(MissionState);
	if (SitRepName != '' && AddMoreSitReps)
	{
		// A special sit rep has been selected, so add it to the list of active sitreps, and check if we want to still add more sitreps.
		ActiveSitReps.AddItem(SitRepName);

		if(!default.ROLL_ADITIONAL_SITREPS_WITH_SPECIAL_SITREP)
			AddMoreSitReps = false;
	}

	for(i = 0; i < default.NUM_SITREPS_TO_ROLL; i++)
	{
		ShouldApplySitreps = ShouldAddRandomSitRepToMission(MissionState);

		AddMoreSitReps = (AddMoreSitReps && ShouldApplySitreps);
	
		if (AddMoreSitReps)
		{
			// Grab the next valid SitRep from the deck
			ValidationData = new class'XComLWTuple';
			ValidationData.Data[0].an = ActiveSitReps;
			ValidationData.Data[1].o = MissionState;
			CardMgr.SelectNextCardFromDeck('SitReps', SitRepLabel, ValidateSitRepForMission, ValidationData);
	
			if (SitRepLabel != "")
			{
				ActiveSitReps.AddItem(name(SitRepLabel));
			}
		}
	}

	// Allow mods to modify the active sit rep list
	TriggerOverrideMissionSitReps(MissionState, ActiveSitReps);

	return ActiveSitReps;
}

// Specific function to be used only as a validation function for
// the card manager's `SelectNextCardFromDeck()` function.
static function bool ValidateSitRepForMission(string SitRepName, Object ValidationData)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(ValidationData);
	return Tuple.Data[0].an.Find(name(SitRepName)) == INDEX_NONE &&
			IsSitRepValidForMission(name(SitRepName), XComGameState_MissionSite(Tuple.Data[1].o));
}

// Returns an array of the names of all active dark events that have associated
// sit reps *that are valid for the given mission*.
static function array<name> GetActiveSitRepDarkEvents(XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_DarkEvent DarkEventState;
	local XComGameStateHistory History;
	local X2SitRepTemplateManager SitRepMgr;
	local X2SitRepTemplate SitRep;
	local array<name> ActiveSitRepDarkEvents, AllSitReps;
	local name SitRepName;
	local int i;

	SitRepMgr = class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager();
	SitRepMgr.GetTemplateNames(AllSitReps);

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	for (i = 0; i < AlienHQ.ActiveDarkEvents.Length; i++)
	{
		DarkEventState = XComGameState_DarkEvent(History.GetGameStateForObjectID(AlienHQ.ActiveDarkEvents[i].ObjectID));
		SitRepName = GetSitRepNameForDarkEvent(DarkEventState.GetMyTemplateName());
		SitRep = SitRepMgr.FindSitRepTemplate(SitRepName);
		if (AllSitReps.Find(SitRepName) != INDEX_NONE && SitRep.MeetsRequirements(MissionState))
		{
			ActiveSitRepDarkEvents.AddItem(DarkEventState.GetMyTemplateName());
		}
	}

	return ActiveSitRepDarkEvents;
}

// Rolls for all the given dark events and picks one of the dark events that
// successfully rolled and returns its name. Returns an empty name if no
// successful roll was made.
static function name PickActiveDarkEventSitRep(out array<name> ActiveSitRepDarkEvents, XComGameState_MissionSite MissionState)
{
	local array<name> PossibleDarkEvents;
	local name DarkEventName, SitRepName;

	SitRepName = '';

	// Roll for each active dark event
	foreach ActiveSitRepDarkEvents(DarkEventName)
	{
		if (`SYNC_FRAND_STATIC() < default.DARK_EVENT_SIT_REP_CHANCE)
			PossibleDarkEvents.AddItem(DarkEventName);
	}

	// Now pick one of the successful rolls
	if (PossibleDarkEvents.Length > 0)
	{
		SitRepName = GetSitRepNameForDarkEvent(PossibleDarkEvents[`SYNC_RAND_STATIC(PossibleDarkEvents.Length)]);
	}

	return SitRepName;
}

static function name GetSitRepNameForDarkEvent(name DarkEventName)
{
	// We remove the "_" from the dark event name and append "SitRep" to get the
	// name of the corresponding sit rep (if there is one).
	//
	// Special case for "Lost World" as the corresponding sit rep doesn't
	// follow this convention.
	return DarkEventName == 'DarkEvent_LostWorld' ? 'TheLost' : name(Repl(DarkEventName, "_", "") $ "SitRep");
}

// Iterates through the list of special sit reps, checking each one for
// whether it can be applied to the given mission and if so, rolling for
// it. As soon as a sit rep is successfully rolled, this function returns
// its name, skipping any remaining special sit reps.
//
// Returns an empty name if no successful roll was made.
static function name PickSpecialSitRep(XComGameState_MissionSite MissionState)
{
	local SitRepChance SitRepWithChance;

	// Make sure the special sit reps are ordered first. This allows mods to influence
	// the priority of their own special sit reps without having to mess around with
	// the array.
	default.SPECIAL_SIT_REPS.Sort(CompareByPriority);

	foreach default.SPECIAL_SIT_REPS(SitRepWithChance)
	{
		if (IsSitRepValidForMission(SitRepWithChance.SitRepName, MissionState) &&
				`SYNC_FRAND_STATIC() < SitRepWithChance.Chance)
		{
			return SitRepWithChance.SitRepName;
		}
	}

	// No special sit rep rolled
	return '';
}

static function int CompareByPriority(SitRepChance SitRepWithChanceA, SitRepChance SitRepWithChanceB)
{
	return SitRepWithChanceB.Priority - SitRepWithChanceA.Priority;
}

// Determines whether a random sit rep should be added to the given mission.
// Mods can override the default behaviour of a simple random chance using
// the following event:
/// ```event
/// EventID: OverrideRandomSitRepChance_LW,
/// EventData: [ inout bool DoAddSitRep ],
/// EventSource: XComGameState_MissionSite,
/// NewGameState: no
/// ```
/// You should use ELD_Immediate for your listeners for this event.
static function bool ShouldAddRandomSitRepToMission(XComGameState_MissionSite MissionState)
{
	local XComLWTuple Tuple;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'OverrideRandomSitRepChance_LW';
	Tuple.Data.Add(1);
	Tuple.Data[0].Kind = XComLWTVBool;

	// Default to a simple random chance
	Tuple.Data[0].b = `SYNC_FRAND_STATIC() < default.SIT_REP_CHANCE;

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, MissionState);

	return Tuple.Data[0].b;
}

// Fires an event that allows mods to modify the active list of sit reps
// chosen for the given mission using the following event:
/// ```event
/// EventID: OverrideMissionSitReps_LW,
/// EventData: [ inout array<name> ActiveSitReps ],
/// EventSource: XComGameState_MissionSite,
/// NewGameState: no
/// ```
/// You should use ELD_Immediate for your listeners for this event.
static function TriggerOverrideMissionSitReps(XComGameState_MissionSite MissionState, out array<name> ActiveSitReps)
{
	local XComLWTuple Tuple;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'OverrideMissionSitReps_LW';
	Tuple.Data.Add(1);
	Tuple.Data[0].Kind = XComLWTVArrayNames;
	Tuple.Data[0].an = ActiveSitReps;

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, MissionState);

	ActiveSitReps = Tuple.Data[0].an;
}

// Checks whether the sit rep with the given name can be applied to the given
// mission.
static function bool IsSitRepValidForMission(name SitRepName, XComGameState_MissionSite MissionState)
{
	return class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager().
			FindSitRepTemplate(SitRepName).MeetsRequirements(MissionState);
}

// Checks whether the given sit rep can be applied to the given mission. Note that
// code should use `X2SitRepTemplate.MeetsRequirements()` instead to perform a full
// check of whether a sit rep meets all its requirements.
static function bool SitRepMeetsAdditionalRequirements(X2SitRepTemplate SitRepTemplate, XComGameState_MissionSite MissionState)
{
	local MissionTypeSitRepExclusions ExclusionDef;
	local string MissionType;
	local int idx;

	// Handle Alien Ruler sit reps separately, particularly as we need to handle the situation
	// where the player may not have the DLC installed.
	if (default.AlienRulerSitRepNames.Find(SitRepTemplate.DataName) != INDEX_NONE)
	{
		return class'XComGameState_AlienRulerManager' != none ? IsAlienRulerSitRepValid(SitRepTemplate.DataName, MissionState) : false;
	}

	// Check whether the mission type has any sit rep exclusions and if so, whether the
	// given sit rep falls in those exclusions.
	MissionType = MissionState.GeneratedMission.Mission.sType;
	idx = default.MISSION_TYPE_SIT_REP_EXCLUSIONS.Find('MissionType', MissionType);
	if (idx == INDEX_NONE)
	{
		return true;
	}
	else
	{
		// Check whether the sit rep is excluded from this mission type. We also double
		// check that the mission type is not configured to forbid sit reps. The alien
		// activity normally performs this check, but we include it here for missions
		// spawned from covert actions or other sources than alien activities.
		ExclusionDef = default.MISSION_TYPE_SIT_REP_EXCLUSIONS[idx];
		return ExclusionDef.SitRepNames.Find(string(SitRepTemplate.DataName)) == INDEX_NONE &&
				class'XComGameState_LWAlienActivity'.default.NO_SIT_REP_MISSION_TYPES.Find(MissionType) == INDEX_NONE;
	}
}

static function bool IsAlienRulerSitRepValid(name SitRepName, XComGameState_MissionSite MissionState)
{
	local XComGameState_AlienRulerManager RulerMgr;
	local XComGameState_MissionSite MissionStateIter;
	local XComGameState_Unit RulerState;
	local X2SitRepTemplateManager SitRepMgr;
	local name RulerActiveTacticalTag;

	// Lock Alien Rulers behind the Alien Nest if that mission is enabled
	if (class'LWDLCHelpers'.static.IsAlienHuntersNarrativeEnabled() &&
			!class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('DLC_AlienNestMissionComplete'))
	{
		return false;
	}

	// Only allow this sit rep where we can actually get missions. Don't
	// want the only one of this sit rep allowed at any one time to be
	// in a region where you can't get missions.
	if (!MissionState.GetWorldRegion().HaveMadeContact()) return false;

	RulerMgr = XComGameState_AlienRulerManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_AlienRulerManager'));

	// Grab the tactical gameplay tag for the ruler from the sit rep.
	SitRepMgr = class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager();
	RulerActiveTacticalTag = SitRepMgr.FindSitRepTemplate(SitRepName).TacticalGameplayTags[0];

	// Make sure this Ruler isn't already on another mission. Need to check
	// in the current game state as well as the history because multiple
	// missions can spawn in the current new game state.
	foreach MissionState.GetParentGameState().IterateByClassType(class'XComGameState_MissionSite', MissionStateIter)
	{
		if (MissionStateIter.ObjectID != MissionState.ObjectID &&
				MissionStateIter.GeneratedMission.SitReps.Find(SitRepName) != INDEX_NONE)
		{
			return false;
		}
	}

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_MissionSite', MissionStateIter)
	{
		if (MissionStateIter.ObjectID != MissionState.ObjectID &&
				MissionStateIter.GeneratedMission.SitReps.Find(SitRepName) != INDEX_NONE)
		{
			return false;
		}
	}

	// If we get here, the sit rep has already passed the force level check.
	// So just need to check that the corresponding Ruler is still alive.
	RulerState = class'LWDLCHelpers'.static.GetAlienRulerForTacticalTag(RulerActiveTacticalTag);
	return RulerMgr.DefeatedAlienRulers.Find('ObjectID', RulerState.ObjectID) == INDEX_NONE;
}

//**********************************************
//------- UTILITY HELPERS ---------------------
//**********************************************

static function SpawnPointOfInterest(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_PointOfInterest POIState;

	History = `XCOMHISTORY;
	if (MissionState.POIToSpawn.ObjectID != 0)
	{
		POIState = XComGameState_PointOfInterest(History.GetGameStateForObjectID(MissionState.POIToSpawn.ObjectID));

		if (POIState != none)
		{
			POIState = XComGameState_PointOfInterest(NewGameState.CreateStateObject(class'XComGameState_PointOfInterest', POIState.ObjectID));
			NewGameState.AddStateObject(POIState);
			POIState.Spawn(NewGameState);
		}
	}
}

static function LoseContactWithMissionRegion(XComGameState NewGameState, XComGameState_MissionSite MissionState, bool bRecord)
{
	local XComGameState_WorldRegion RegionState;
	local XGParamTag ParamTag;
	local EResistanceLevelType OldResLevel;
	local int OldIncome, NewIncome, IncomeDelta;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(MissionState.Region.ObjectID));

	if (RegionState == none)
	{
		RegionState = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', MissionState.Region.ObjectID));
		NewGameState.AddStateObject(RegionState);
	}

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	ParamTag.StrValue0 = RegionState.GetMyTemplate().DisplayName;
	OldResLevel = RegionState.ResistanceLevel;
	OldIncome = RegionState.GetSupplyDropReward();

	RegionState.SetResistanceLevel(NewGameState, eResLevel_Unlocked);
	
	NewIncome = RegionState.GetSupplyDropReward();
	IncomeDelta = NewIncome - OldIncome;

	if (bRecord)
	{
		if(RegionState.ResistanceLevel < OldResLevel)
		{
			class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strRegionLostContact), true);
		}

		if(IncomeDelta < 0)
		{
			ParamTag.StrValue0 = string(-IncomeDelta);
			class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strDecreasedSupplyIncome), true);
		}
	}
}

static function bool OneStrategyObjectiveCompleted(XComGameState_BattleData BattleDataState)
{
	return (BattleDataState.OneStrategyObjectiveCompleted());
}

static function bool IsInStartingRegion(XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;

	History = `XCOMHISTORY;
	RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(MissionState.Region.ObjectID));

	return (RegionState != none && RegionState.IsStartingRegion());
}

defaultproperties
{
	AlienRulerSitRepNames[0] = "ViperKing"
	AlienRulerSitRepNames[1] = "BerserkerQueen"
	AlienRulerSitRepNames[2] = "ArchonKing"
}
