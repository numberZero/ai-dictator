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

function cBuilder::DeleteStation(uid, stationid)
// Remove stationid from uid route
// check no one else use it before doing that
{
local exist=false;
local temp=cStation.GetStationObject(stationid);
if (temp.owner.Count() != 0)
	{
	DInfo("Can't delete station "+AIStation.GetName(stationid)+" ! Station is use by "+temp.owner.Count()+" route",0);
	return false;
	}
// didn't find someone else use it
// check if we have a vehicle using it
INSTANCE.carrier.VehicleGroupSendToDepotAndSell(uid);
local vehcheck=AIVehicleList_Station(stationid);
if (!vehcheck.IsEmpty())
	{
	DInfo("Can't delete station "+AIStation.GetName(stationid)+" ! Station is use by "+vehcheck.Count()+" vehicles",0);
	return false;
	}
local wasnamed=AIStation.GetName(stationid);
if (!INSTANCE.builder.DeleteDepot(temp.depot))	return false;
							else	{ DInfo("Removing depot link to station "+wasnamed,0); }
if (!AITile.DemolishTile(AIStation.GetLocation(stationid))) return false;
DInfo("Removing station "+wasnamed+" unused by anyone",0);
cStation.DeleteStation(stationid);
return true;
}

function cBuilder::DeleteDepot(tile)
{
local isDepot=(AIMarine.IsWaterDepotTile(tile) || AIRoad.IsRoadDepotTile(tile) || AIRail.IsRailDepotTile(tile));
if (isDepot)	return cTileTools.DemolishTile(tile);
}
