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

function cBuilder::DeleteStationSourceOrDestination(idx, start)
// remove a start or end station from idx
// check no one else use it before doing that
{
local exist=false;
local obj=root.chemin.RListGetItem(idx);
local realidobj=root.builder.GetStationID(idx,start);
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	if (i == idx) continue; // ignore ourselves
	local temp=root.chemin.RListGetItem(i);
	if (!temp.ROUTE.isServed) continue; // we need an already built route, even our isn't ready
	local realidtemp=root.builder.GetStationID(i,start);
	if (realidtemp == realidobj)
		{
		DInfo("Can't delete station "+AIStation.GetName(realidobj)+" ! Station is use by another route",0);
		return false;
		}
	}
// didn't find someone else use it

// check if we have a vehicle using it
root.carrier.VehicleGroupSendToDepotAndSell(idx);
local vehcheck=AIVehicleList_Station(realidobj);
if (!vehcheck.IsEmpty())
	{
	DInfo("Can't delete station "+AIStation.GetName(realidobj)+" ! Station is use by "+vehcheck.Count()+" vehicles",0);
	return false;
	}
local wasnamed=AIStation.GetName(realidobj);
if (!AITile.DemolishTile(AIStation.GetLocation(realidobj))) return false;
DInfo("Removing station "+wasnamed+" unused by anyone",0);
local fakeid=-1;
if (start)	fakeid=obj.ROUTE.src_station;
	else	fakeid=obj.ROUTE.dst_station;
for (local j=0; j < root.chemin.RListGetSize(); j++)
	{
	local road=root.chemin.RListGetItem(j);
	if (road.ROUTE.src_station >= fakeid) road.ROUTE.src_station--;	
	if (road.ROUTE.dst_station >= fakeid) road.ROUTE.dst_station--;
	root.chemin.RListUpdateItem(j,road);
	}
root.chemin.GListDeleteItem(fakeid);
return true;
}

function cBuilder::DeleteDepot(tile)
{
local isDepot=(AIMarine.IsWaterDepotTile(tile) || AIRoad.IsRoadDepotTile(tile) || AIRail.IsRailDepotTile(tile));
if (isDepot)	cTileTools.DemolishTile(tile);
}

function cBuilder::DeleteStation(idx)
{
local realidobj=root.builder.GetStationID(idx,true);
local depot=null;
if (realidobj!=-1)
	{
	depot=root.builder.GetDepotID(idx,true);
	root.builder.DeleteDepot(depot);
	root.builder.DeleteStationSourceOrDestination(idx,true);
	}
realidobj=root.builder.GetStationID(idx,false);
if (realidobj!=-1)
	{
	depot=root.builder.GetDepotID(idx,false);
	root.builder.DeleteDepot(depot);
	root.builder.DeleteStationSourceOrDestination(idx,false);
	}
}

function cBuilder::RouteIsInvalid(idx)
// remove vehicles using that route & remove stations on that route if possible
{
root.carrier.VehicleGroupSendToDepotAndSell(idx);
root.builder.DeleteStation(idx);
}

function cBuilder::RouteDelete(idx)
// Delete a route, we may have vehicule on it...
{
root.builder.RouteIsInvalid(idx);
root.chemin.RListDeleteItem(idx);
root.chemin.RemapGroupsToRoutes();
}

