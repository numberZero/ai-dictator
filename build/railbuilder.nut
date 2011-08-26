/* -*- Mode: C++; tab-width: 6 -*- */ 
/**
 *    This file is part of DictatorAI
 *
 *    It's free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 2 of the License, or
 *    (at your option) any later version.
 *
 *    You should have received a copy of the GNU General Public License
 *    with it.  If not, see <http://www.gnu.org/licenses/>.
 *
**/


function cBuilder::BuildTrainStation(start)
// It's where we find a spot for our train station
// Unlike classic stations that need best spot where to get cargo, train stations best spot
// is the one that can do its task while still provide most space to futher allow station upgrading
{
// for industry: to grab goods: best is near where it produce and closest to target
// to drop goods: best is farest target while still accept goods
// train station best direction is | when left or right the industry
// and -- when up or down the industry location, this offer best upgrade chance
// for town, saddly it's contrary, station is best -- when left/right and | when up/down
// because that configuration will almost always cut entry or exit point of station, but offer higher
// chance to enlarge the station without going too much into the city
local dir, tilelist, otherplace, isneartown = null;
local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
local istown=false;
local srcpoint=null;
local sourceplace=null;
local statile=null;
if (start)	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.source_location, INSTANCE.route.target_location);
		if (INSTANCE.route.source_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.sourceID);
			tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.route.cargoID, 1, 1, rad);
			tilelist.KeepAboveValue(0); 
			istown=true;
			}
		else	{
			tilelist = AITileList_IndustryProducing(INSTANCE.route.sourceID, rad);
			istown=false;
			}
		otherplace=INSTANCE.route.target_location; sourceplace=INSTANCE.route.source_location;
		}
	else	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.target_location, INSTANCE.route.source_location);
		if (INSTANCE.route.target_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.targetID);
			tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.route.cargoID, 1, 1, rad);
			tilelist.KeepAboveValue(8); 
			istown=true;
			}
		else	{
			tilelist = AITileList_IndustryAccepting(INSTANCE.route.targetID, rad);
			isneartown=false; istown=false;
			}
		otherplace=INSTANCE.route.source_location; sourceplace=INSTANCE.route.target_location;
		}

//tilelist.Valuate(cTileTools.IsBuildable);
//tilelist.KeepValue(1);
local success = false;
local saveList=AIList();
saveList.AddList(tilelist);
//DInfo("isneartown="+isneartown+" istown="+istown,2,"BuildTrainStation");
local buildmode=0;
do
	{
/* 5 build mode:
- try find a place with stationsize+4 tiles flatten and buildable
- same other direction
- try find a place with stationsize+4 tiles maybe not flat and buildable
- same other direction
- try find a place with stationsize+4 tiles maybe not flat and buildable even on water
*/
	tilelist.Clear();
	tilelist.AddList(saveList);
	switch (buildmode)
		{
		case	0:
			tilelist.Valuate(cTileTools.IsBuildableRectangleFlat,1,9);
			tilelist.KeepValue(1);
			break;
		case	1:
			tilelist.Valuate(cTileTools.IsBuildableRectangleFlat,9,1);
			tilelist.KeepValue(1);
			break;
		case	2:
			tilelist.Valuate(AITile.IsBuildableRectangle,1,9); // allow terraform19
			tilelist.KeepValue(1);
			break;
		case	3:
			tilelist.Valuate(AITile.IsBuildableRectangle,9,1); // allow terraform91
			tilelist.KeepValue(1);
			break;
		case	4:
			tilelist.Valuate(cTileTools.IsBuildable); // even water will be terraform
			tilelist.KeepValue(1);
			break;
		}
	DInfo("Tilelist set to "+tilelist.Count()+" in mode "+buildmode,1,"BuildTrainStation");
	// restore previous valuated values...
	foreach (ltile, lvalue in saveList)	if (tilelist.HasItem(ltile))	tilelist.SetValue(ltile, lvalue);
	if (!istown)
		{
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
		tilelist.Sort(AIList.SORT_BY_VALUE, true);
		}
	else	{ tilelist.Sort(AIList.SORT_BY_VALUE, false); }
	showLogic(tilelist); 
	ClearSignsALL();
	foreach (tile, dummy in tilelist)
		{
		// find where that point is compare to its source for the station
			if (start)	dir=INSTANCE.builder.GetDirection(tile, INSTANCE.route.source_location);
				else	dir=INSTANCE.builder.GetDirection(INSTANCE.route.target_location,tile);
			switch (dir)
				{
				case DIR_NW: //0 south
					if (istown)	dir=AIRail.RAILTRACK_NW_SE;
						else	dir=AIRail.RAILTRACK_NE_SW;
					break;
				case DIR_SE: //1 north
					if (istown)	dir=AIRail.RAILTRACK_NW_SE;
						else	dir=AIRail.RAILTRACK_NE_SW;
					break;
				case DIR_SW: //3 est/droite
					if (istown)	dir=AIRail.RAILTRACK_NE_SW;
						else	dir=AIRail.RAILTRACK_NW_SE;
					break;
				case DIR_NE: //2 west/gauche
					if (istown)	dir=AIRail.RAILTRACK_NE_SW;
						else	dir=AIRail.RAILTRACK_NW_SE;
					break;
				}
			DInfo("New station direction set to "+dir,1,"BuildTrainStation");
		if (buildmode==4)
			{
			if (dir == AIRail.RAILTRACK_NW_SE)	statile=cTileTools.CheckLandForConstruction(tile, 1, 5);
								else	statile=cTileTools.CheckLandForConstruction(tile, 5, 1);
			}
		else	statile=tile;
		if (statile == -1)	continue; // we have no solve to build a station here
		if (istown)	
			{
			if (start)	cTileTools.SeduceTown(INSTANCE.route.sourceID, AITown.TOWN_RATING_MEDIOCRE);
				else	cTileTools.SeduceTown(INSTANCE.route.targetID, AITown.TOWN_RATING_MEDIOCRE);
			}
		success=INSTANCE.builder.CreateAndBuildTrainStation(statile, dir);
		if (!success)
			{
			// switch again station direction, a solve exist there
			if (dir == AIRail.RAILTRACK_NE_SW)	dir=AIRail.RAILTRACK_NW_SE;
								else	dir=AIRail.RAILTRACK_NE_SW;
			success=INSTANCE.builder.CreateAndBuildTrainStation(statile, dir);
			}
		if (success)	{
					statile=tile;
					break;
					}
				else	{ // see why we fail
					INSTANCE.builder.IsCriticalError();
					if (INSTANCE.builder.CriticalError)	{ break; }
					if (AIError.GetLastError()==AIError.ERR_LOCAL_AUTHORITY_REFUSES)	{ break; }
					}
		}
	buildmode++;
	} while (!success && buildmode!=5);
ClearSignsALL();

if (!success) 
	{
	DInfo("Can't find a good place to build the train station ! "+tilelist.Count(),1,"BuildTrainStation");
	return false;
	}
// here, so we success to build one
local staID=AIStation.GetStationID(statile);
if (start)	INSTANCE.route.source_stationID=staID;
	else	INSTANCE.route.target_stationID=staID;
INSTANCE.route.CreateNewStation(start);
return true;
}

function cBuilder::BuildRoadRAIL(head1, head2) {
local pathfinder = MyRailPF();
pathfinder._cost_level_crossing = 900;
pathfinder._cost_slope = 200;
pathfinder._cost_coast = 100;
pathfinder._cost_bridge_per_tile = 90;
pathfinder._cost_tunnel_per_tile = 75;
pathfinder._max_bridge_length = 20;
pathfinder._max_tunnel_length = 20;
pathfinder.InitializePath([head1], [head2]);
local savemoney=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local pfInfo=null;
INSTANCE.bank.SaveMoney(); // thinking long time, don't waste money
pfInfo=AISign.BuildSign(head1[0],"Pathfinding...");
DInfo("Rail Pathfinding...",1);
local counter = 0;
local path = false;
while (path == false && counter < 350)
	{
	path = pathfinder.FindPath(350);
	counter++;
	AISign.SetName(pfInfo,"Pathfinding... "+counter);
	AIController.Sleep(1);
	}
if (path != null && path != false)
	{
	DInfo("Path found. (" + counter + ")",0,"BuildRoadRAIL");
	AISign.RemoveSign(pfInfo);
	ClearSignsALL();
	}
else	{
	ClearSignsALL();
	DInfo("Pathfinding failed.",1);
	INSTANCE.builder.CriticalError=true;
	INSTANCE.bank.RaiseFundsTo(savemoney);
	return false;
	}
	INSTANCE.bank.RaiseFundsBigTime();
	local prev = null;
	local prevprev = null;
	local pp1, pp2, pp3 = null;
	while (path != null) {
		if (prevprev != null) {
			if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
				if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
					if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev)) {
						DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							DInfo("That tunnel would be too expensive. Construction aborted.",2);
							return false;
						}
						if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
					}
				} else {
					local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
					bridgelist.Valuate(AIBridge.GetMaxSpeed);
					if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgelist.Begin(), prev, path.GetTile())) {
						DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							DInfo("That bridge would be too expensive. Construction aborted.",2);
							return false;
						}
						if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
					}
				}
				pp3 = pp2;
				pp2 = pp1;
				pp1 = prevprev;
				prevprev = prev;
				prev = path.GetTile();
				path = path.GetParent();
			} else {
				if (!AIRail.BuildRail(prevprev, prev, path.GetTile())) {
					DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
					if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
				}
			}
		}
		if (path != null) {
			pp3 = pp2;
			pp2 = pp1;
			pp1 = prevprev;
			prevprev = prev;
			prev = path.GetTile();
			path = path.GetParent(); 
		}
	}
	return true;
}

function cBuilder::RetryRail(prevprev, pp1, pp2, pp3, head1)
{
	/*recursiondepth++;
	if (recursiondepth > 10) {
		AILog.Error("It looks like I got into an infinite loop.");
		return false;
	}*/
	if (pp1 == null) return false;
	local head2 = [null, null];
	local tiles = [pp3, pp2, pp1, prevprev];
	foreach (idx, tile in tiles) {
		if (tile != null) {
			head2[1] = tile;
			break;
		}
	}
	tiles = [prevprev, pp1, pp2, pp3]
	foreach (idx, tile in tiles) {
		if (tile == head2[1]) {
			break;
		} else {
			if (AIRail.IsLevelCrossingTile(tile)) {
				local track = AIRail.GetRailTracks(tile);
				if (!AIRail.RemoveRailTrack(tile, track)) {
					local counter = 0;
					AIController.Sleep(75);
					while (!AIRail.RemoveRailTrack(tile, track) && counter < 3) {
						counter++;
						AIController.Sleep(75);
					}
				}
			} else {
				cTileTools.DemolishTile(tile);
			}
			head2[0] = tile;
		}
	}
	if (cBuilder.BuildRoadRAIL(head2, head1)) return true; else return false;
}

function cBuilder::ReportHole(start, end, waserror)
{
	if (!waserror) {
		holestart = start;
	}
	holeend = end;
}

function cBuilder::FindStationEntryToExitPoint(src, dst)
// find the closest path from station src to station dst
// We return result in array: 0=src tile, 1=1(entry)0(exit), 1=dst tile, value=1(entry)0(exit)
// return array empty on error
// 
{
// check entry/exit avaiablility on stations
local srcEntry=cStation.IsRailStationEntryOpen(src);
local srcExit=cStation.IsRailStationExitOpen(src);
local dstEntry=cStation.IsRailStationEntryOpen(dst);
local dstExit=cStation.IsRailStationExitOpen(dst);
local srcEntryLoc=cStation.GetRailStationIN(true,src);
local srcExitLoc=cStation.GetRailStationIN(false,src);
local dstEntryLoc=cStation.GetRailStationIN(true,dst);
local dstExitLoc=cStation.GetRailStationIN(false,dst);
if (srcEntryLoc==-1)	srcEntryLoc=cStation.GetRailStationFrontTile(true, cStation.GetLocation(src), src);
if (dstEntryLoc==-1)	dstEntryLoc=cStation.GetRailStationFrontTile(true, cStation.GetLocation(dst), dst);
if (srcExitLoc==-1)	srcExitLoc=cStation.GetRailStationFrontTile(false, cStation.GetLocation(src), src);
if (dstExitLoc==-1)	dstExitLoc=cStation.GetRailStationFrontTile(false, cStation.GetLocation(dst), dst);

if ( (!srcEntry && !srcExit) || (!dstEntry && !dstExit) )
	{
	DInfo("That station have its entry and exit closed. No more connections could be made with it",1,"FindStationEntryToExitPoint");
	return [];
	}
local best=100000000000;
local bestsrc=0;
local bestdst=0;
local check=0;
local srcFlag=0;
local dstFlag=0; // use to check if we're connect to entry(1) or exit(0)

if (srcEntry)
	{
	if (dstExit)
		{
		check = AIMap.DistanceManhattan(srcEntryLoc,dstExitLoc);
		if (check < best)	{ best=check; bestsrc=srcEntryLoc; bestdst=dstExitLoc; }
		}
		DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	if (dstEntry)
		{
		check = AIMap.DistanceManhattan(srcEntryLoc,dstEntryLoc);
		if (check < best)	{ best=check; bestsrc=srcEntryLoc; bestdst=dstEntryLoc; }
		}
		DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	}
if (srcExit)
	{
	if (dstEntry)
		{
		check = AIMap.DistanceManhattan(srcExitLoc,dstEntryLoc);
		if (check < best)	{ best=check; bestsrc=srcExitLoc; bestdst=dstEntryLoc; }
		}
	DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	if (dstExit)
		{
		check = AIMap.DistanceManhattan(srcExitLoc,dstExitLoc); 
		if (check < best)	{ best=check; bestsrc=srcExitLoc; bestdst=dstExitLoc; }
		}
	DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	}
// Now we know where to build our roads
local bestWay=[];
if (bestsrc == srcEntryLoc)	srcFlag=1;
if (bestdst == dstEntryLoc)	dstFlag=1;
bestWay.push(bestsrc);
bestWay.push(srcFlag);
bestWay.push(bestdst);
bestWay.push(dstFlag);
DInfo("Best connecting source="+bestsrc+" destination="+bestdst+" srcFlag="+srcFlag+" dstFlag="+dstFlag,2,"FindStationEntryToExit");
PutSign(bestsrc,"CS");
PutSign(bestdst,"CT");
return bestWay;
}

function cBuilder::CreateStationsConnection(fromObj, toObj)
// Connect station fromObj to station toObj
// Pickup entry/exit close to each other
// Create the connections in front of these stations
{
local srcStation=cStation.GetStationObject(fromObj);
local dstStation=cStation.GetStationObject(toObj);
DInfo("Connecting rail station "+AIStation.GetName(srcStation.stationID)+" to "+AIStation.GetName(dstStation.stationID),1,"CreateStationsConnection");
local retry=true;
local bestWay=AIList();
local srcresult=false;
local dstresult=false;
local srcpos=null;
local dstpos=null;
local srcUseEntry=null;
local dstUseEntry=null;
do	{
	bestWay=INSTANCE.builder.FindStationEntryToExitPoint(fromObj, toObj);
	if (bestWay.len()==0)	{ INSTANCE.builder.CriticalError=true; return false; }
				else	retry=true;
	if (retry) // we found a possible connection
		{
		srcpos=bestWay[0];
		dstpos=bestWay[2];
		srcUseEntry=(bestWay[1]==1);
		dstUseEntry=(bestWay[3]==1);
		DInfo("srcUseEntry="+srcUseEntry+" dstUseEntry="+dstUseEntry,2,"cBuilder::CreateStationsConnection");
		if (!srcresult)	srcresult=INSTANCE.builder.RailStationGrow(fromObj, srcUseEntry, true);
		if (!srcresult)
			{
			DWarn("RailStationGrow report failure",1,"cBuilder::CreateStationConnection");
			if (INSTANCE.builder.CriticalError)	return false;
			}
		if (!dstresult)	dstresult=INSTANCE.builder.RailStationGrow(toObj, dstUseEntry, false);
		if (!dstresult)
			{
			DWarn("RailStationGrow report failure",1,"cBuilder::CreateStationConnection");
			if (INSTANCE.builder.CriticalError)	return false;
			}
		if (dstresult && srcresult)
			{
			// need to grab the real locations first, as they might have change while building entrances of station
			local srclink=0;
			local dstlink=0;
			if (srcUseEntry)	{ srcpos=srcStation.locations.GetValue(1); srclink=srcStation.locations.GetValue(11); }
					else	{ srcpos=srcStation.locations.GetValue(3); srclink=srcStation.locations.GetValue(13); }
			if (dstUseEntry)	{ dstpos=dstStation.locations.GetValue(2); dstlink=dstStation.locations.GetValue(12); }
					else	{ dstpos=dstStation.locations.GetValue(4); dstlink=dstStation.locations.GetValue(14); }
			ClearSignsALL();
			print("testing stations**********");
			INSTANCE.builder.RailStationGrow(fromObj, true, true); // TODO: remove force grow
			INSTANCE.builder.RailStationGrow(toObj, true, true);
			INSTANCE.builder.RailStationGrow(fromObj, false, false); // TODO: remove force grow
			INSTANCE.builder.RailStationGrow(toObj, false, false);
			ClearSignsALL();
			DInfo("Calling rail pathfinder: srcpos="+srcpos+" dstpos="+dstpos,2,"CreateStationConnection");
			PutSign(dstpos,"D");
			PutSign(dstlink,"d");
			PutSign(srcpos,"S");
			PutSign(srclink,"s");
			if (!INSTANCE.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos]))
					return false;
				else	retry=false;
			}
		}
	} while (retry);
// pfff here, all connections were made, and rail built
if (srcUseEntry)	srcStation.locations.SetValue(11,dstpos);
		else	srcStation.locations.SetValue(13,dstpos);
if (dstUseEntry)	dstStation.locations.SetValue(11,srcpos);
		else	dstStation.locations.SetValue(13,srcpos);
return true;
}

function cBuilder::CreateAndBuildTrainStation(tilepos, direction, link=null)
// Create a new station, we still don't know if station will be usable
// that's a task handle by CreateStationConnection
// link: true to link to a previous station
{
if (link==null)	link=AIStation.STATION_NEW;
local money=AIRail.GetBuildCost(AIRail.GetCurrentRailType(), AIRail.BT_STATION);
if (!cBanker.CanBuyThat(money))	DInfo("We lack money to buy the station",1,"cBuilder::CreateAndBuildTrainStation");
INSTANCE.bank.RaiseFundsTo(money);
if (!AIRail.BuildRailStation(tilepos, direction, 1, 5, link))
	{
	DInfo("Rail station couldn't be built: "+AIError.GetLastErrorString(),1,"cBuilder::CreateAndBuildTrainStation");
	PutSign(tilepos,"!"); INSTANCE.NeedDelay(10);
	return false;
	}
return true;
}

function cBuilder::SetRailType(rtype=null)
// set current railtype
{
	if (rtype == null)
		{
		local railtypes = AIRailTypeList();
		if (railtypes.IsEmpty())	{ DError("There's no railtype avaiable !",1,"cBuilder::SetRailType"); return false; }
		rtype=railtypes.Begin();
		}
	if (!AIRail.IsRailTypeAvailable(rtype))	{ DError("Railtype "+rtype+" is not available !",1,"cBuilder::SetRailType"); return false; }
	AIRail.SetCurrentRailType(rtype);
}

function cBuilder::RailStationRemovePlatform(staloc)
// remove a rail station platform we found at staloc
// discard any errors, we just try to remove it
{
local tilelist=cTileTools.FindStationTiles(statile);
if (tilelist.IsEmpty())	return true;
local Keeper=null;
local railtrack=null;
if (AIRail.GetRailStationDirection(staloc) == AIRail.RAILTRACK_NW_SE)
	{ tilelist.Valuate(AIMap.GetTileX); Keeper=AIMap.GetTileX(staloc); railtrack=AIRail.RAILTRACK_NW_SE; }
else	{ tilelist.Valuate(AIMap.GetTileY); Keeper=AIMap.GetTileY(staloc); railtrack=AIRail.RAILTRACK_NE_SW; }
tilelist.KeepValue(Keeper);
showLogic(tilelist);
foreach (tile, dummy in tilelist)	AIRail.RemoveRailTrack(tile, railtrack);
return true;
}

function cBuilder::RailStationGrow(staID, useEntry, taker)
// make the station grow and build entry/exit
// staID: stationID
// useEntry: true to add a train to its entry, false to add it at exit
// taker: true to add a taker train, false to add a dropper train
{
// when a station entry cannot be change anymore, we lock it and refuse any train on it
// "" for exit
// when both entry and exit are locked, still the station might be a valid & working one
// so a dead one is : entry+exit locked, no train using it, size=1
local thatstation=cStation.GetStationObject(staID);
if (thatstation.stationID == null)	return false;
local trainEntryTaker=thatstation.locations.GetValue(9);
local trainExitTaker=thatstation.locations.GetValue(10);
local trainEntryDropper=thatstation.locations.GetValue(7);
local trainExitDropper=thatstation.locations.GetValue(8);
local station_depth=thatstation.locations.GetValue(19);
local success=false;
local closeIt=false;
if (useEntry)
	{
	if (taker)	trainEntryTaker++;
		else	trainEntryDropper++;
	}
else	{
	if (taker)	trainExitTaker++;
		else	trainExitDropper++;
	}
local tED=trainEntryDropper / 2;
if (trainEntryDropper > 0 && tED==0)	tED++;
local tXD=trainExitDropper / 2;
if (trainExitDropper > 0 && tXD==0)	tXD++;
local newStationSize=trainEntryTaker+trainExitTaker+tED+tXD;
print("new size="+newStationSize+" tED="+tED+" tXD="+tXD);
local position=thatstation.GetLocation();
local direction=thatstation.GetRailStationDirection();
INSTANCE.builder.SetRailType(thatstation.specialType);
local leftTileOf, rightTileOf, forwardTileOf, backwardTileOf =null;
local workTile=null; // the station front tile, but depend on entry or exit
local railFront, railCross, railLeft, railRight, railUpLeft, railUpRight, fire = null;
workTile=thatstation.GetRailStationFrontTile(useEntry,position);
local temptile=0;
if (direction == AIRail.RAILTRACK_NW_SE)
	{
	railFront=AIRail.RAILTRACK_NW_SE;
	railCross=AIRail.RAILTRACK_NE_SW;
	if (useEntry)	{ // going NW->SE
				railLeft=AIRail.RAILTRACK_SW_SE;
				railRight=AIRail.RAILTRACK_NE_SE;
				railUpLeft=AIRail.RAILTRACK_NW_SW;
				railUpRight=AIRail.RAILTRACK_NW_NE;
				}
			else	{ // going SE->NW
				railLeft=AIRail.RAILTRACK_NW_NE;
				railRight=AIRail.RAILTRACK_NW_SW;
				railUpLeft=AIRail.RAILTRACK_NE_SE;
				railUpRight=AIRail.RAILTRACK_SW_SE;
				}
	}
else	{ // NE_SW
	railFront=AIRail.RAILTRACK_NE_SW;
	railCross=AIRail.RAILTRACK_NW_SE;
	if (useEntry)	{ // going NE->SW
				railLeft=AIRail.RAILTRACK_NW_SW;
				railRight=AIRail.RAILTRACK_SW_SE;
				railUpLeft=AIRail.RAILTRACK_NW_NE;
				railUpRight=AIRail.RAILTRACK_NE_SE;
				}
			else	{ // going SW->NE
				railLeft=AIRail.RAILTRACK_NE_SE;
				railRight=AIRail.RAILTRACK_NW_NE;
				railUpLeft=AIRail.RAILTRACK_SW_SE;
				railUpRight=AIRail.RAILTRACK_NW_SW;
				}
	}
if (useEntry)	DInfo("Working on station entry",1,"RailStationGrow");
		else	DInfo("Working on station exit",1,"RailStationGrow");
leftTileOf=cStation.GetRelativeTileLeft(staID, useEntry);
rightTileOf=cStation.GetRelativeTileRight(staID, useEntry);
forwardTileOf=cStation.GetRelativeTileForward(staID, useEntry);
backwardTileOf=cStation.GetRelativeTileBackward(staID, useEntry);
PutSign(workTile,"W");
INSTANCE.NeedDelay(50);
local displace=0;
// need grow the station ?
//newStationSize=thatstation.size+1;
if (newStationSize > thatstation.size)
	{
	DInfo("Upgrading "+thatstation.GetName()+" to "+newStationSize+" platforms",0,"RailStationGrow");
	if (thatstation.maxsize==thatstation.size)
		{
		DInfo("We'll need another platform to handle that train, but the station "+AIStation.GetName(thatstation.stationID)+" cannot grow anymore.",1,"RailStationGrow");
		INSTANCE.builder.CriticalError=true; // raise it ourselves
		return false;
		}
	local allfail=false;
	local topLeftPlatform=thatstation.locations.GetValue(20);
	local topRightPlatform=thatstation.locations.GetValue(21);
	local idxRightPlatform=cStation.GetPlatformIndex(topRightPlatform, useEntry);
	local idxLeftPlatform=cStation.GetPlatformIndex(topLeftPlatform, useEntry);
	ClearSignsALL();// deb
	displace=idxLeftPlatform+rightTileOf;
//	PutSign(displace,"D"); PutSign(idxRightPlatform,"I"); PutSign(topRightPlatform,"T"); INSTANCE.NeedDelay(100);
//	print("displace="+displace+" topRight="+topRightPlatform+" idxtopRight="+idxRightPlatform);
	
	local areaclean=AITileList();
	areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
	areaclean.Valuate(AITile.IsBuildable);
	print("areaclean size ="+areaclean.Count());
	showLogic(areaclean); // deb
	local canDestroy=cTileTools.IsAreaBuildable(areaclean,staID);
	if (canDestroy)	print("1st area say buidable");
			else	print("1st area say NOT buildable");
	if (canDestroy)
		foreach (ctile, cdummy in areaclean)
			{
			print("trying tile "+ctile);
			if (!cTileTools.DemolishTile(ctile))	print("fail demolish");
			}
	print("2nd try only ctile size="+areaclean.Count()); INSTANCE.NeedDelay(50);
	if (canDestroy)	foreach (ctile in areaclean)	cTileTools.DemolishTile(ctile);
 INSTANCE.NeedDelay(90);
	cTileTools.TerraformLevelTiles(idxLeftPlatform, displace+(backwardTileOf*(station_depth-1)));
	success=CreateAndBuildTrainStation(cStation.GetPlatformIndex(idxLeftPlatform,true)+rightTileOf, direction, thatstation.stationID);
	if (!success) print("right side fail");
	INSTANCE.NeedDelay(150);
	if (success)	foreach (tile, dummy in areaclean)	thatstation.StationClaimTile(tile, thatstation.stationID);
	if (!success)
		{
		INSTANCE.builder.IsCriticalError();
		allfail=INSTANCE.builder.CriticalError;
		INSTANCE.builder.CriticalError=false;
		displace=idxRightPlatform+leftTileOf;
		local areaclean=AITileList();
		areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
		showLogic(areaclean);
		if (cTileTools.IsAreaBuildable(areaclean,staID))
			foreach (ctile, cdummy in areaclean)	cTileTools.DemolishTile(ctile);
		cTileTools.TerraformLevelTiles(idxRightPlatform, displace+(backwardTileOf*(station_depth-1)));
		success=CreateAndBuildTrainStation(cStation.GetPlatformIndex(idxRightPlatform,true)+leftTileOf, direction, thatstation.stationID);
		if (success)	foreach (tile, dummy in areaclean)	thatstation.StationClaimTile(tile, thatstation.stationID);
		if (!success)	
			{
			INSTANCE.builder.IsCriticalError();
			if (INSTANCE.builder.CriticalError && allfail)
				{ // We will never be able to build one more station platform in that station so
				DInfo("Critical failure, station couldn't be upgrade anymore!",1,"RailStationGrow");
				thatstation.maxsize=thatstation.size;
				INSTANCE.builder.CriticalError=true; // Make sure caller will be aware of that failure
				return false;
				}
			else	{
				DInfo("Temporary failure, station couldn't be upgrade for now",1,"RailStationGrow");
				return false;
				}
			}
		}
	// if we are here, we endup successfuly add a new platform to the station
	thatstation.DefinePlatform();
	}
local se_IN, se_OUT, se_crossing = null; // entry
local sx_IN, sx_OUT, sx_crossing = null; // exit
se_IN=thatstation.GetRailStationIN(true);
se_OUT=thatstation.GetRailStationOUT(true);
sx_IN=thatstation.GetRailStationIN(false);
sx_OUT=thatstation.GetRailStationOUT(false);
se_crossing=thatstation.locations.GetValue(5);
sx_crossing=thatstation.locations.GetValue(6);
local rail=null;
local success=false;
local crossing=null;
// find if we can use that entry/exit if none is define yet
if ( (useEntry && se_crossing==-1) || (!useEntry && sx_crossing==-1) )
	{ // look if we're going too much inside a town, making big damages to it, and mostly sure failure to use that direction to build rails
	local towncheck=AITileList();
	local testcheck=AITileList();
	towncheck.AddRectangle(workTile, workTile+rightTileOf+(4*forwardTileOf));
	if (cTileTools.IsAreaBuildable(towncheck,staID))
		{
		testcheck.AddList(towncheck);
		cTileTools.YexoValuate(testcheck, cTileTools.IsRemovable); // rails are protect here
		showLogic(testcheck);
		INSTANCE.NeedDelay(100);
		testcheck.KeepValue(0);
		if (testcheck.IsEmpty()) // everything is removable
			{
			testcheck.AddList(towncheck);
			testcheck.Valuate(AITile.IsStationTile); // protect station here
			testcheck.KeepValue(1);
			if (testcheck.IsEmpty()) 
				{ // now look if we're not going too much in a town
				local neartown=AITile.GetClosestTown(workTile);
				local s_dst=AITown.GetDistanceManhattanToTile(neartown,workTile);
				local s_end=AITown.GetDistanceManhattanToTile(neartown,workTile+(4*forwardTileOf));
				if (s_dst < 10 && s_end < 10 && s_dst > s_end) // we must be going farer inside the town
					{
					DInfo("Giving up, we're probably going inside "+AITown.GetName(neartown),1,"RailStationGrow");
					success=false;
					}
				else	success=true;
				}
			else	success=false; // station there
			}
		else	{ // not everything is removable, still we might success to cross a road
			testcheck.Valuate(AIRoad.IsRoadTile);
			testcheck.KeepValue(0);
			success=(testcheck.IsEmpty());
			}
		if (success)	foreach (tile, dummy in towncheck)	cTileTools.DemolishTile(tile);
				else	{ DInfo("Giving up, some tiles aren't removable",1,"RailStationGrow"); closeIt=true; }
		}
	else	{ closeIt=true; DInfo("We won't be able to use that entry/exit",1,"RailStationGrow"); }
	}

// define & build crossing point if none exist yet
if ( ((useEntry && se_crossing==-1) || (!useEntry && sx_crossing==-1)) && !closeIt )
	{
	// We first try to build the crossing area from worktile+1 upto worktile+3 to find where one is doable
	// Because a rail can cross a road, we try build a track that will fail to cross a road to be sure it's a valid spot for crossing
	rail=railLeft;
	DInfo("Building crossing point ",2,"RailStationGrow");
	local j=1;
	do	{
		temptile=workTile+(j*forwardTileOf);
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,staID))
			success=INSTANCE.builder.DropRailHere(rail, temptile);
		else	{ INSTANCE.builder.CriticalError=true; success=false; }
		if (success)	{
					if (useEntry)	{ se_crossing=temptile; crossing=se_crossing; }
							else	{ sx_crossing=temptile; crossing=sx_crossing; }
					INSTANCE.builder.DropRailHere(rail, temptile,true); // remove the test track
					}
		j++;
		} while (j < 4 && !success);
	if (success)
		{
		thatstation.RailStationClaimTile(crossing, useEntry);
		if (useEntry)
				{
				thatstation.locations.SetValue(5,se_crossing);
				DInfo("Entry crossing is now set to : "+se_crossing,2,"RailStationGrow");
				PutSign(se_crossing,"X");
				}
			else	{
				thatstation.locations.SetValue(6,sx_crossing);
				DInfo("Exit crossing is now set to : "+sx_crossing,2,"RailStationGrow");
				PutSign(sx_crossing,"X");
				}
		INSTANCE.builder.CriticalError=false;
		}
	else	{
		INSTANCE.builder.IsCriticalError();
		if (INSTANCE.builder.CriticalError)
				{
				closeIt=true;
				INSTANCE.builder.CriticalError=false;
				}
		}
	}

// build entry/exit IN and OUT, if anyone use entry or exit, we need it built
if (!closeIt && ( (se_IN==-1 && useEntry && taker) || (sx_IN==-1 && !useEntry && taker) || (se_OUT==-1 && useEntry && !taker) || (sx_OUT==-1 && !useEntry && !taker) ))
	{
	local in_str="OUT";
	if (taker)	in_str="IN";
	DInfo("Building "+in_str+" point",1,"RailStationGrow");
	rail=railFront;
	local j=1;
	local fromtile=0;
	if (useEntry)	fromtile=se_crossing;
			else	fromtile=sx_crossing;
	if (!taker)	fromtile+=rightTileOf; // OUT line will be right side of IN line
	local endconnector=fromtile;
	do	{
		//PutSign(fromtile+(j*forwardTileOf),"."); 
		temptile=fromtile+(j*forwardTileOf);
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,staID))
			success=INSTANCE.builder.DropRailHere(rail, temptile);
		else	{ INSTANCE.builder.CriticalError=true; success=false; }
		if (success)	thatstation.RailStationClaimTile(temptile,useEntry);
		if (INSTANCE.builder.IsCriticalError())
			{
			if (INSTANCE.builder.CriticalError)	closeIt=true;
			INSTANCE.builder.CriticalError=false;
			break;
			}
		DInfo("Building "+in_str+" point signal",1,"RailStationGrow");
		success=AIRail.BuildSignal(temptile, fromtile+((j-1)*forwardTileOf), AIRail.SIGNALTYPE_NORMAL_TWOWAY);
		if (success)	{
					local entry_str="Entry";
					local pointview=0;
					if (taker)
						{
						if (useEntry)
							{
							se_IN=temptile;
							thatstation.locations.SetValue(1,se_IN);
							thatstation.locations.SetValue(11, se_IN+forwardTileOf); // link
							if (!cTileTools.DemolishTile(se_IN+forwardTileOf))	closeIt=true;
							pointview=se_IN;
							}
						else	{
							sx_IN=fromtile+(j*forwardTileOf);
							thatstation.locations.SetValue(3,sx_IN);
							thatstation.locations.SetValue(13, sx_IN+forwardTileOf); // link
							if (!cTileTools.DemolishTile(sx_IN+forwardTileOf))	closeIt=true;
							pointview=sx_IN; entry_str="Exit";
							}
						}
					else	{
						if (useEntry)
							{
							if (cTileTools.CanUseTile(fromtile,staID))
								if (INSTANCE.builder.DropRailHere(railUpLeft, fromtile))
									thatstation.RailStationClaimTile(fromtile, useEntry);
							se_OUT=temptile;
							thatstation.locations.SetValue(2,se_OUT);
							thatstation.locations.SetValue(12, se_OUT+forwardTileOf); // link
							if (!cTileTools.DemolishTile(se_OUT+forwardTileOf))	closeIt=true;
							pointview=se_OUT;
							if (!cBuilder.RailConnectorSolver(se_OUT, crossing+rightTileOf,true))
								closeIt=true;
							else	thatstation.RailStationClaimTile(crossing+rightTileOf, useEntry);
							}
						else	{
							if (cTileTools.CanUseTile(fromtile,staID))
								if (INSTANCE.builder.DropRailHere(railUpLeft, fromtile))
									thatstation.RailStationClaimTile(fromtile, useEntry);
							sx_OUT=temptile;
							thatstation.locations.SetValue(4,sx_OUT);
							thatstation.locations.SetValue(14, sx_OUT+forwardTileOf); // link
							if (!cTileTools.DemolishTile(sx_OUT+forwardTileOf))	closeIt=true;
							pointview=sx_OUT; entry_str="Exit";
							if (!cBuilder.RailConnectorSolver(se_OUT, crossing+rightTileOf,true))
								closeIt=true;
							else	thatstation.RailStationClaimTile(crossing+rightTileOf, useEntry);
							}
						}
					DInfo(in_str+" "+entry_str+" point set to "+pointview,1,"RailStationGrow");
					PutSign(pointview,in_str);
					}
		j++;
		INSTANCE.NeedDelay(100);
		} while (j < 4 && !success);
		if (!success)	closeIt=true;
	}

// build station entrance point to crossing point
local entry_build=false;
local exit_build=false;
if (!closeIt)
	{
	foreach (platform, status in thatstation.platforms)
		{
		if (se_IN!=-1 || se_OUT!=-1) // entry is build
			{
			cBuilder.PlatformConnectors(platform, true);
			entry_build=true;
			}
		if (sx_IN!=-1 || sx_OUT!=-1) // exit is build
			{
			cBuilder.PlatformConnectors(platform, false);
			exit_build=true;
			}
		}
	thatstation.DefinePlatform();  // scan the station platforms for their status
	local endConnector=AIList();
	local topLeftPlatform=thatstation.locations.GetValue(20);
	local topRightPlatform=thatstation.locations.GetValue(21);
	local doittwice=0;
	local stationside=true;
	for (local hh=0; hh < 3; hh++)
		{
		stationside=(hh==0);
		if (stationside && !entry_build)	continue;
		if (!stationside && !exit_build)	continue;
		local platformsweeper=AIList();
		foreach (platf, openclose in thatstation.platforms)
			{
			local platid=cStation.GetPlatformIndex(platf, true);
			local wpoint=cStation.GetRelativeCrossingPoint(platf, stationside);
			local refpoint=cStation.GetRelativeCrossingPoint(topLeftPlatform, stationside);
			PutSign(refpoint,"R");
			local dir=cBuilder.GetDirection(wpoint, refpoint);
			//print("wpoint="+wpoint+" dir="+dir+" left="+topLeftPlatform+" platid="+platid+" stationside="+stationside);
			local runthru=true;
			if (platid==topLeftPlatform)
				{
				dir=cBuilder.GetDirection(wpoint, cStation.GetRelativeCrossingPoint(topRightPlatform, stationside));
				runthru=false;
				}
			if (platid == topRightPlatform)	runthru=false;
			PutSign(wpoint,dir); 
			switch (dir)
				{
				case	0: // SE-NW
					if (stationside)	rail=railLeft;
							else	rail=railRight;
					break;
				case	1: // NW-SE
					if (stationside)	rail=railRight;
							else	rail=railLeft;
					break;
				case	2: // SW-NE
					if (stationside)	rail=railRight;
							else	rail=railLeft;
					break;
				case	3: // NE-SW
					if (stationside)	rail=railLeft;
							else	rail=railRight;
					break;
				}
			//print("platform open ? "+platf+" : "+cStation.IsPlatformOpen(platf, stationside));
			if (cStation.IsPlatformOpen(platf, stationside) && cTileTools.CanUseTile(wpoint,staID))
				if (INSTANCE.builder.DropRailHere(rail, wpoint))	thatstation.RailStationClaimTile(wpoint, stationside);
			if (runthru && cTileTools.CanUseTile(wpoint,staID))
				if (INSTANCE.builder.DropRailHere(railCross, wpoint))	thatstation.RailStationClaimTile(wpoint, stationside);
			INSTANCE.NeedDelay(50);
			}
		foreach (platf, openclose in thatstation.platforms)
			{
			local platfront=cStation.GetRelativeCrossingPoint(platf, stationside);
			cBuilder.RailConnectorSolver(platfront+backwardTileOf, platfront, true);
			thatstation.RailStationClaimTile(platfront,staID);
			}
		doittwice++;
		ClearSignsALL();									
		} // hh loop
	thatstation.DefinePlatform();
	}
INSTANCE.NeedDelay(100);

// build depot for it,
// in order to build cleaner rail we build the depot where the OUT line should goes, reserving space for it
// if this cannot be done, we build it next to the IN line, and we just swap lines (OUT<>IN)
local tile_OUT=null;
local depot_checker=null;
local removedepot=false;
success=false;
if (useEntry)
	{
	crossing=se_crossing;
	tile_OUT=se_IN;
	depot_checker=thatstation.depot;
	}
else	{
	crossing=sx_crossing;
	tile_OUT=sx_IN;
	depot_checker=thatstation.locations[15];
	}
if (!AIRail.IsRailDepotTile(depot_checker))	depot_checker=-1;
if (depot_checker==-1 && !closeIt)
	{
	local topLeftPlatform=thatstation.locations.GetValue(20);
	local topRightPlatform=thatstation.locations.GetValue(21);
	local topRL=cStation.GetRelativeCrossingPoint(topLeftPlatform, useEntry);
	local topRR=cStation.GetRelativeCrossingPoint(topRightPlatform, useEntry);
	local depotlocations=[topRL+rightTileOf, topRL+leftTileOf, topRR+rightTileOf, topRR+leftTileOf, topRL+forwardTileOf, topRR+forwardTileOf];
	local depotfront=[topRL, topRL, topRR, topRR, topRL, topRR];
	DInfo("Building station depot",1,"RailStationGrow");
	//if (!taker)	crossing+=rightTileOf;
	for (local h=0; h < depotlocations.len(); h++)
		{
		cTileTools.TerraformLevelTiles(crossing,depotlocations[h]);
		PutSign(depotlocations[h],"D");
		if (cTileTools.CanUseTile(depotlocations[h],staID))
			{
			cTileTools.DemolishTile(depotlocations[h]);
			removedepot=AIRail.BuildRailDepot(depotlocations[h], depotfront[h]);
			}
		local depotFront=AIRail.GetRailDepotFrontTile(depotlocations[h]);
		if (AIMap.IsValidTile(depotFront))	success=cBuilder.RailConnectorSolver(depotlocations[h],depotFront,true);
		if (success)	{
					thatstation.RailStationClaimTile(depotlocations[h],useEntry);
					if (useEntry)	thatstation.depot=depotlocations[h];
							else	thatstation.locations[15]=depotlocations[h];
					success=true;
					break;
					}
		}
	}
else	success=true; // depot already build
if (!success)	closeIt=true; // fail to build the depot
//	1 train = 1 entry 
//	2+ trains = connect every sides
//	2+ trains = must have IN & OUT
//	no out & 1 train = close entry
//	so to be valid IN must also run upto station at first

if (closeIt)
	{ // something went wrong, the station entry or exit is now dead
	if (useEntry)
		{
		thatstation.RailStationCloseEntry();
		// entry is only valid if we have more than 1 train using it, because 1 (virtually add) train = 0 trains in real
		if ((trainEntryTaker+trainEntryDropper) == 1)	thatstation.RailStationDeleteEntrance(true);
		}
	else	{
		thatstation.RailStationCloseExit();
		if ((trainExitTaker+trainExitDropper) == 1)	thatstation.RailStationDeleteEntrance(false);
		}
	INSTANCE.builder.CriticalError=false; // let's get another chance to build exit/entry when fail
	return false;
	}
// 7: number of train dropper using entry
// 8: number of train dropper using exit
// 9: number of train taker using entry
// 10: number of train taker using exit
// If we reach this line, it means everything upper was succesful (and i hope this will be !)
thatstation.locations.SetValue(9,trainEntryTaker);
thatstation.locations.SetValue(10,trainExitTaker);
thatstation.locations.SetValue(7,trainEntryDropper);
thatstation.locations.SetValue(8,trainExitDropper);
DInfo("Station "+AIStation.GetName(thatstation.stationID)+" have "+(trainEntryTaker+trainEntryDropper)+" trains using its entry and "+(trainExitTaker+trainExitDropper)+" using its exit",1,"RailStationGrow");
return true;
}

function cBuilder::PlatformConnectors(platform, useEntry)
// connect a platform (build rail and the signal before crosspoint)
// platform: platform tile to work on
// useEntry: connect the platform entry or exit
// on error -1, if rails are already there, no error is report, only if we cannot manage to connect it
{
local frontTile=cStation.GetPlatformFrontTile(platform, useEntry);
if (frontTile==-1)	return -1;
local stationID=AIStation.GetStationID(platform);
local thatstation=cStation.GetStationObject(stationID);
local forwardTileOf=cStation.GetRelativeTileForward(stationID, useEntry);
local backwardTileOf=cStation.GetRelativeTileBackward(stationID, useEntry);
local crossing=0;
local direction=thatstation.GetRailStationDirection();
if (useEntry)	crossing=thatstation.locations.GetValue(5);
		else	crossing=thatstation.locations.GetValue(6);
if (crossing < 0)	{ DError("Crossing isn't define yet",1,"cBuilder::PlatformConnectors"); return false; }
local goal=0;
local rail=AIRail.RAILTRACK_NE_SW;
local sweeper=AIList();
local error=false;
if (direction==AIRail.RAILTRACK_NE_SW)
		goal=AIMap.GetTileIndex(AIMap.GetTileX(crossing),AIMap.GetTileY(frontTile));
	else	{ goal=AIMap.GetTileIndex(AIMap.GetTileX(frontTile),AIMap.GetTileY(crossing)); rail=AIRail.RAILTRACK_NW_SE; }
print("tileX goal:"+AIMap.GetTileX(crossing)+" Y:"+AIMap.GetTileY(crossing));
INSTANCE.NeedDelay(50);
cTileTools.TerraformLevelTiles(goal,frontTile);
local i=frontTile;
local signaldone=false;
while (i != goal)
	{
	PutSign(i,"c");
	if (cTileTools.CanUseTile(i, thatstation.stationID) && cBuilder.DropRailHere(rail, i))
		{
		thatstation.RailStationClaimTile(i, useEntry);
		sweeper.AddItem(i, 0);
		if (!signaldone)	signaldone=AIRail.BuildSignal(i, i+forwardTileOf, AIRail.SIGNALTYPE_NORMAL_TWOWAY);
		}
	else	{ error=true; break; }
	i+=forwardTileOf;
	}
if (!error)	{ cTileTools.DemolishTile(goal); }
if (error)	{ cBuilder.RailCleaner(sweeper); }
return 0;
}

function cBuilder::DropRailHere(railneed, pos, remove=false)
// Put a rail at position pos, on failure clear the area and retry
// railneed : the railtrack we want build/remove
// pos : where to do the action
// remove: true to remove the track, false to add it
// return true on success
{
local lasterr=-1;
if (remove)
	{
	if (!AIRail.IsRailTile(pos))	return true;
					else	return AIRail.RemoveRailTrack(pos, railneed);
	}
if (!AIRail.BuildRailTrack(pos,railneed))
	{
	lasterr=AIError.GetLastError();
	switch (lasterr)
		{
		case	AIError.ERR_AREA_NOT_CLEAR:
			cTileTools.DemolishTile(pos);
			break;
		default:
			DInfo("Cannot build rail track at "+pos,1,"DropRailHere");
			return false;
		}
	}
else	return true;
return AIRail.BuildRailTrack(pos,railneed);
}

function cBuilder::RailCleaner(targetTile)
// clean the tile by removing rails/depot/station... we found there
// targetTile : the tile to remove or an AIList of tiles to remove
{
local many=AIList();
if (targetTile instanceof ::AIList)	many.AddList(targetTile);
					else	many.AddItem(targetTile,0);
if (many.IsEmpty())	return true;
local voisin=[AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)]; // SE, NW, SW, NE
local trackMap=AIList();
local seek=null;
trackMap.AddItem(AIRail.RAILTRACK_NE_SW,	0);
trackMap.AddItem(AIRail.RAILTRACK_NW_SE,	0);
trackMap.AddItem(AIRail.RAILTRACK_NW_NE,	0);
trackMap.AddItem(AIRail.RAILTRACK_SW_SE,	0);
trackMap.AddItem(AIRail.RAILTRACK_NW_SW,	0);
trackMap.AddItem(AIRail.RAILTRACK_NE_SE,	0);
foreach (tile, dummy in many)
	{
	PutSign(tile,"Z"); AIController.Sleep(40);
	if (AITile.GetOwner(tile) != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	continue;
	if (AIRail.IsRailStationTile(tile))	continue; // protect station
	if (AIRail.IsRailDepotTile(tile))
		{
		AITile.DemolishTile(tile);
		continue;
		}
	foreach (near in voisin)
		{
		while (AIRail.GetSignalType(tile,tile+near)!=AIRail.SIGNALTYPE_NONE)	AIRail.RemoveSignal(tile, tile+near);
		}
	seek=AIRail.GetRailTracks(tile);
	if (seek != 255)
		foreach (railtype, dummy in trackMap)	if ((seek & railtype) == railtype)	AIRail.RemoveRailTrack(tile,railtype);
	AIController.Sleep(1);
	}
}

function cBuilder::GetRailBitMask(rails)
// Return a nibble bitmask with each NE,SW,NW,SE direction set to 1
{
local NE = 1; // we will use them as bitmask
local	SW = 2;
local	NW = 4;
local	SE = 8;
local trackMap=AIList();
trackMap.AddItem(AIRail.RAILTRACK_NE_SW,	NE + SW);	// AIRail.RAILTRACK_NE_SW
trackMap.AddItem(AIRail.RAILTRACK_NW_SE,	NW + SE);	// AIRail.RAILTRACK_NW_SE
trackMap.AddItem(AIRail.RAILTRACK_NW_NE,	NW + NE);	// AIRail.RAILTRACK_NW_NE
trackMap.AddItem(AIRail.RAILTRACK_SW_SE,	SW + SE);	// AIRail.RAILTRACK_SW_SE
trackMap.AddItem(AIRail.RAILTRACK_NW_SW,	NW + SW);	// AIRail.RAILTRACK_NW_SW
trackMap.AddItem(AIRail.RAILTRACK_NE_SE,	NE + SE);	// AIRail.RAILTRACK_NE_SE
if (rails==255)	return 0;
local railmask=0;
foreach (tracks, value in trackMap)
	{
	if ((rails & tracks)==tracks)	{ railmask=railmask | value; }
	if (railmask==(NE+SW+NW+SE))	return railmask; // no need to test further
	}
return railmask;
}

function cBuilder::AreRailTilesConnected(tilefrom, tileto)
// Look at tilefront and build rails to connect that tile to its neightbourg tiles that are us with rails
{
local NE = 1; // we will use them as bitmask
local	SW = 2;
local	NW = 4;
local	SE = 8;
local direction=cBuilder.GetDirection(tilefrom, tileto);
local tilefrom_mask=cBuilder.GetRailBitMask(AIRail.GetRailTracks(tilefrom));
local tileto_mask=cBuilder.GetRailBitMask(AIRail.GetRailTracks(tileto));
local tilefrom_need, tileto_need=0;
switch (direction)
	{
	case	0: // SE-NW
		tilefrom_need=SE;
		tileto_need=NW;
		break;
	case	1: // NW-SE
		tilefrom_need=NW;
		tileto_need=SE;
		break;
	case	2: // SW-NE
		tilefrom_need=SW;
		tileto_need=NE;
		break;
	case	3: // NE-SW
		tilefrom_need=NE;
		tileto_need=SW;
		break;
	}
print("from mask="+tilefrom_mask+" from need="+tilefrom_need+"    tileto_mask="+tileto_mask+" tileto_need="+tileto_need);
AIController.Sleep(10);
if ( (tilefrom_mask & tilefrom_need)==tilefrom_need && (tileto_mask & tileto_need)==tileto_need)	return true;
print("not connect");
return false;
}

function cBuilder::RailConnectorSolver(tilepos, tilefront, fullconnect=true)
// Look at tilefront and build rails to connect that tile to its neightbourg tiles that are us with rails
// tilepos : tile where we have a rail/depot...
// tilefront: tile where we want to connect tilepos to
// fullconnect: set to true to allow the tilefront to also connect neighbourg tiles to each other (this might not respect 90 turn settings!)
// so if tilepos=X, tilefront=Y, 2 tiles near Y as A & B
// without fullconnect -> it create AX, BX and with it, also do AB
// only return false if we fail to build all we tracks need at tilefront (and raise critical error)
{
local voisin=[AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)]; // SE, NW, SW, NE
local NE = 1; // we will use them as bitmask
local	SW = 2;
local	NW = 4;
local	SE = 8;
local trackMap=AIList();
trackMap.AddItem(AIRail.RAILTRACK_NE_SW,	NE + SW);	// AIRail.RAILTRACK_NE_SW
trackMap.AddItem(AIRail.RAILTRACK_NW_SE,	NW + SE);	// AIRail.RAILTRACK_NW_SE
trackMap.AddItem(AIRail.RAILTRACK_NW_NE,	NW + NE);	// AIRail.RAILTRACK_NW_NE
trackMap.AddItem(AIRail.RAILTRACK_SW_SE,	SW + SE);	// AIRail.RAILTRACK_SW_SE
trackMap.AddItem(AIRail.RAILTRACK_NW_SW,	NW + SW);	// AIRail.RAILTRACK_NW_SW
trackMap.AddItem(AIRail.RAILTRACK_NE_SE,	NE + SE);	// AIRail.RAILTRACK_NE_SE
PutSign(tilefront,"X");
// dirValid is [VV,II] VV=valid to go, II=invalid when no 90 turn is allow
// and for each direction we're going in order SE, NW, SW, NE
local dirValid=[
	NW,0, SE,0, NE,SE, SW,SE,  	// SE->NW (when we go from->to)- 0
	NW,0, SE,0, NE,NW, SW,NW,  	// NW->SE - 1
	NW,SW, SE,SW, NE,0, SW,0, 	// SW->NE - 2
	NW,NE, SE,NE, NE,0, SW,0 	// NE->SW - 3
	];
local workTile=[];
for (local i=0; i < 4; i++)	workTile.push(tilefront+voisin[i]);
if (AITile.GetDistanceManhattanToTile(tilepos,tilefront) > 1)
	{ DError("We must use two tiles close to each other !",1,"RailConnectorSolver"); return false; }
local direction=cBuilder.GetDirection(tilepos, tilefront);
local checkArray=[];
local connections=[];
for (local i=0; i<8; i++)	checkArray.push(dirValid[i+(8*direction)]);
local tile=null;
local tileposRT=AIRail.GetRailType(tilepos);
local connection=false;
local checkOrder=[];
checkOrder.push(direction);
for (local i=0; i <4; i++)
	{
	if (i==direction)	continue;
	checkOrder.push(i);
	}
local startposValid=false;
for (local kk=0; kk<4; kk++)
	{
	local i = checkOrder[kk];
	tile=workTile[i];
	local trackinfo=AIRail.GetRailTracks(tile);
	local test=null;
	if (trackinfo==255)
		{ // maybe a tunnel, depot or bridge that "could" also be valid entries
		local testdir=null;
		if (AIRail.IsRailDepotTile(tile))
			{
			test=AIRail.GetRailDepotFrontTile(tile);
			testdir=cBuilder.GetDirection(tile, test);
			DInfo("Rail depot found",2,"RailConnectorSolver");
			if (test==tilefront)
				trackinfo= (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
			}
		if (AITunnel.IsTunnelTile(tile))
			{
			test=AITunnel.GetOtherTunnelEnd(tile);
			testdir=cBuilder.GetDirection(tile, test);
			DInfo("Tunnel found",2,"RailConnectorSolver");
			trackinfo = (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
			}
		if (AIBridge.IsBridgeTile(tile))
			{
			test=AIBridge.GetOtherBridgeEnd(tile);
			testdir=cBuilder.GetDirection(tile, test);
			DInfo("Bridge found",2,"RailConnectorSolver");
			trackinfo = (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
			}
		}
	if (trackinfo==255)	{ DInfo("No rails found",2,"RailConnectorSolver"); continue; } // no rails here
	test=AITile.GetOwner(tile);
	if (test != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	{ DInfo("Not a rail of our company",2,"RailConnectorSolver"); PutSign(tile,"N"); continue; } // we don't own that
	test = AIRail.GetRailType(tile);
	if (test != tileposRT)	{ DInfo("Rails are not of the same type",2,"RailConnectorSolver"); continue; } // not the same rail type
	
	local validbit=checkArray[0+(i*2)];
	local turnbit=checkArray[1+(i*2)];
	local bitcheck=0;
	local connection=false;
	local turn_enable=(AIGameSettings.GetValue("forbid_90_deg") == 0);
	foreach (trackitem, trackmapping in trackMap)
		{
		if ((trackinfo & trackitem) == trackitem)	// we have that track
			{
			if ((trackmapping & validbit) == validbit)	connection=true;
			if (connection && i==direction)	{ DInfo("Starting rails have entry we can work on",2,"RailConnectorSolver"); startposValid=true; break; }
			if (!startposValid)	continue;
			if (connection)	{ connections.push(tile); } // save status to later connect everyone if need, avoid 90 turn check
			if (!turn_enable && turnbit!=0)	if ((trackmapping & turnbit) == turnbit)	connection=false;
			}
		if (connection && startposValid)
			{
			if (!AIRail.BuildRail(tilepos, tilefront, tile))
				{
				INSTANCE.builder.IsCriticalError();
				if (INSTANCE.builder.CriticalError)	return false;
				}
			else	{ break; }
			}
		}
	}
if (connections.len()>1 && fullconnect && startposValid)
	{
	foreach (con1 in connections)
		foreach (con2 in connections)
			{
			if (con1 != con2 && !AIRail.BuildRail(con1, tilefront, con2))
				{
				INSTANCE.builder.IsCriticalError();
				if (INSTANCE.builder.CriticalError)	return false;
				}
			}
	}
return true;
}

