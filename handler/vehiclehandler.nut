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


// main class is in vehiculebuilder

function cCarrier::GetCurrentCargoType(vehID)
// return the cargoID in use by this vehicle
{
local cargoList=AICargoList();
foreach (cargoID, dummy in cargoList)
	if (AIVehicle.GetCapacity(vehID, cargoID) > 0)	return cargoID;
return -1;
}

function cCarrier::GetGroupLoadCapacity(groupID)
// return the total capacity a group of vehicle can handle
{
if (!AIGroup.IsValidGroup(groupID))	return 0;
local veh_in_group=AIVehicleList_Group(groupID);
local cargoList=AICargoList();
local total=0;
local biggest=0;
foreach (cargoID, dummy in cargoList)
	{
	veh_in_group.Valuate(AIVehicle.GetCapacity, cargoID);
	total=0;
	foreach (vehicle, capacity in veh_in_group)	total+=capacity;
	if (total > biggest)	biggest=total;
	}
return biggest;
}

function cCarrier::VehicleGetBiggestCapacityUsingStation(stationID)
// return the top capacity vehicles that use that station
{
local vehlist=AIVehicleList_Station(stationID);
vehlist.Valuate(AIEngine.GetCapacity);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
local top=0;
if (!vehlist.IsEmpty())	top=vehlist.GetValue(vehlist.Begin());
return top;
}

function cCarrier::VehicleListBusyAtAirport(stationID)
// return the list of vehicles that are waiting at the station
{
local vehicles=AIVehicleList_Station(stationID);
local tilelist=cTileTools.GetTilesAroundPlace(AIStation.GetLocation(stationID)); // grab tiles around the station
tilelist.Valuate(AIStation.GetStationID); // look all station ID there
tilelist.KeepValue(stationID); // and keep only tiles with our stationID
vehicles.Valuate(AIVehicle.GetLocation);
foreach (vehicle, location in vehicles)
	{ if (!tilelist.HasItem(location))	vehicles.SetValue(vehicle, -1); }
vehicles.RemoveValue(-1);
//DInfo(vehicles.Count()+" vehicles near that station",2);
vehicles.Valuate(AIVehicle.GetState);
vehicles.KeepValue(AIVehicle.VS_AT_STATION);
return vehicles;
}

function cCarrier::VehicleList_KeepStuckVehicle(vehicleslist)
/**
* Filter a list of vehicle to only keep running ones with a 0 speed (stuck vehicle)
* 
* @param vehicleslist The list of vehicle we should filter
* @return same list with only matching vehicles
*/
{
vehicleslist.Valuate(AIVehicle.GetState);
vehicleslist.KeepValue(AIVehicle.VS_RUNNING);
vehicleslist.Valuate(AIVehicle.GetCurrentSpeed);
vehicleslist.KeepValue(0); // non moving ones
return vehicleslist;
}

function cCarrier::VehicleList_KeepLoadingVehicle(vehicleslist)
/**
* Filter a list of vehicle to only keep ones that are loading at a station
* 
* @param vehicleslist The list of vehicle we should filter
* @return same list with only matching vehicles
*/
{
vehicleslist.Valuate(AIVehicle.GetState);
vehicleslist.KeepValue(AIVehicle.VS_AT_STATION);
return vehicleslist;
}

function cCarrier::VehicleNearStation(stationID)
/**
* return a list with all road vehicles we own near that station with VS_RUNNING && VS_AT_STATION status
*
* @param stationID the station id to check
* @return the vehicle list
*/
{
local vehicles=AIVehicleList_Station(stationID);
local tilelist=cTileTools.GetTilesAroundPlace(AIStation.GetLocation(stationID));
tilelist.Valuate(AIStation.GetStationID);
tilelist.KeepValue(stationID); // now tilelist = only the tiles of the station we were looking for
local check_tiles=AITileList();
foreach (tiles, stationid_found in tilelist)
	{
	local stationloc=AIStation.GetLocation(stationid_found);
	local upper=stationloc+AIMap.GetTileIndex(-1,-1);
	local lower=stationloc+AIMap.GetTileIndex(1,1);
	check_tiles.AddRectangle(upper,lower);
	}
vehicles.Valuate(AIVehicle.GetLocation);
foreach (vehicle, location in vehicles)
	{ if (!check_tiles.HasItem(location))	vehicles.SetValue(vehicle, -1); }
vehicles.RemoveValue(-1);
vehicles.Valuate(AIVehicle.GetState);
vehicles.RemoveValue(AIVehicle.VS_STOPPED);
vehicles.RemoveValue(AIVehicle.VS_IN_DEPOT);
vehicles.RemoveValue(AIVehicle.VS_BROKEN);
vehicles.RemoveValue(AIVehicle.VS_CRASHED);
vehicles.RemoveValue(AIVehicle.VS_INVALID);
//DInfo("VehicleListAtRoadStation = "+vehicles.Count(),2);
return vehicles;
}

function cCarrier::VehicleName(veh)
// return a vehicle string with the vehicle infos
{
if (!AIVehicle.IsValidVehicle(veh))	return "<Invalid vehicle>";
local toret=AIVehicle.GetName(veh)+"("+AIEngine.GetName(AIVehicle.GetEngineType(veh))+")";
return toret;
}

function cCarrier::VehicleGetCargoLoad(veh)
// return amout of any cargo loaded in the vehicle
{
if (!AIVehicle.IsValidVehicle(veh)) return 0;
local cargoList=AICargoList();
local amount=0;
local topamount=0;
foreach (i, dummy in cargoList)
	{
	amount=AIVehicle.GetCargoLoad(veh,i);
	if (amount > topamount)	topamount=amount;
	}
return amount;
}

function cCarrier::VehicleGetLoadingPercent(veh)
// return the % load of any cargo on a vehicle
{
if (!AIVehicle.IsValidVehicle(veh)) return 0;
local full=cCarrier.VehicleGetFullCapacity(veh);
local actual=cCarrier.VehicleGetCargoLoad(veh);
local toret=(actual * 100) / full;
return toret;
}

function cCarrier::VehicleHandleTrafficAtStation(stationID, reroute)
// if reroute this function stop all vehicles that use stationID to goto stationID
// if !rereroute this function restore vehicles orders
{
local station=cStation.GetStationObject(stationID);
local road=null;
local vehlist=null;
local veh=null;
local group=null;
foreach (ownID, dummy in station.owner)
	{
	if (ownID == 1)	continue; // ignore virtual mail route, route 0 will re-reroute route 1 already
	road=cRoute.GetRouteObject(ownID);
	if (reroute)
		{
		vehlist=AIVehicleList_Group(road.groupID);
		vehlist.Valuate(AIVehicle.GetState);
		vehlist.RemoveValue(AIVehicle.VS_STOPPED);
		vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
		vehlist.RemoveValue(AIVehicle.VS_CRASHED);
		foreach (veh, dummy in vehlist)
			if (cCarrier.ToDepotList.HasItem(veh))	vehlist.RemoveItem(veh); // remove vehicle on their way to depot
		if (vehlist.IsEmpty()) return false;
		veh=vehlist.Begin();
		local orderindex=VehicleFindDestinationInOrders(veh, stationID);
		if (orderindex != -1)
			{
			DInfo("Re-routing traffic on route "+road.name+" to ignore "+AIStation.GetName(stationID),0);
			if (!AIOrder.RemoveOrder(veh, AIOrder.ResolveOrderPosition(veh, orderindex)))
				{ DError("Fail to remove order for vehicle "+INSTANCE.carrier.VehicleName(veh),2); }
			}
		}
	else	{ INSTANCE.carrier.VehicleBuildOrders(road.groupID); }
	}
}

function cCarrier::VehicleSendToDepot(veh,reason)
// send a vehicle to depot
{
if (!AIVehicle.IsValidVehicle(veh))	return false;
if (INSTANCE.carrier.ToDepotList.HasItem(veh))	return false; // ignore ones going to depot already
INSTANCE.carrier.VehicleSetDepotOrder(veh);
local understood=false;
understood=AIVehicle.SendVehicleToDepot(veh);
if (!understood) { DInfo(INSTANCE.carrier.VehicleName(veh)+" refuse to go to depot",1,"cCarrier::VehicleSendToDepot"); }
local rr="";
local wagonnum=0;
if (reason >= DepotAction.ADDWAGON)	{ wagonnum=reason-DepotAction.ADDWAGON; reason=DepotAction.ADDWAGON; }
switch (reason)
	{
	case	DepotAction.SELL:
		rr="to be sold.";
	break;
	case	DepotAction.UPGRADE:
		rr="to be upgrade.";
	break;
	case	DepotAction.REPLACE:
		rr="to be replace.";
	break;
	case	DepotAction.CRAZY:
		rr="for a crazy action.";
	break;
	case	DepotAction.ADDWAGON:
		rr="to add "+wagonnum+" new wagons.";
		reason=wagonnum+DepotAction.ADDWAGON;
	break;
	}
DInfo("Vehicle "+INSTANCE.carrier.VehicleName(veh)+" is going to depot "+rr,0,"cCarrier::VehicleSendToDepot");
INSTANCE.carrier.ToDepotList.AddItem(veh,reason);
}

function cCarrier::VehicleGetFullCapacity(veh)
// return total capacity a vehicle can handle
{
if (!AIVehicle.IsValidVehicle(veh)) return -1;
local mod=AIVehicle.GetVehicleType(veh);
local engine=AIVehicle.GetEngineType(veh);
if (mod == AIVehicle.VT_RAIL)
	{ // trains
	local wagonnum=AIVehicle.GetNumWagons(veh);
	local wagonengine=AIVehicle.GetWagonEngineType(veh,1);
	local wagoncapacity=AIEngine.GetCapacity(wagonengine);
	local traincapacity=AIEngine.GetCapacity(engine);
	local total=traincapacity+(wagonnum*wagoncapacity);
	return total;
	}
else	{ // others
	local value=AIEngine.GetCapacity(engine);
	return value;
	}
}

function cCarrier::VehicleFindRouteIndex(veh)
// return UID of the route the veh vehicle is running on
{
local group=AIVehicle.GetGroupID(veh);
if (cRoute.GroupIndexer.HasItem(group))		return cRoute.GroupIndexer.GetValue(group);
return null;
}

function cCarrier::VehicleUpgradeEngine(vehID)
// we will try to upgrade engine and wagons for vehicle veh
{
local idx=INSTANCE.carrier.VehicleFindRouteIndex(vehID);
if (idx == null)
	{
	DWarn("This vehicle "+INSTANCE.carrier.VehicleName(vehID)+" is not use by any route !!!",1,"cCarrier::VehicleUpgradeEngine");
	INSTANCE.carrier.VehicleSell(vehID,true);
	INSTANCE.carrier.vehnextprice=0;
	return false;
	}
local betterEngine=cEngine.IsVehicleAtTop(vehID);
if (betterEngine==-1)
	{
	DWarn("That vehicle have it's engine already at top, but we sell it anyway",1,"cCarrier::VehicleUpgradeEngine");
	INSTANCE.carrier.VehicleSell(vehID, false);
	return false;
	}
local vehtype=AIVehicle.GetVehicleType(vehID);
local new_vehID=null;
local homedepot=AIVehicle.GetLocation(vehID);
local road=INSTANCE.route.GetRouteObject(idx);
if (road == null)	return;
//local group = AIVehicle.GetGroupID(vehID);
DInfo("Upgrading using depot at "+homedepot,2,"cCarrier::VehicleUpgradeEngine");
PutSign(homedepot,"D");
local money=0;
local oldenginename=INSTANCE.carrier.VehicleName(vehID);
switch (vehtype)
	{
	case AIVehicle.VT_RAIL:
		/*
		TODO: upgrade for trains
		*/
	break;
	case AIVehicle.VT_ROAD:
		INSTANCE.carrier.VehicleSell(vehID,false);
		new_vehID = INSTANCE.carrier.CreateRoadEngine(betterEngine, homedepot, road.cargoID);
	break;
	case AIVehicle.VT_AIR:
		INSTANCE.carrier.VehicleSell(vehID,false);
		new_vehID = INSTANCE.carrier.CreateAircraftEngine(betterEngine, homedepot);
	break;
	case AIVehicle.VT_WATER:
		INSTANCE.carrier.VehicleSell(vehID,false);
	return;
	break;
	}
if (AIVehicle.IsValidVehicle(new_vehID))
	{
	local newenginename=INSTANCE.carrier.VehicleName(new_vehID);
	AIGroup.MoveVehicle(road.groupID,new_vehID);
	DInfo("Vehicle "+oldenginename+" replace with "+newenginename,0,"cCarrier::VehicleUpgradeEngine");
	AIVehicle.StartStopVehicle(new_vehID); // Not sharing orders with previous vehicle as its orders are "goto depot" orders
	INSTANCE.carrier.VehicleBuildOrders(road.groupID); // need to build its orders
	INSTANCE.carrier.vehnextprice-=cEngine.GetPrice(betterEngine);
	}
if (INSTANCE.carrier.vehnextprice < 0)	INSTANCE.carrier.vehnextprice=0;
}

function cCarrier::VehicleMaintenance_Orders(vehID)
// try to repair orders for a vehicle, else send it to depot
{
local numorders=AIOrder.GetOrderCount(vehID);
local name=cCarrier.VehicleName(vehID);
for (local z=AIOrder.GetOrderCount(vehID)-1; z >=0; z--)
		{ // I check backward to prevent z index gone wrong if an order is remove
		if (!INSTANCE.carrier.VehicleOrderIsValid(vehID, z))
			{
			DInfo("-> Vehicle "+name+" have invalid order, removing orders "+z,0,"cCarrier::VehicleMaintenance_Orders");
			AIOrder.RemoveOrder(vehID, z);
			}
		}
if (numorders < 2)
		{
		local groupid=AIVehicle.GetGroupID(vehID);
		DInfo("-> Vehicle "+name+" have too few orders, trying to correct it",0,"cCarrier::VehicleMaintenance_Orders");
		INSTANCE.carrier.VehicleBuildOrders(groupid);
		}
numorders=AIOrder.GetOrderCount(vehID);
	if (age < 2)
		{
		DInfo("-> Vehicle "+name+" have too few orders, sending it to depot",0,"cCarrier::VehicleMaintenance_Orders");
		INSTANCE.carrier.VehicleSendToDepot(vehID, DepotAction.SELL);
		cCarrier.CheckOneVehicleOrGroup(vehID,true); // push all vehicles to get a check
		}
}

function cCarrier::VehicleMaintenance()
// lookout our vehicles for troubles
{
local tlist=AIList();
while (cCarrier.MaintenancePool.len()>0)	tlist.AddItem(cCarrier.MaintenancePool.pop(),0);
// Get the work and clean the mainteance list
tlist.Valuate(AIVehicle.GetState);
tlist.RemoveValue(AIVehicle.VS_STOPPED);
tlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
tlist.RemoveValue(AIVehicle.VS_CRASHED);
DInfo("Checking "+tlist.Count()+" vehicles",0);
local name="";
local tx, ty, tz=0; // temp variable to use freely
INSTANCE.carrier.warTreasure=0;
local ignore_some=0;
foreach (vehicle, dummy in tlist)
	{
	local vehtype=AIVehicle.GetVehicleType(vehicle);
	if (ignore_some >6 && vehtype == AIVehicle.VT_ROAD)	INSTANCE.carrier.warTreasure+=AIVehicle.GetCurrentValue(vehicle);
	ignore_some++;
	local topengine=cEngine.IsVehicleAtTop(vehicle); // new here
	if (topengine != -1)	price=cEngine.GetPrice(topengine);
				else	price=cEngine.GetPrice(AIVehicle.GetEngineType(vehicle));
	price+=(0.5*price);
	// add a 50% to price to avoid try changing an engine and running low on money because of fluctuating money
	name=INSTANCE.carrier.VehicleName(vehicle);
	tx=AIVehicle.GetAgeLeft(vehicle);
	if (tx < cCarrier.OldVehicle)
		{
		if (!cBanker.CanBuyThat(price+INSTANCE.carrier.vehnextprice)) continue;
		DInfo("-> Vehicle "+name+" is getting old ("+tx+" days left), replacing it",0,"cCarrier::VehicleMaintenance");
		INSTANCE.carrier.VehicleSendToDepot(vehicle,DepotAction.REPLACE);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		continue;
		}
	tx=INSTANCE.carrier.VehicleGetProfit(vehicle);
	ty=AIVehicle.GetAge(vehicle);
	if (ty > 240 && tx < 0 && INSTANCE.OneMonth > 6) // (6 months after new year)
		{
		ty=INSTANCE.carrier.VehicleFindRouteIndex(vehicle);
		INSTANCE.builder.RouteIsDamage(ty);
		}
	tx=AIVehicle.GetReliability(vehicle);
	if (tx < 30)
		{
		DInfo("-> Vehicle "+name+" reliability is low ("+tx+"%), sending it for servicing at depot",0,"cCarrier::VehicleMaintenance");
		AIVehicle.SendVehicleToDepotForServicing(vehicle);
		local idx=INSTANCE.carrier.VehicleFindRouteIndex(vehicle);
		INSTANCE.builder.RouteIsDamage(idx);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		continue;
		}
	if (topengine != -1)
		{
		// reserving money for the upgrade
		DInfo("Upgrade engine ! "+INSTANCE.bank.CanBuyThat(INSTANCE.carrier.vehnextprice+price)+" price: "+price+" vehnextprice="+vehnextprice,1);
		if (!INSTANCE.bank.CanBuyThat(INSTANCE.carrier.vehnextprice+price))	continue; // no way, we lack funds for it
		INSTANCE.carrier.vehnextprice+=price;
		DInfo("-> Vehicle "+name+" can be upgrade with a better version, sending it to depot",0,"cCarrier::VehicleMaintenance");
		INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.UPGRADE);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		continue;
		}
	cCarrier.VehicleMaintenance_Orders(vehicle);
	AIController.Sleep(1);
	}
}

function cCarrier::CrazySolder(moneytoget)
// this function send & sold nearly all road vehicle to get big money back
{
local allvehicle=AIVehicleList();
allvehicle.Valuate(AIVehicle.GetVehicleType);
allvehicle.KeepValue(AIVehicle.VT_ROAD);
allvehicle.Valuate(AIVehicle.GetProfitThisYear);
allvehicle.Sort(AIList.SORT_BY_VALUE, false);
allvehicle.RemoveTop(2);
allvehicle.Sort(AIList.SORT_BY_VALUE, true);
foreach (vehicle, dummy in allvehicle)
	{
	INSTANCE.Sleep(1);
	INSTANCE.carrier.VehicleSendToDepot(vehicle,DepotAction.CRAZY);
	if (moneytoget < 0)	break;
	moneytoget-=AIVehicle.GetCurrentValue(vehicle);
	}
}

function cCarrier::VehicleSell(veh, recordit)
// sell the vehicle and update route info
{
DInfo("-> Selling Vehicle "+INSTANCE.carrier.VehicleName(veh),0);
cTrain.DeleteVehicle(veh);
AIVehicle.SellVehicle(veh);
local uid=INSTANCE.carrier.VehicleFindRouteIndex(veh);
local road=cRoute.GetRouteObject(uid);
if (road == null) return;
road.RouteUpdateVehicle();
if (recordit)	road.dateVehicleDelete=AIDate.GetCurrentDate();
}

function cCarrier::VehicleGroupSendToDepotAndSell(idx)
// Send & sell all vehicles from that route, we will wait 2 months or the vehicles are sold
{
local road=INSTANCE.route.GetRouteObject(idx);
if (road == null)	return;
local vehlist=null;
if (road.groupID != null)
	{
	vehlist=AIVehicleList_Group(road.groupID);
	DInfo("Removing a group of vehicle : "+vehlist.Count(),1);
	foreach (vehicle, dummy in vehlist)
		{
		INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
		}
	foreach (vehicle, dummy in vehlist)
		{
		local waitmax=444; // 2 month / vehicle, as 444*10(sleep)=4440/74
		local waitcount=0;
		local wait=true;
		do	{
			AIController.Sleep(10);
			INSTANCE.carrier.VehicleIsWaitingInDepot();
			wait=(AIVehicle.IsValidVehicle(vehicle));
			DInfo("wait? "+AIVehicle.IsValidVehicle(vehicle)+" waiting:"+wait+" waitcount="+waitcount,0);
			waitcount++;
			if (waitcount > waitmax)	wait=false;
			} while (wait);
		}
	}
}

function cCarrier::VehicleIsWaitingInDepot()
// this function checks our depot sell vehicle in it
{
local tlist=AIVehicleList();
DInfo("Checking vehicles in depots:",2);
tlist.Valuate(AIVehicle.IsStoppedInDepot);
tlist.KeepValue(1);
foreach (i, dummy in tlist)
	{
	INSTANCE.Sleep(1);
	local reason=DepotAction.SELL;
	local numwagon=0;
	local uid=0;
	local name=INSTANCE.carrier.VehicleName(i);
	if (INSTANCE.carrier.ToDepotList.HasItem(i))
		{
		reason=INSTANCE.carrier.ToDepotList.GetValue(i);
		INSTANCE.carrier.ToDepotList.RemoveItem(i);
		if (reason >= DepotAction.ADDWAGON)
			{
			numwagon=reason-DepotAction.ADDWAGON;
			reason=DepotAction.ADDWAGON;
			uid=INSTANCE.carrier.VehicleFindRouteIndex(i);
			if (uid==null)	{
						DError("Cannot find the route uid for "+name,2,"cCarrier::VehicleIsWaitingInDepot");
						reason=DepotAction.SELL;
						}
			}
		}
	switch (reason)
		{
		case	DepotAction.SELL:
			INSTANCE.carrier.VehicleSell(i,true);
		break;
		case	DepotAction.UPGRADE:
			INSTANCE.carrier.VehicleUpgradeEngine(i);
		break;
		case	DepotAction.REPLACE:
			INSTANCE.carrier.VehicleSell(i,false);
		break;
		case	DepotAction.CRAZY:
			INSTANCE.carrier.VehicleSell(i,false);
		break;
		case	DepotAction.ADDWAGON:
			DInfo("Vehicle "+name+" is waiting at depot to get "+numwagon+" wagons",2,"cCarrier::VehicleIsWaitingInDepot");
			INSTANCE.carrier.AddWagon(uid, numwagon);
		break;
		}
	if (INSTANCE.carrier.ToDepotList.IsEmpty())	INSTANCE.carrier.vehnextprice=0;
	}
}

