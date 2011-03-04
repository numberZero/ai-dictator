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

function cCarrier::VehicleGetFormatString(veh)
// return a vehicle string with the vehicle infos
{
if (!AIVehicle.IsValidVehicle(veh))	return "<Invalid vehicle>";
local toret="#"+veh+" - "+AIVehicle.GetName(veh)+"("+AIEngine.GetName(AIVehicle.GetEngineType(veh))+")";
return toret;
}

function cCarrier::VehicleOrderSkipCurrent(veh)
// Skip the current order and go to the next one
{
local current=AIOrder.ResolveOrderPosition(veh, AIOrder.ORDER_CURRENT);
local total=AIOrder.GetOrderCount(veh);
if (current+1 == total)	current=0;
	else		current++;
AIOrder.SkipToOrder(veh, current);
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

function cCarrier::AirNetworkOrdersHandler()
// Create orders for aircrafts that run the air network
{
local road=null;
local isfirst=true;
local rabbit=null; // this will be our rabbit aircraft that take orders & everyone share with it
local mailgroup=AIVehicleList_Group(cRoute.GetVirtualAirMailGroup());
local passgroup=AIVehicleList_Group(cRoute.GetVirtualAirPassengerGroup());
local allgroup=AIList();
allgroup.AddList(mailgroup);
allgroup.AddList(passgroup);
if (allgroup.IsEmpty())	return;
allgroup.Valuate(AIVehicle.GetAge);
allgroup.Sort(AIList.SORT_BY_VALUE, false);
rabbit=allgroup.Begin();
allgroup.RemoveTop(1);
local numorders=AIOrder.GetOrderCount(rabbit);
if (numorders != cCarrier.VirtualAirRoute.len())
	{
	for (local i=0; i < INSTANCE.carrier.VirtualAirRoute.len(); i++)
		{
		local destination=INSTANCE.carrier.VirtualAirRoute[i];
		if (!AIOrder.AppendOrder(rabbit, destination, AIOrder.AIOF_FULL_LOAD_ANY))
			{ DError("Aircraft network order refuse",2); }
		}
	if (numorders > 0)
		{
	// now remove previous rabbit orders, should not make the aircrafts gone too crazy
		for (local i=0; i < numorders; i++)
				{ AIOrder.RemoveOrder(rabbit, AIOrder.ResolveOrderPosition(rabbit,0)); }
		}
	}
foreach (vehicle, dummy in allgroup)	AIOrder.ShareOrders(vehicle,rabbit);
}

function cCarrier::VehicleOrdersReset(veh)
// Remove all orders for veh
{
while (AIOrder.GetOrderCount(veh) > 0)
	{
	if (!AIOrder.RemoveOrder(veh, AIOrder.ResolveOrderPosition(veh, 0)))
		{ DError("Cannot remove orders ",2); }
	}
}

function cCarrier::VehicleBuildOrders(groupID)
// Redo all orders vehicles from that group should have
{
local vehlist=AIVehicleList_Group(groupID);
vehlist.Valuate(AIVehicle.GetState);
vehlist.RemoveValue(AIVehicle.VS_STOPPED);
vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
vehlist.RemoveValue(AIVehicle.VS_CRASHED);
foreach (veh, dummy in vehlist)
	{
	if (veh in cCarrier.ToDepotList)	{ vehlist.SetValue(veh,-1); }
				else		{ vehlist.SetValue(veh, 1); }
	}
vehlist.RemoveValue(-1);
if (vehlist.IsEmpty()) return false;
local veh=vehlist.Begin();
local idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
local road=cRoute.GetRouteObject(idx);
local oneorder=null;
local twoorder=null;
local srcplace=null;
local dstplace=null;
// setup everything before removing orders, as it could be dangerous for the poor vehicle to stay without orders a long time
switch (road.route_type)
	{
	case AIVehicle.VT_ROAD:
		oneorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY;
		if (road.target_istown)
			{ twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY; }
		else	{ twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE; }
		srcplace= AIStation.GetLocation(road.source.stationID);
		dstplace= AIStation.GetLocation(road.target.stationID);
	break;
	case AIVehicle.VT_RAIL:
		oneorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY;
		twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
/*		if (srcStation.STATION.haveEntry)	{ srcplace= srcStation.STATION.e_loc; }
				else			{ srcplace= srcStation.STATION.s_loc; }
		if (dstStation.STATION.haveEntry)	{ dstplace= dstStation.STATION.e_loc; }
				else			{ dstplace= dstStation.STATION.s_loc; }
*/
	break;
	case AIVehicle.VT_AIR:
		oneorder=AIOrder.AIOF_FULL_LOAD_ANY;
		twoorder=AIOrder.AIOF_FULL_LOAD_ANY;
		srcplace= AIStation.GetLocation(road.source.stationID);
		dstplace= AIStation.GetLocation(road.target.stationID);
	break;
	case AIVehicle.VT_WATER:
	break;
	case RouteType.AIRNET: // it's the air network
		INSTANCE.carrier.AirNetworkOrdersHandler();
		return true;
	case RouteType.CHOPPER:
		oneorder=AIOrder.AIOF_FULL_LOAD_ANY;
		twoorder=AIOrder.AIOF_FULL_LOAD_ANY;
		srcplace= AIIndustry.GetHeliportLocation(road.sourceID);
		dstplace= AIStation.GetLocation(road.target.stationID);
	break;
	}
if (srcplace == null || dstplace == null) return false;
DInfo("Setting orders for route "+idx,2);
INSTANCE.carrier.VehicleOrdersReset(veh);
if (!AIOrder.AppendOrder(veh, srcplace, oneorder))
	{ DError("First order refuse",2); }
if (!AIOrder.AppendOrder(veh, dstplace, twoorder))
	{ DError("Second order refuse",2); }
vehlist.RemoveTop(1);
foreach (vehicle, dummy in vehlist)	AIOrder.ShareOrders(vehicle, veh);
return true;
}

function cCarrier::VehicleFindDestinationInOrders(vehicle, stationID)
// browse vehicle orders and return index of order that target that destination
{
local numorders=AIOrder.GetOrderCount(vehicle);
if (numorders==0) return -1;
for (local j=0; j < numorders; j++)
	{
	local tiletarget=AIOrder.GetOrderDestination(vehicle,AIOrder.ResolveOrderPosition(vehicle, j));
	if (!AITile.IsStationTile(tiletarget)) continue;
	local targetID=AIStation.GetStationID(tiletarget);
	if (targetID == stationID)	return j;
	}
return -1;
}

function cCarrier::VehicleHandleTrafficAtStation(stationID, reroute)
// if reroute this function stop all vehicles that use stationID to goto stationID
// if !rereroute this function restore vehicles orders
{
local road=null;
local vehlist=null;
local veh=null;
local orderpos=null;
local group=null;
for (local i=0; i < INSTANCE.route.RListGetSize(); i++)
	{
	road=INSTANCE.route.RListGetItem(i);
	orderpos=-1;
	local srcstation=INSTANCE.builder.GetStationID(i,true);
	if (srcstation == stationID)	orderpos=0;
	local dststation=INSTANCE.builder.GetStationID(i,false);
	if (dststation == stationID)	orderpos=1;
	group=road.ROUTE.group_id;
	if (orderpos > -1)
		{ // that route use that station
		if (reroute)
			{
			DInfo("Re-routing traffic on route #"+i,0);
			vehlist=AIVehicleList_Group(group);
			veh=vehlist.Begin();
			local orderindex=VehicleFindDestinationInOrders(veh, stationID);
			if (!AIOrder.RemoveOrder(veh, AIOrder.ResolveOrderPosition(veh, orderindex)))
				{ DError("Fail to remove order for vehicle "+veh,2); }
			}
		else	{ INSTANCE.carrier.VehicleBuildOrders(group); }
		}
	}
}

function cCarrier::VehicleSetDepotOrder(veh)
// set all orders of the vehicle to force it going to a depot
{
local idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
// One day i should check rogues vehicles running out of control from a route, but this shouldn't happen :p
local homedepot=INSTANCE.builder.GetDepotID(idx,true);
if (homedepot==-1)	homedepot=INSTANCE.builder.GetDepotID(idx,false); // TODO: might fail if vehicle don't have any depot to go
AIOrder.UnshareOrders(veh);
INSTANCE.carrier.VehicleOrdersReset(veh);
if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.AIOF_STOP_IN_DEPOT))
	{ DError("Vehicle refuse goto depot order",2); }
// And another one day i will kills all vehicles that refuse to go to a depot !!!
if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.AIOF_STOP_IN_DEPOT))
	{ DError("Vehicle refuse goto depot order",2); }
// twice time, even we get caught by vehicle orders check, it will ask to send the vehicle.... to depot
DInfo("Setting depot order for vehicle "+veh+"-"+AIVehicle.GetName(veh),2);
}

function cCarrier::VehicleSendToDepot(veh)
// send a vehicle to depot
{
if (!AIVehicle.IsValidVehicle(veh))	return false;
if (INSTANCE.carrier.ToDepotList.HasItem(veh))	return false;
INSTANCE.carrier.VehicleSetDepotOrder(veh);
local understood=false;
understood=AIVehicle.SendVehicleToDepot(veh);
if (!understood) { DInfo(AIVehicle.GetName(veh)+" refuse to go to depot",1); }
DInfo("Vehicle "+INSTANCE.carrier.VehicleGetFormatString(veh)+" is going to depot ",0);
INSTANCE.carrier.ToDepotList.AddItem(veh,veh);
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

function cCarrier::VehicleUpgradeEngineAndWagons(veh)
// we will try to upgrade engine and wagons for vehicle veh
{
local idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
if (idx < 0)
	{
	DError("This vehicle "+INSTANCE.carrier.VehicleGetFormatString(veh)+" is not use by any route !!!",1);
	INSTANCE.carrier.VehicleSell(veh);
	return false;
	}
local road=INSTANCE.route.RListGetItem(idx);
local group = AIVehicle.GetGroupID(veh);
local engine = null;
local wagon = null;
local numwagon=AIVehicle.GetNumWagons(veh);
local railtype = INSTANCE.route.RouteGetRailType(idx);
local newveh=null;
local homedepot=INSTANCE.builder.GetDepotID(idx,true);
DInfo("Upgrading using depot at "+homedepot,2);
PutSign(homedepot,"D");
local money=0;
//if (railtype > 20) railtype-=20;
switch (AIVehicle.GetVehicleType(veh))
	{
	case AIVehicle.VT_RAIL:
		AIRail.SetCurrentRailType(railtype);
		engine = INSTANCE.carrier.ChooseTrainEngine();
		wagon = INSTANCE.carrier.ChooseWagon(road.ROUTE.cargo_id);
		newveh=AIVehicle.BuildVehicle(homedepot,engine);
		AIVehicle.RefitVehicle(newveh, road.ROUTE.cargo_id);
		local first=null;
		first=AIVehicle.BuildVehicle(homedepot, wagon); 
		for (local i=1; i < numwagon; i++)
			{ AIVehicle.BuildVehicle(homedepot, wagon); }
		AIVehicle.MoveWagonChain(first, 0, newveh, AIVehicle.GetNumWagons(veh) - 1);
	break;
	case AIVehicle.VT_ROAD:
		engine = INSTANCE.carrier.ChooseRoadVeh(road.ROUTE.cargo_id);
		newveh=AIVehicle.BuildVehicle(homedepot,engine);
		AIVehicle.RefitVehicle(newveh, road.ROUTE.cargo_id);
	break;
	case AIVehicle.VT_AIR:
		local modele=AircraftType.EFFICIENT;
		if (road.ROUTE.kind == 1000)	modele=AircraftType.BEST;
		if (!road.ROUTE.src_entry)	modele=AircraftType.CHOPPER;
		engine = INSTANCE.carrier.ChooseAircraft(road.ROUTE.cargo_id,modele);
		INSTANCE.bank.RaiseFundsBy(AIEngine.GetPrice(engine));
		newveh = AIVehicle.BuildVehicle(homedepot,engine);
	break;
	case AIVehicle.VT_WATER:
	return;
	break;
	}
INSTANCE.builder.IsCriticalError();
INSTANCE.builder.CriticalError=false;
AIGroup.MoveVehicle(road.ROUTE.group_id,newveh);
local oldenginename=AIEngine.GetName(AIVehicle.GetEngineType(veh));
local newenginename=AIVehicle.GetName(newveh)+"("+AIEngine.GetName(AIVehicle.GetEngineType(newveh))+")";
if (AIVehicle.IsValidVehicle(newveh))
	{
	DInfo("-> Vehicle "+INSTANCE.carrier.VehicleGetFormatString(veh)+" replace with "+INSTANCE.carrier.VehicleGetFormatString(newveh),0);
	AIVehicle.StartStopVehicle(newveh); // send it without orders, it should get catch
	AIVehicle.SellWagonChain(veh,0);
	INSTANCE.carrier.VehicleSell(veh);
	INSTANCE.carrier.vehnextprice=0;
	}
else	{
	INSTANCE.carrier.VehicleOrdersReset(veh); // because its orders are now goto depot, next vehicle check will catch it
	AIVehicle.StartStopVehicle(veh);
	}
INSTANCE.carrier.vehnextprice=0;
}

function cCarrier::VehicleIsTop_GetUniqID(engine, cargo)
// return a uniqID for a vehicle engine type + cargo, as we can't have dup in a AIList()
{
return (engine+1)*2048+cargo;
}

function cCarrier::VehicleIsTop(veh)
// return engine modele if the vehicle can be upgrade
{
if (!AIVehicle.IsValidVehicle(veh)) return -1;
local cargo=null;
local uniqID=null;
local idx=null;
local road=null;
local top=null;
local ourEngine=AIVehicle.GetEngineType(veh);
switch (AIVehicle.GetVehicleType(veh))
	{
	case AIVehicle.VT_ROAD:
		cargo=INSTANCE.carrier.VehicleGetCargoType(veh);
		uniqID=INSTANCE.carrier.VehicleIsTop_GetUniqID(ourEngine, cargo);
		if (INSTANCE.carrier.TopEngineList.HasItem(uniqID))	return -1; // we know that engine is at top already
		top = INSTANCE.carrier.ChooseRoadVeh(cargo);
	break;
	case AIVehicle.VT_RAIL:
		uniqID=INSTANCE.carrier.VehicleIsTop_GetUniqID(ourEngine, 100);
		if (INSTANCE.carrier.TopEngineList.HasItem(uniqID))	return -1;
		idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
		top = INSTANCE.carrier.ChooseRailVeh(idx);
	break;
	case AIVehicle.VT_WATER:
	return;
	break;
	case AIVehicle.VT_AIR:
		idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
		road=cRoute.GetRouteObject(idx);
		local modele=AircraftType.EFFICIENT;
		//if (road.ROUTE.kind == 1000)	modele=AircraftType.BEST;
		//if (!road.ROUTE.src_entry)	modele=AircraftType.CHOPPER;
		uniqID=INSTANCE.carrier.VehicleIsTop_GetUniqID(ourEngine, modele);
		if (INSTANCE.carrier.TopEngineList.HasItem(uniqID))	return -1;
		top = INSTANCE.carrier.ChooseAircraft(road.cargoID,modele);
	break;
	}
if (ourEngine == top)	{
			DInfo("Adding engine "+AIEngine.GetName(ourEngine)+" to vehicle top list",1);
			INSTANCE.carrier.TopEngineList.AddItem(uniqID, ourEngine);
			return -1;
			}
		else	return top;
}

function cCarrier::VehicleOrderIsValid(vehicle,orderpos)
// Really check if a vehicle order is valid
{
// for now i just disable orders check for chopper, find a better fix if this trouble us later
local chopper=INSTANCE.carrier.AircraftIsChopper(vehicle);
if (chopper) return true;

local ordercount=AIOrder.GetOrderCount(vehicle);
if (ordercount == 0)	return true;
local ordercheck=AIOrder.ResolveOrderPosition(vehicle, orderpos);
if (!AIOrder.IsValidVehicleOrder(vehicle, ordercheck)) return false;
local tiletarget=AIOrder.GetOrderDestination(vehicle, ordercheck);
local vehicleType=AIVehicle.GetVehicleType(vehicle);
if (!chopper)
	{ // Skip this test for a chopper, well it a start, we never get there with a chopper for now
	if (!AICompany.IsMine(AITile.GetOwner(tiletarget)))	return false;
	}
local stationID=AIStation.GetStationID(tiletarget);
switch (vehicleType)
	{
	case	AIVehicle.VT_RAIL:
		local is_station=AIStation.HasStationType(stationID,AIStation.STATION_TRAIN);
		local is_depot=AIRail.IsRailDepotTile(tiletarget);
		if (!is_depot && !is_station) return false;
	break;
	case	AIVehicle.VT_WATER:
		local is_station=AIStation.HasStationType(stationID,AIStation.STATION_DOCK);
		local is_depot=AIMarine.IsWaterDepotTile(tiletarget);
		if (!is_station && !is_depot) return false;
	break;
	case	AIVehicle.VT_AIR:
		local is_station=AIStation.HasStationType(stationID,AIStation.STATION_AIRPORT);
		local is_depot=AIAirport.GetHangarOfAirport(tiletarget);
		if (!is_station && !is_depot)	return false;
	break;
	case	AIVehicle.VT_ROAD:
		local truckcheck=AIStation.HasStationType(stationID,AIStation.STATION_TRUCK_STOP);
		local buscheck=AIStation.HasStationType(stationID,AIStation.STATION_BUS_STOP);
		local depotcheck=AIRoad.IsRoadDepotTile(tiletarget);
		if (!truckcheck && !buscheck && !depotcheck) return false;
	break;
	}
return true;
}

function cCarrier::VehicleMaintenance()
// lookout our vehicles for troubles
{
local tlist=AIVehicleList();
tlist.Valuate(AIVehicle.GetState);
tlist.RemoveValue(AIVehicle.VS_STOPPED);
tlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
tlist.RemoveValue(AIVehicle.VS_CRASHED);
DInfo("Checking "+tlist.Count()+" vehicles",0);
local age=0;
local name="";
local price=0;
foreach (vehicle, dummy in tlist)
	{
	age=AIVehicle.GetAgeLeft(vehicle);
	local topengine=INSTANCE.carrier.VehicleIsTop(vehicle);
	if (topengine == -1)	price=AIEngine.GetPrice(topengine);
		else	 price=AIEngine.GetPrice(AIVehicle.GetEngineType(vehicle));
	price+=(0.5*price);
	// add a 50% to price to avoid try changing an engine and running low on money because of fluctuating money
	name=INSTANCE.carrier.VehicleGetFormatString(vehicle);
	local groupid=AIVehicle.GetGroupID(vehicle);
	local vehgroup=AIVehicleList_Group(groupid);
	if (age < 1095)
		{
		if (vehgroup.Count()==1)	continue; // don't touch last vehicle of the group
		if (!INSTANCE.bank.CanBuyThat(price+INSTANCE.carrier.vehnextprice)) continue;
		DInfo("-> Vehicle "+name+" is getting old ("+AIVehicle.GetAge(vehicle)+" days left), replacing it",0);
		INSTANCE.carrier.VehicleSendToDepot(vehicle);
		INSTANCE.bank.busyRoute=true;
		continue;
		}
	price=INSTANCE.carrier.VehicleGetProfit(vehicle);
	DInfo("-> Vehicle "+name+" profits : "+price,2);
	age=AIVehicle.GetAge(vehicle);
	if (age > 240 && price < 0 && INSTANCE.OneMonth > 3) // (3 months after new year)
		{
		DInfo("-> Vehicle "+name+" is not making profit, sending it to depot",0);
		INSTANCE.carrier.VehicleSendToDepot(vehicle);
		age=INSTANCE.carrier.VehicleFindRouteIndex(vehicle);
		INSTANCE.builder.RouteIsDamage(age);
		}
	age=AIVehicle.GetReliability(vehicle);
	if (age < 30)
		{
		DInfo("-> Vehicle "+name+" reliability is low ("+age+"%), sending it for servicing at depot",0);
		AIVehicle.SendVehicleToDepotForServicing(vehicle);
		local idx=INSTANCE.carrier.VehicleFindRouteIndex(vehicle);
		INSTANCE.builder.RouteIsDamage(idx);
		INSTANCE.bank.busyRoute=true;
		continue;
		}
	if (topengine != -1)
		{
		if (vehgroup.Count()==1)	continue; // don't touch last vehicle of the group
		// reserving money for the upgrade
		if (INSTANCE.carrier.vehnextprice==0)	INSTANCE.carrier.vehnextprice+=price;
		DInfo("-> Vehicle "+name+" can be upgrade with a better version, sending it to depot",0);
		INSTANCE.carrier.VehicleSendToDepot(vehicle);
		INSTANCE.bank.busyRoute=true;
		continue;
		}
	age=AIOrder.GetOrderCount(vehicle);
	if (age < 2)
		{
		local groupid=AIVehicle.GetGroupID(vehicle);
		DInfo("-> Vehicle "+name+" have too few orders, trying to correct it",0);
		INSTANCE.carrier.VehicleBuildOrders(groupid);
		}
	age=AIOrder.GetOrderCount(vehicle);
	if (age < 2)
		{
		DInfo("-> Vehicle "+name+" have too few orders, sending it to depot",0);
		INSTANCE.carrier.VehicleSendToDepot(vehicle);
		}
	for (local z=AIOrder.GetOrderCount(vehicle)-1; z >=0; z--)
		{ // I check backward to prevent z index gone wrong if an order is remove
		if (!INSTANCE.carrier.VehicleOrderIsValid(vehicle, z))
			{
			DInfo("-> Vehicle "+name+" have invalid order, removing orders "+z,0);
			AIOrder.RemoveOrder(vehicle, z);
			}
		}
	}
local dlist=AIVehicleList();
dlist.Valuate(AIVehicle.IsStoppedInDepot);
dlist.KeepValue(1);
if (!dlist.IsEmpty())	INSTANCE.carrier.VehicleIsWaitingInDepot();
}

function cCarrier::VehicleSell(veh)
// sell the vehicle and update route info
{
DInfo("-> Sold Vehicle "+INSTANCE.carrier.VehicleGetFormatString(veh),0);
local idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
AIVehicle.SellWagonChain(veh, 0);
AIVehicle.SellVehicle(veh);
local uid=INSTANCE.carrier.VehicleFindRouteIndex(veh);
local road=cRoute.GetRouteObject(uid);
if (road == null) return;
road.RouteRemoveVehicle();
}

function cCarrier::VehicleGroupSendToDepotAndSell(idx)
// Send & sell all vehicles from that route, we will wait 2 months or the vehicles are sold
{
local road=INSTANCE.route.GetRouteObject(idx);
local vehlist=null;
if (road.groupID != null)
	{
	vehlist=AIVehicleList_Group(road.groupID);
	foreach (vehicle in vehlist)
		{
		INSTANCE.carrier.VehicleSendToDepot(vehicle);
		}
	foreach (vehicle in vehlist)
		{
		local waitmax=222; // 1 month / vehicle, as 222*10(sleep)=2220/74
		local waitcount=0;
		local wait=false;
		do	{
			AIController.Sleep(10);
			INSTANCE.carrier.VehicleIsWaitingInDepot();
			if (AIVehicle.IsValidVehicle(vehicle))	wait=true;
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
DInfo("Checking vehicles in depots:",0);
tlist.Valuate(AIVehicle.IsStoppedInDepot);
tlist.KeepValue(1);
foreach (i, dummy in tlist)
	{
	if (INSTANCE.carrier.ToDepotList.HasItem(i))	INSTANCE.carrier.ToDepotList.RemoveValue(i);
	local istop=INSTANCE.carrier.VehicleIsTop(i);
	if (istop != -1)	{ INSTANCE.carrier.VehicleUpgradeEngineAndWagons(i); }
	INSTANCE.carrier.VehicleSell(i);
	AIController.Sleep(1);
	}
}

