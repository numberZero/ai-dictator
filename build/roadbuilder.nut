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

class MyRoadPF extends RoadPathFinder {
	_cost_level_crossing = null;
}
function MyRoadPF::_Cost(path, new_tile, new_direction, self)
{
	local cost = ::RoadPathFinder._Cost(path, new_tile, new_direction, self);
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_RAIL)) cost += self._cost_level_crossing;
	return cost;
}

function MyRoadPF::_GetTunnelsBridges(last_node, cur_node, bridge_dir)
{
	local slope = AITile.GetSlope(cur_node);
	if (slope == AITile.SLOPE_FLAT && AITile.IsBuildable(cur_node + (cur_node - last_node))) return [];
	local tiles = [];
	for (local i = 2; i < this._max_bridge_length; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = cur_node + i * (cur_node - last_node);
		if (!bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), cur_node, target)) {
			tiles.push([target, bridge_dir]);
		}
	}

	if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(cur_node);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(cur_node, other_tunnel_end);
	local prev_tile = cur_node + (cur_node - other_tunnel_end) / tunnel_length;
	if (AITunnel.GetOtherTunnelEnd(other_tunnel_end) == cur_node && tunnel_length >= 2 &&
			prev_tile == last_node && tunnel_length < _max_tunnel_length && AITunnel.BuildTunnel(AIVehicle.VT_ROAD, cur_node)) {
		tiles.push([other_tunnel_end, bridge_dir]);
	}
	return tiles;
}

class MyRailPF extends RailPathFinder {
	_cost_level_crossing = null;
}
function MyRailPF::_Cost(path, new_tile, new_direction, self)
{
	local cost = ::RailPathFinder._Cost(path, new_tile, new_direction, self);
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_ROAD)) cost += self._cost_level_crossing;
	return cost;
}

function cBuilder::CanBuildRoadStation(tile, direction)
{
if (!AITile.IsBuildable(tile)) return false;
local offsta = null;
local offdep = null;
local middle = null;
local middleout = null;
switch (direction)
	{
	case DIR_NE:
		offdep = AIMap.GetTileIndex(0,-1);  
		offsta = AIMap.GetTileIndex(-1,0);
		middle = AITile.CORNER_W;
		middleout = AITile.CORNER_N;
	break;
	case DIR_NW:
		offdep = AIMap.GetTileIndex(1,0);
		offsta = AIMap.GetTileIndex(0,-1);
		middle = AITile.CORNER_S;
		middleout = AITile.CORNER_W;
	break;
	case DIR_SE:
		offdep = AIMap.GetTileIndex(-1,0);
		offsta = AIMap.GetTileIndex(0,1);
		middle = AITile.CORNER_N;
		middleout = AITile.CORNER_E;
	break;
	case DIR_SW:
		offdep = AIMap.GetTileIndex(0,1);
		offsta = AIMap.GetTileIndex(1,0);
		middle = AITile.CORNER_E;
		middleout = AITile.CORNER_S;
	break;
	}
statile = tile; deptile = tile + offdep;
stafront = tile + offsta; depfront = tile + offsta + offdep;
if (!AITile.IsBuildable(deptile)) {return false;}
if (!AITile.IsBuildable(stafront) && !AIRoad.IsRoadTile(stafront)) {return false;}
if (!AITile.IsBuildable(depfront) && !AIRoad.IsRoadTile(depfront)) {return false;}
local height = AITile.GetMaxHeight(statile);
local tiles = AITileList();
tiles.AddTile(statile);
tiles.AddTile(stafront);
tiles.AddTile(deptile);
tiles.AddTile(depfront);
if (!AIGameSettings.GetValue("construction.build_on_slopes"))
	{
	foreach (idx, dummy in tiles)
		{
		if (AITile.GetSlope(idx) != AITile.SLOPE_FLAT) return false;
		}
	} 
else	{
	if ((AITile.GetCornerHeight(stafront, middle) != height) && (AITile.GetCornerHeight(stafront, middleout) != height)) return false;
	}
	foreach (idx, dummy in tiles)
		{
		if (AITile.GetMaxHeight(idx) != height) return false;
		if (AITile.IsSteepSlope(AITile.GetSlope(idx))) return false;
		}
local test = AITestMode();
if (!AIRoad.BuildRoad(stafront, statile))
	{
	if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
if (!AIRoad.BuildRoad(depfront, deptile))
	{
	if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
if (!AIRoad.BuildRoad(stafront, depfront))
	{
	if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
if (!AIRoad.BuildRoadStation(statile, stafront, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) return false;
if (!AIRoad.BuildRoadDepot(deptile, depfront)) return false;
test = null;
return true;
}

function cBuilder::BuildAndStickToRoad(tile, stationtype, stalink=-1)
/**
* Find a road near tile and build a road depot or station connected to that road
*
* @param tile tile where to put the structure
* @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
* @return -1 on error, tile position on success, CriticalError is set 
*/
{
local directions=[AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
// ok we know we are close to a road, let's find where the road is
local direction=-1;
local tooclose=false;

foreach (voisin in directions)
	{
	if (AIRoad.IsRoadTile(tile+voisin)) { direction=tile+voisin; break; }
	}
if (direction == -1)	{ DWarn("Can't find a road to stick our structure ???",2); return -1; }

if (stationtype != (AIRoad.ROADVEHTYPE_BUS+100000) && stalink == -1) // not a depot = truck or bus station need
	{
	foreach (voisin in directions) // find if the place isn't too close from another station
		{
		tooclose=AITile.IsStationTile(tile+voisin);
		if (!tooclose)	tooclose=AITile.IsStationTile(tile+voisin+voisin);
		if (tooclose)
			{
			DWarn("Road station would be too close from another station",2);
			INSTANCE.builder.CriticalError=true; // force a critical error
			return -1;
			}
		}
	}
// now build the structure, function is in stationbuilder.nut
return INSTANCE.builder.BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stalink);
}

function cBuilder::BuildRoadDepotAtTile(tile)
// Try to build a road depot at tile and nearer
{
local reusedepot=cTileTools.GetTilesAroundPlace(tile);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
reusedepot.RemoveAboveValue(8);
reusedepot.Valuate(AITile.IsWaterTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AITile.IsStationTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AIRail.IsRailTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AIRail.IsRailDepotTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AIRoad.IsRoadDepotTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AITile.GetSlope);
reusedepot.KeepValue(AITile.SLOPE_FLAT); // only flat tile filtering
reusedepot.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
reusedepot.KeepAboveValue(0);
reusedepot.Valuate(AIRoad.IsRoadTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
local newpos=-1;
foreach (tile, dummy in reusedepot)
	{
	newpos=INSTANCE.builder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000);
	if (newpos != -1)	return newpos;
	}
return -1;
}

function cBuilder::BuildRoadStation(start)
/**
* Build a road station for a route
*
* @param start true to build at source, false at destination
* @return true or false
*/
{
INSTANCE.bank.RaiseFundsBigTime();
local stationtype = null;
local rad=null;
if (AICargo.GetTownEffect(INSTANCE.route.cargoID) == AICargo.TE_PASSENGERS)
		{
		rad= AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
		stationtype = AIRoad.ROADVEHTYPE_BUS;
		}
	else	{
		rad= AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		stationtype = AIRoad.ROADVEHTYPE_TRUCK;
		}
local dir, tilelist, checklist, otherplace, istown, isneartown=null;
if (start)	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.source_location, INSTANCE.route.target_location);
		if (INSTANCE.route.source_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.sourceID);
			checklist= cTileTools.GetTilesAroundTown(INSTANCE.route.sourceID);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryProducing(INSTANCE.route.sourceID, rad);
			checklist = AITileList_IndustryProducing(INSTANCE.route.sourceID, rad);
			isneartown=true; // fake it's a town, it produce, it might be within a town (like a bank)
			istown=false;	 
			}
		otherplace=INSTANCE.route.target_location;
		}
	else	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.target_location, INSTANCE.route.source_location);
		if (INSTANCE.route.target_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.targetID);
			checklist= cTileTools.GetTilesAroundTown(INSTANCE.route.targetID);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryAccepting(INSTANCE.route.targetID, rad);
			checklist = AITileList_IndustryAccepting(INSTANCE.route.targetID, rad);
			isneartown=true; istown=false;
			}
		otherplace=INSTANCE.route.source_location;
		}
// let's see if we can stick to a road
tilelist.Sort(AIList.SORT_BY_VALUE, false); // highest values first
checklist.Valuate(AIRoad.IsRoadTile);
checklist.KeepValue(1);
if (checklist.IsEmpty())
	{
	DInfo("Cannot stick our station to a road, building classic",2);
	isneartown=false;
	}
else	{
	DInfo("Sticking station & depot to the road",2);
	}
checklist.AddList(tilelist); // re-put tiles in it in case we fail building later

if (isneartown)	{ // first, removing most of the unbuildable cases
		tilelist.Valuate(AITile.IsWaterTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AITile.IsStationTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AIRail.IsRailTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AIRail.IsRailDepotTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AIRoad.IsRoadDepotTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AITile.GetSlope);
		tilelist.KeepValue(AITile.SLOPE_FLAT); // only flat tile filtering
		tilelist.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
		tilelist.KeepAboveValue(0);
		tilelist.Valuate(AIRoad.IsRoadTile);
		tilelist.KeepValue(0);
		if (!istown && !start)	// not a town, and not start = only industry as destination
			{
			tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
			tilelist.Sort(AIList.SORT_BY_VALUE,true); // little distance first
			}
		else	{ // town or (industry at start)
			if (!istown)
	 				tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.route.cargoID, 1, 1, rad);
				else	{
					tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.route.cargoID, 1, 1, rad);
					tilelist.KeepAboveValue(7);
					}
			tilelist.Sort(AIList.SORT_BY_VALUE, false);
			}
		}
	else	{
		if (!istown)
			{
			tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
			}
		tilelist.Sort(AIList.SORT_BY_VALUE,true);
		}
DInfo("Tilelist set to "+tilelist.Count(),2);
local success = false;
local depotbuild=false;
local stationbuild=false;

deptile=-1; statile=-1;
if (isneartown)
	{
	foreach (tile, dummy in tilelist)
		{
		statile=INSTANCE.builder.BuildAndStickToRoad(tile, stationtype);
		if (statile >= 0)
			{ stationbuild = true; break; }
		}
	if (stationbuild)
		{ // try build depot closer to our station
		tilelist.Valuate(AITile.GetDistanceManhattanToTile,statile);
		tilelist.Sort(AIList.SORT_BY_VALUE, true);
		}
	foreach (tile, dummy in tilelist)
		{
		if (tile == statile) continue; // don't build on the same place as our new station
		deptile=INSTANCE.builder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000); // depot
		if (deptile >= 0)
			{ depotbuild = true; break; }
		}
	success=(depotbuild && stationbuild);
	if (success) // we have depot + station tile, pathfind to them
		{ INSTANCE.builder.BuildRoadROAD(AIRoad.GetRoadDepotFrontTile(deptile), AIRoad.GetRoadStationFrontTile(statile));	}
	}
if ((statile==-1 || deptile==-1) && !istown && isneartown)
	{ // We fail to build the station, but it's because we force build station close to roads and there is no roads
	if (statile>0)	cTileTools.DemolishTile(statile);
	if (deptile>0)	cTileTools.DemolishTile(deptile);
	isneartown=false;
	tilelist.AddList(checklist); // restore the list of original tiles
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepAboveValue(0);
	tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	tilelist.Sort(AIList.SORT_BY_VALUE, true);
	}
if (!isneartown)
	{
	foreach (tile, dummy in tilelist)
		{
		if (cBuilder.CanBuildRoadStation(tile, dir))
			{
			success = true;
			break;
			}
		else	continue;
		}
	}
if (!success) 
	{
	DInfo("Can't find a good place to build the road station !",1);
	INSTANCE.builder.CriticalError=true;
	return false;
	}
// if we are here all should be fine, we could build now
if (!isneartown)
	{
	AIRoad.BuildRoad(stafront, statile);
	AIRoad.BuildRoad(depfront, deptile);
	AIRoad.BuildRoad(stafront, depfront);
	if (!AIRoad.BuildRoadStation(statile, stafront, stationtype, AIStation.STATION_NEW))
		{
		DError("Station could not be built",1);
		return false;
		}
	if (!AIRoad.BuildRoadDepot(deptile, depfront))
		{
		DError("Depot could not be built",1);
		cTileTools.DemolishTile(statile);
		return false;
		}
	}
local newStation=cStation();
if (start)	INSTANCE.route.source_stationID=AIStation.GetStationID(statile);
	else	INSTANCE.route.target_stationID=AIStation.GetStationID(statile);
INSTANCE.route.CreateNewStation(start);
if (start)	INSTANCE.route.source.depot=deptile;
	else	INSTANCE.route.target.depot=deptile;
return true;
}

function cBuilder::PathfindRoadROAD(head1, head2)
// just pathfind the road, but still don't build it
{
local pathfinder = MyRoadPF();
pathfinder._cost_level_crossing = 1000;
pathfinder._cost_coast = 100;
pathfinder._cost_slope = 100;
pathfinder._cost_bridge_per_tile = 100;
pathfinder._cost_tunnel_per_tile = 80;
pathfinder._max_bridge_length = 20;
pathfinder.InitializePath([head1], [head2]);
local savemoney=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local pfInfo=null;
INSTANCE.bank.SaveMoney(); // thinking long time, don't waste money
pfInfo=AISign.BuildSign(head1,"Pathfinding...");
DInfo("Road Pathfinding...",1);
local path = false;
local counter=0;
while (path == false && counter < 250)
	{
	path = pathfinder.FindPath(250);
	counter++;
	AISign.SetName(pfInfo,"Pathfinding... "+counter);
	AIController.Sleep(1);
	}
// restore our money
INSTANCE.bank.RaiseFundsTo(savemoney);
if (path != null && path != false)
	{
	DInfo("Path found. (" + counter + ")",0,"BuildRoadROAD");
	AISign.RemoveSign(pfInfo);
	return path;
	}
else	{
	ClearSignsALL();
	DInfo("Pathfinding failed.",1);
	INSTANCE.builder.CriticalError=true;
	return false;
	}
}

function cBuilder::BuildRoadFrontTile(tile, targettile)
{
if (!AIRoad.IsRoadTile(targettile))
	{
	cTileTools.DemolishTile(targettile);
	AIRoad.BuildRoad(tile, targettile);
	}
return AIRoad.AreRoadTilesConnected(tile, targettile);
}

function cBuilder::CheckRoadHealth(routeUID)
// we check a route for trouble & try to solve them
// return true if no problems were found
{
local repair=cRoute.GetRouteObject(routeUID);
if (repair == null)	{ DInfo("Cannot load that route for a repair.",1); repair=INSTANCE.route; }
if (!repair.source_entry || !repair.target_entry)	return false;
local good=true;
local space="        ";
local correction=false;
local temp=null;
if (repair.route_type != AIVehicle.VT_ROAD)	return false; // only check road type
DInfo("Checking route health of #"+routeUID+" "+repair.name,1);
// check stations for trouble
// source station
correction=false;
local msg="";
local error_repair="Fixed !";
local error_error="Fail to fix it";
temp=repair.source.stationID;
if (!AIStation.IsValidStation(temp))	{ DInfo(space+" Source Station is invalid !",1); good=false; }
	else	DInfo(space+"Source station "+AIStation.GetName(temp)+"("+temp+") is valid",1);
if (good)
	{
	DInfo(space+space+"Station size : "+repair.source.locations.Count(),1);
	foreach (tile, front in repair.source.locations)
		{
		PutSign(tile, "S");
		msg=space+space+"Entry "+tile+" is ";
		if (!AIRoad.AreRoadTilesConnected(tile, front))
			{
			msg+="NOT usable. ";
			correction=INSTANCE.builder.BuildRoadFrontTile(tile, front);
			if (correction)	msg+=error_repair;
				else	{ msg+=error_error; good=false; }
			}
		else	{ msg+="usable"; }
		DInfo(msg,1);
		}
	}
// the depot

msg=space+"Source Depot "+repair.source.depot+" is ";
if (!AIRoad.IsRoadDepotTile(repair.source.depot))
	{
	msg+="invalid. ";
	if (repair.source.depot=INSTANCE.builder.BuildRoadDepotAtTile(repair.source.GetRoadStationEntry()))	msg+=error_repair;
		else	{ msg+=error_error; good=false; }
	}
else	msg+="valid";
DInfo(msg,1);
local depotfront=AIRoad.GetRoadDepotFrontTile(repair.source.depot);
if (good)
	{
	msg=space+space+"Depot entry is ";
	if (!AIRoad.AreRoadTilesConnected(repair.source.depot, depotfront))
		{
		msg+="not usable. ";
		correction=INSTANCE.builder.BuildRoadFrontTile(repair.source.depot, depotfront);
		if (correction)	msg+=error_repair;
			else	{ msg+=error_error; good=false; }
		}
	else	msg+="usable";
	DInfo(msg,1);
	}
ClearSignsALL();
// target station
correction=false;
temp=repair.target.stationID;
if (!AIStation.IsValidStation(temp))	{ DInfo(space+" Destination Station is invalid !",1); good=false; }
	else	DInfo(space+"Source station "+AIStation.GetName(temp)+"("+temp+") is valid",1);
if (good)
	{
	DInfo(space+space+"Station size : "+repair.target.locations.Count(),1);
	foreach (tile, front in repair.target.locations)
		{
		PutSign(tile, "S");
		msg=space+space+"Entry "+tile+" is ";
		if (!AIRoad.AreRoadTilesConnected(tile, front))
			{
			msg+="NOT usable. ";
			correction=INSTANCE.builder.BuildRoadFrontTile(tile, front);
			if (correction)	msg+=error_repair;
				else	{ msg+=error_error; good=false; }
			}
		else	{ msg+="usable"; }
		DInfo(msg,1);
		}
	}
// the depot

msg=space+"Destination Depot "+repair.target.depot+" is ";
if (!AIRoad.IsRoadDepotTile(repair.target.depot))
	{
	msg+="invalid. ";
	if (repair.target.depot=INSTANCE.builder.BuildRoadDepotAtTile(repair.target.GetRoadStationEntry()))	msg+=error_repair;
		else	{ msg+=error_error; good=false; }
	}
else	msg+="valid";
DInfo(msg,1);
local depotfront=AIRoad.GetRoadDepotFrontTile(repair.target.depot);
if (good)
	{
	msg=space+space+"Depot entry is ";
	if (!AIRoad.AreRoadTilesConnected(repair.target.depot, depotfront))
		{
		msg+="not usable. ";
		correction=INSTANCE.builder.BuildRoadFrontTile(repair.target.depot, depotfront);
		if (correction)	msg+=error_repair;
			else	{ msg+=error_error; good=false; }
		}
	else	msg+="usable";
	DInfo(msg,1);
	}
ClearSignsALL();

// check the road itself
if (good)
	{
	local src_depot_front=AIRoad.GetRoadDepotFrontTile(repair.source.depot);
	local tgt_depot_front=AIRoad.GetRoadDepotFrontTile(repair.target.depot);
	foreach (tile, front in repair.source.locations)
		{
		msg=space+"Connnection from source station -> Entry "+tile+" to its depot : ";
		if (!INSTANCE.builder.RoadRunner(front, src_depot_front, AIVehicle.VT_ROAD))
			{
			msg+="Damage & ";
			INSTANCE.builder.BuildRoadROAD(front, src_depot_front);
			if (!INSTANCE.builder.RoadRunner(front, src_depot_front, AIVehicle.VT_ROAD))
				{ msg+=error_error; good=false;  cTileTools.DemolishTile(repair.source.depot); }
			else	{ msg+=error_repair; }
			DInfo(msg,1);
			}
		else	{ DInfo(msg+"Working",1); }
		ClearSignsALL();
		}
	foreach (tile, front in repair.target.locations)
		{
		msg=space+"Connnection from destination station -> Entry "+tile+" to its depot : ";
		if (!INSTANCE.builder.RoadRunner(front, tgt_depot_front, AIVehicle.VT_ROAD))
			{
			msg+="Damage & ";
			INSTANCE.builder.BuildRoadROAD(front, tgt_depot_front);
			if (!INSTANCE.builder.RoadRunner(front, tgt_depot_front, AIVehicle.VT_ROAD))
				{ msg+=error_error; good=false; cTileTools.DemolishTile(repair.target.depot); }
			else	{ msg+=error_repair; }
			DInfo(msg,1);
			}
		else	{ DInfo(msg+"Working",1); }
		ClearSignsALL();
		}
	msg=space+"Connection from source station to target station : "
	local one = repair.source.GetRoadStationEntry();
	local two = repair.target.GetRoadStationEntry();
	if (!INSTANCE.builder.RoadRunner(one, two, AIVehicle.VT_ROAD))
		{
		msg+="Damage & ";
		INSTANCE.builder.BuildRoadROAD(one, two);
		if (!INSTANCE.builder.RoadRunner(one, two, AIVehicle.VT_ROAD))
			{ msg+=error_error; good=false; }
		else	{ msg+=error_repair; }
		DInfo(msg,1);
		}
	else	{ DInfo(msg+"Working",1); }
	}
ClearSignsALL();
return good;
}

function cBuilder::ConstructRoadROAD(path)
// this construct (build) the road we get from path
{
INSTANCE.bank.RaiseFundsBigTime();
DInfo("Building road structure",0);
local prev = null;
local waserror = false;
local counter=0;
holes=[];
while (path != null)
	{
	local par = path.GetParent();
	if (par != null)
		{
		if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1)
			{
			if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile()))
				{
				local error = AIError.GetLastError();
				if (error != AIError.ERR_ALREADY_BUILT)
					{
					if (error == AIError.ERR_VEHICLE_IN_THE_WAY)
						{
						DInfo("A vehicle was in the way while I was building the road. Retrying...",1);
						counter = 0;
						AIController.Sleep(75);
						while (!AIRoad.BuildRoad(path.GetTile(), par.GetTile()) && counter < 3)
							{
							counter++;
							AIController.Sleep(75);
							}
						if (counter > 2)
							{
							DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
							cBuilder.ReportHole(path.GetTile(), par.GetTile(), waserror);
							waserror = true;
							}
						 else	{
							if (waserror)
								{
								waserror = false;
								holes.push([holestart, holeend]);
								}
							}
						}
					else	{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
						cBuilder.ReportHole(path.GetTile(), par.GetTile(), waserror);
						waserror = true;
						}
					}
			 	else	{
					if (waserror)
						{
						waserror = false;
						holes.push([holestart, holeend]);
						}
					}
				}
		 	else 	{
				if (waserror)
					{
					waserror = false;
					holes.push([holestart, holeend]);
					}
				}
			}
	 	else	{
			if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile()))
				{
				if (AIRoad.IsRoadTile(path.GetTile())) cTileTools.DemolishTile(path.GetTile());
				if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile())
					{
					if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile()))
						{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH)
							{
							DInfo("That tunnel would be too expensive. Construction aborted.",1);
							return false;
							}
						cBuilder.ReportHole(prev.GetTile(), par.GetTile(), waserror);
						waserror = true;
						}
					else	{
						if (waserror)
							{
							waserror = false;
							holes.push([holestart, holeend]);
							}
						}
					}
			 	else	{
					local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
					bridgelist.Valuate(AIBridge.GetMaxSpeed);
					if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgelist.Begin(), path.GetTile(), par.GetTile()))
						{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH)
							{
							DInfo("That bridge would be too expensive. Construction aborted.",1);
							return false;
							}
						cBuilder.ReportHole(prev.GetTile(), par.GetTile(), waserror);
						waserror = true;
						}
					 else	{
						if (waserror)
							{
							waserror = false;
							holes.push([holestart, holeend]);
							}
						}
					}
				}
			}
		}
	prev = path;
	path = par;
	}
if (waserror)
	{
	waserror = false;
	holes.push([holestart, holeend]);
	}
if (holes.len() > 0)
	{ DInfo("Road construction fail...",1); return false; }
return true;
}


function cBuilder::BuildRoadROAD(head1, head2)
// pathfind+building the road
// we return true or false if it fail
{
local path= false;
path = INSTANCE.builder.PathfindRoadROAD(head1, head2);
if (path != null && path != false)
	{
	return INSTANCE.builder.ConstructRoadROAD(path);
	}
else	{ return false;	}
}

function cBuilder::RoadFindCompatibleDepot(tile)
/**
* Try to find an existing road depot near tile and reuse it
*
* @param tile the tile to search the depot
* @return -1 on failure, depot location on success
*/
{
local reusedepot=cTileTools.GetTilesAroundPlace(tile);
reusedepot.Valuate(AIRoad.IsRoadDepotTile);
reusedepot.KeepValue(1);
reusedepot.Valuate(AITile.GetOwner);
local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
reusedepot.KeepValue(weare);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
reusedepot.RemoveAboveValue(10);

local newdeploc=-1;
if (!reusedepot.IsEmpty())
	{
	newdeploc=reusedepot.Begin();
	}
return newdeploc;
}

function cBuilder::RoadStationNeedUpgrade(roadidx,start)
/**
* Upgrade a road station.
* @param roadidx index of the route to upgrade
* @param start true to upgrade source station, false for destination station
* @return true or false
*/
{
//local new_location=[AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(-1,0), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,-1), AIMap.GetTileIndex(-1,1), AIMap.GetTileIndex(1,-1), AIMap.GetTileIndex(1,1)];
// left, right, behind middle, front middle, behind left, behind right, front left, front right
//local new_facing=[AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0), AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1)];
// 0 will be same as original station, north, south, east, west
local road=cRoute.GetRouteObject(roadidx);
if (road == null)	return false;
local work=null;
if (start)	work=road.source;
	else	work=road.target;
if (work == null)	return;
DInfo("Upgrading road station "+AIStation.GetName(work.stationID),0);
local depot_id=work.depot;
DInfo("Road depot is at "+depot_id,2);
// first lookout where is the station, where is its entry, where is the depot, where is the depot entry
local sta_pos=AIStation.GetLocation(work.stationID);
local sta_front=AIRoad.GetRoadStationFrontTile(sta_pos);
local dep_pos=depot_id;
local dep_front=AIRoad.GetRoadDepotFrontTile(depot_id);
local depotdead=false;
local statype= AIRoad.ROADVEHTYPE_BUS;
if (work.stationType == AIStation.STATION_TRUCK_STOP)	statype=AIRoad.ROADVEHTYPE_TRUCK;
local deptype=AIRoad.ROADVEHTYPE_BUS+100000; // we add 100000
local new_sta_pos=-1;
local new_dep_pos=-1;
local success=false;
local upgradepos=[];
local facing=INSTANCE.builder.GetDirection(sta_pos, sta_front);
local p_left=0;
local p_right=0;
local p_back=0;
switch (facing)
	{
	case DIR_NW:
		p_left = AIMap.GetTileIndex(1,0);
		p_right =AIMap.GetTileIndex(-1,0);
		p_back = AIMap.GetTileIndex(0,-1);
		PutSign(sta_pos,"NW");
	break;
	case DIR_NE:
		p_left = AIMap.GetTileIndex(0,-1);
		p_right =AIMap.GetTileIndex(0,1);
		p_back = AIMap.GetTileIndex(-1,0);
		PutSign(sta_pos,"NE");
	break;
	case DIR_SW: // facing left ok
		p_left = AIMap.GetTileIndex(0,1);
		p_right =AIMap.GetTileIndex(0,-1); 
		p_back = AIMap.GetTileIndex(1,0);
		PutSign(sta_pos,"SW");
	break;
	case DIR_SE: // facing sud
		p_left =AIMap.GetTileIndex(-1,0);
		p_right = AIMap.GetTileIndex(1,0);
		p_back = AIMap.GetTileIndex(0,1);
		PutSign(sta_pos,"SE");
	break;
	}
PutSign(sta_pos+p_left,"L");
PutSign(sta_pos+p_right,"R");
PutSign(sta_pos+p_back,"B");
DInfo("Size :"+work.size,2);
INSTANCE.NeedDelay(30);
if (work.size == 1)
	{
	if (!AIRoad.IsRoadTile(sta_front+p_left))
		{ cTileTools.DemolishTile(sta_front+p_left); AIRoad.BuildRoad(sta_front, sta_front+p_left); }
	if (!AIRoad.IsRoadTile(sta_front+p_right))
		{ cTileTools.DemolishTile(sta_front+p_right); AIRoad.BuildRoad(sta_front, sta_front+p_right); }
	}
// possible entry + location of station
// these ones = left, right, front (other side of road), frontleft, frontright
upgradepos.push(sta_front+p_left);
upgradepos.push(sta_pos+p_left);	// same left
upgradepos.push(sta_front+p_right);
upgradepos.push(sta_pos+p_right); // same right
upgradepos.push(sta_front+p_left);
upgradepos.push(sta_front+p_back+p_left);
upgradepos.push(sta_front+p_right);
upgradepos.push(sta_front+p_back+p_right);
upgradepos.push(sta_front);
upgradepos.push(sta_front+p_back); // revert middle
upgradepos.push(sta_pos+p_left+p_left);
upgradepos.push(sta_pos+p_left); // same left
upgradepos.push(sta_pos+p_right+p_right);
upgradepos.push(sta_pos+p_right); // same right
upgradepos.push(sta_front+p_back+p_left+p_left);
upgradepos.push(sta_front+p_back+p_left);
upgradepos.push(sta_front+p_back+p_right+p_right);
upgradepos.push(sta_front+p_back+p_right);
local allfail=true;
for (local i=0; i < upgradepos.len()-1; i++)
	{
	local tile=upgradepos[i+1];
	local direction=upgradepos[i];
	if (AIRoad.IsRoadStationTile(tile))	continue; // don't build on a station
	if (AIRoad.IsRoadStationTile(direction))	continue;
	if (AIRoad.IsRoadTile(tile))	continue; // don't build on a road if we could
	new_sta_pos=INSTANCE.builder.BuildRoadStationOrDepotAtTile(tile, direction, statype, work.stationID);
	if (!INSTANCE.builder.CriticalError)	allfail=false; // if we have only critical errors we're doom
	INSTANCE.builder.CriticalError=false; // discard it
	if (new_sta_pos != -1)	break;
	AIController.Sleep(1);
	INSTANCE.NeedDelay(30);
	i++; if (i>=upgradepos.len())	break;
	}
DInfo("2nd try don't care roads");
// same as upper but destructive
if (new_sta_pos==-1)
	{
	for (local i=0; i < upgradepos.len()-1; i++)
		{
		local tile=upgradepos[i+1];
		local direction=upgradepos[i];
		if (AIRoad.IsRoadStationTile(tile))	continue; // don't build on a station
		if (AIRoad.IsRoadStationTile(direction))	continue;
		if (!cTileTools.DemolishTile(tile))	{ DInfo("Cannot clean the place for the new station at "+tile,1); }
		new_sta_pos=INSTANCE.builder.BuildRoadStationOrDepotAtTile(tile, direction, statype, work.stationID);
		if (!INSTANCE.builder.CriticalError)	allfail=false; // if we have only critical errors we're doom
		INSTANCE.builder.CriticalError=false; // discard it
		if (new_sta_pos != -1)	break;
		AIController.Sleep(1);
		INSTANCE.NeedDelay(30);
		i++; if (i>=upgradepos.len())	break;
		}
	}

if (new_sta_pos == dep_pos)	{ depotdead = true; }
if (new_sta_pos == dep_front)
	{
	depotdead=true; // the depot entry is now block by the station
	cTileTools.DemolishTile(dep_pos);
	}
if (depotdead)	
	{
	DWarn("Road depot was destroy while upgrading",1);
	new_dep_pos=INSTANCE.builder.BuildRoadDepotAtTile(new_sta_pos);
	work.depot=new_dep_pos;
	INSTANCE.builder.CriticalError=false;
	// Should be more than enough
	}
if (new_sta_pos > -1)
	{
	DInfo("Station "+AIStation.GetName(work.stationID)+" has been upgrade",0);
	local loc=AIStation.GetLocation(work.stationID);
	work.locations=cTileTools.FindStationTiles(loc);
	foreach(loc, dummy in work.locations)	work.locations.SetValue(loc, AIRoad.GetRoadStationFrontTile(loc));
	work.size=work.locations.Count();
	DInfo("New station size: "+work.size+"/"+work.maxsize,2);
	INSTANCE.builder.BuildRoadROAD(AIRoad.GetRoadStationFrontTile(new_sta_pos), AIRoad.GetRoadDepotFrontTile(work.depot));
	}
else	{ // fail to upgrade station
	DInfo("Failure to upgrade "+AIStation.GetName(work.stationID),1);
	if (allfail)
		{
		work.maxsize=work.size;
		DInfo("Cannot upgrade "+AIStation.GetName(work.stationID)+" anymore !",1);
		}
	success=false;
	}
foreach (uid, dummy in work.owner)	{ INSTANCE.builder.RouteIsDamage(uid); }
// ask ourselves a check for every routes that own that station, because station or depot might have change
return success;
}

function cBuilder::BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stationnew)
/**
* Build a road depot or station, add tile to blacklist on critical failure
* Also build the entry tile with road if need. Try also to find a compatible depot near the wanted position and re-use it
*
* @param tile the tile where to put the structure
* @param direction the tile where the structure will be connected
* @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
* @param stationnew invalid station id to build a new station, else joint the station with stationid
* @return tile position on success. -1 on error, set CriticalError
*/
{
// before spending money on a "will fail" structure, check the structure could be connected to a road
if (AITile.IsStationTile(tile))	return -1; // don't destroy a station, might even not be our
INSTANCE.bank.RaiseFundsBigTime(); 
if (!AIRoad.IsRoadTile(direction))
	{
	if (!cTileTools.DemolishTile(direction))
		{
		DWarn("Can't remove the tile front structure to build a road at "+direction,2); PutSign(direction,"X");
		INSTANCE.builder.IsCriticalError();
		return -1;
		}
	}

if (!AIRoad.AreRoadTilesConnected(direction,tile))
	{
	if (!AIRoad.BuildRoad(direction,tile))
		{
		DWarn("Can't build road entrance for the structure",2);
		INSTANCE.builder.IsCriticalError();
		return -1;
		}
	}
INSTANCE.builder.CriticalError=false;
if (!cTileTools.DemolishTile(tile))
	{
	DWarn("Can't remove the structure tile position at "+tile,2); PutSign(tile,"X");
	INSTANCE.builder.IsCriticalError();
	return -1;
	}
local success=false;
local newstation=0;
if (AIStation.IsValidStation(stationnew))	newstation=stationnew;
						else	newstation=AIStation.STATION_NEW;
if (stationtype == (AIRoad.ROADVEHTYPE_BUS+100000))
	{
	INSTANCE.bank.RaiseFundsBigTime();
	// first let's hack another depot if we can
	local hackdepot=INSTANCE.builder.RoadFindCompatibleDepot(tile);
	if (hackdepot == -1)	success=AIRoad.BuildRoadDepot(tile,direction);
			else	{
				tile=hackdepot;
				direction=AIRoad.GetRoadDepotFrontTile(tile);
				success=true;
				}
	PutSign(tile,"D");
	if (!success)
		{
		DWarn("Can't built a road depot at "+tile,2);
		INSTANCE.builder.IsCriticalError();
		}
	else	{
		if (hackdepot == -1)	DInfo("Built a road depot at "+tile,0);
				else	DInfo("Found a road depot near "+tile+", reusing that one",0);
		}
	}
else	{
	INSTANCE.bank.RaiseFundsBigTime(); ClearSignsALL();
	DInfo("Road info: "+tile+" direction"+direction+" type="+stationtype+" mod="+newstation,2);
	PutSign(tile,"s"); PutSign(direction,"c");
	success=AIRoad.BuildRoadStation(tile, direction, stationtype, newstation);
	if (!success)
		{
		DWarn("Can't built the road station at "+tile,2);
		INSTANCE.builder.IsCriticalError();
		}
	else	DInfo("Built a road station at "+tile,0);
	}
if (!success)
	{
	return -1;
	}
else	{
	if (!AIRoad.AreRoadTilesConnected(tile, direction))
		if (!AIRoad.BuildRoad(tile, direction))
		{
		DWarn("Fail to connect the road structure with the road in front of it",2);
		INSTANCE.builder.IsCriticalError();
		if (!cTileTools.DemolishTile(tile))
			{
			DWarn("Can't remove bad road structure !",2);
			}
		return -1;
		}
	return tile;
	}
}

function cBuilder::RoadRunner(source, target, road_type, walkedtiles=null, origin=null)
// Follow all directions to walk through the path starting at source, ending at target
// check if the path is valid by using road_type (railtype, road)
// return true if we reach target by running the path
{
local max_wrong_direction=15;
if (origin == null)	origin=AITile.GetDistanceManhattanToTile(source, target);
if (walkedtiles == null)	{ walkedtiles=AIList(); }
local valid=false;
local direction=null;
local found=(source == target);
local directions=[AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
foreach (voisin in directions)
	{
	direction=source+voisin;
	if (AIBridge.IsBridgeTile(source) || AITunnel.IsTunnelTile(source))
		{
		local endat=null;
		endat=AIBridge.IsBridgeTile(source) ? AIBridge.GetOtherBridgeEnd(source) : AITunnel.GetOtherTunnelEnd(source);
		// i will jump at bridge/tunnel exit, check tiles around it to see if we are connect to someone (guessTile)
		// if we are connect to someone, i reset "source" to be "someone" and continue
		local guessTile=null;	
		foreach (where in directions)
			{
			if (road_type == AIVehicle.VT_ROAD)
				if (AIRoad.AreRoadTilesConnected(endat, endat+where))	{ guessTile=endat+where; }
			if (road_type == AIVehicle.VT_RAIL)
				if (cBuilder.AreRailTilesConnected(endat, endat+where))	{ guessTile=endat+where; }
			}
		if (guessTile != null)
			{
			source=guessTile;
			direction=source+voisin;
			}
		}
	if (road_type==AIVehicle.VT_ROAD)	valid=AIRoad.AreRoadTilesConnected(source, direction);
	if (road_type==AIVehicle.VT_RAIL)	valid=cBuilder.AreRailTilesConnected(source, direction);
	local currdistance=AITile.GetDistanceManhattanToTile(direction, target);
	if (currdistance > origin+max_wrong_direction)	{ valid=false; }
	if (walkedtiles.HasItem(direction))	{ valid=false; } 
	if (valid)	walkedtiles.AddItem(direction,0);
	if (valid && INSTANCE.debug)	PutSign(direction,"*");
	//if (INSTANCE.debug) DInfo("Valid="+valid+" curdist="+currdistance+" origindist="+origin+" source="+source+" dir="+direction+" target="+target,2);
	if (!found && valid)	found=INSTANCE.builder.RoadRunner(direction, target, road_type, walkedtiles, origin);
	if (found) return found;
	}
return found;
}

function cBuilder::IsRoadStationBusy(stationid)
// Check if a road station is busy and return the vehicle list that busy it
// Station must be AIStation.StationType==STATION_TRUCK_STOP
// We will valuate it with cargo type each vehicle use before return it
// Return false if not
{
if (!AIStation.HasStationType(stationid,AIStation.STATION_TRUCK_STOP))	return false;
local veh_using_station=AIVehicleList_Station(stationid);
if (veh_using_station.IsEmpty())	return false;
local station_tiles=cTileTools.FindRoadStationTiles(AIStation.GetLocation(stationid));
local station_index=INSTANCE.chemin.GListGetStationIndex(stationid);
if (station_index == false)	return false;
local station_obj=INSTANCE.chemin.GListGetItem(station_index);
veh_using_station.Valuate(AITile.GetDistanceManhattanToTile, AIStation.GetLocation(stationid));
}


