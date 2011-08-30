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

function cCarrier::ChooseRailWagon(cargo, rtype, compengine)
// pickup a wagon that could be use to carry "cargo", on railtype "rtype"
{
	local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
	wagonlist.Valuate(AIEngine.IsBuildable);
	wagonlist.KeepValue(1);
	if (rtype!=null)	
		{
		wagonlist.Valuate(AIEngine.CanRunOnRail, rtype);
		wagonlist.KeepValue(1);
		}
	if (compengine!=null)
		{
		wagonlist.Valuate(cEngine.IsCompatible, compengine);
		wagonlist.KeepValue(1);
		}
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.CanRefitCargo, cargo);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.GetMaxSpeed);
	wagonlist.KeepValue(wagonlist.GetValue(wagonlist.Begin()));
	wagonlist.Valuate(cEngine.GetCapacity, cargo);
	wagonlist.Sort(AIList.SORT_BY_VALUE,false);
	wagonlist.KeepValue(wagonlist.GetValue(wagonlist.Begin()));
	wagonlist.Valuate(cEngine.GetPrice, cargo);
	wagonlist.Sort(AIList.SORT_BY_VALUE,true);
	if (wagonlist.IsEmpty()) 
		{ DError("No wagons can transport that cargo "+AICargo.GetCargoLabel(cargo),1,"ChooseWagon"); return null; }
	return wagonlist.Begin();
}

function cCarrier::ChooseRailCouple(cargo, rtype=null)
// This function will choose a wagon to carry that cargo, and a train engine to carry it
// It will return AIList with item=engineID, value=wagonID
// AIList() on error
{
local couple=AIList();
local engine=ChooseRailEngine(rtype, cargo);
if (rtype==null)	rtype=cCarrier.GetRailTypeNeedForEngine(engine);
if (engine==null || rtype==-1)	return couple;
local wagon=cCarrier.ChooseRailWagon(cargo, rtype, engine);
if (wagon != null)	couple.AddItem(engine,wagon);
return couple;
}

function cCarrier::GetRailTypeNeedForEngine(engineID)
// return the railtype the engine need to work on
{
local rtypelist=AIRailTypeList();
foreach (rtype, dum in rtypelist)
	{
	if (AIEngine.HasPowerOnRail(engineID, rtype))	return rtype;
	}
return -1;
}

function cCarrier::ChooseRailEngine(rtype=null, cargoID=null)
// return fastest+powerfulest engine
{
local vehlist = AIEngineList(AIVehicle.VT_RAIL);
vehlist.Valuate(AIEngine.IsBuildable);
vehlist.KeepValue(1);
if (rtype != null)
	{
	vehlist.Valuate(AIEngine.HasPowerOnRail, rtype);
	vehlist.KeepValue(1);
	}
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(0);
if (cargoID!=null)
	{
	vehlist.Valuate(cEngine.CanPullCargo, cargoID);
	vehlist.KeepValue(1);
	}
vehlist.Valuate(AIEngine.GetMaxSpeed);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
vehlist.KeepValue(vehlist.GetValue(vehlist.Begin()));
vehlist.Valuate(AIEngine.GetPower);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
local veh = null;
if (vehlist.IsEmpty())	DInfo("Cannot find a train engine for that rail type",1,"cCarrier::ChooseRailEngine");
			else	veh=vehlist.Begin();
//print("Selected train engine "+AIEngine.GetName(veh)+" speed:"+AIEngine.GetMaxSpeed(veh));
return veh;
}

function cCarrier::TrainSetOrders(trainID)
// Set orders for a train
{
local uid=INSTANCE.carrier.VehicleFindRouteIndex(trainID);
if (uid==null)	{ DError("Cannot find uid for that train",1,"cCarrier::TrainSetOrders"); return false; }
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
DInfo("Append orders to "+AIVehicle.GetName(trainID),2,"cCarrier::TrainSetOrder");
local firstorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
local secondorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
if (!road.source_istown)	firstorder+=AIOrder.AIOF_FULL_LOAD_ANY;
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.source.stationID), firstorder))
	{ DError(AIVehicle.GetName(trainID)+" refuse first order",2,"cCarrier::TrainSetOrder"); return false; }
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.target.stationID), secondorder))
	{ DError(AIVehicle.GetName(trainID)+" refuse second order",2,"cCarrier::TrainSetOrder"); return false; }
return true;
}

function cCarrier::GetNumberOfWagons(vehID)
// Count only part that are wagons, and not engine locomotive
{
if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID : "+vehID,2,"cCarrier::GetNumberOfWagons"); return 0; }
local numwagon=0;
local numpart=AIVehicle.GetNumWagons(vehID);
for (local i=0; i < numpart; i++)
	if (AIEngine.IsWagon(AIVehicle.GetWagonEngineType(vehID, i)))	numwagon++;
return numwagon;
}

function cCarrier::GetNumberOfLoco(vehID)
// Count how many locomotives are in vehicle
{
local numwagon=cCarrier.GetNumberOfWagons(vehID);
return AIVehicle.GetNumWagons(vehID)-numwagon;
}

function cCarrier::GetWagonFromVehicle(vehID)
// pickup a wagon from the vehicle and return its place in the vehicle
{
if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID : "+vehID,2,"cCarrier::GetAWagonFromVehicle"); return -1; }
local numengine=AIVehicle.GetNumWagons(vehID);
for (local z=0; z < numengine; z++)
	if (AIEngine.IsWagon(AIVehicle.GetWagonEngineType(vehID,z)))	return z;
}

function cCarrier::GetWagonsInGroup(groupID)
// return number of wagons present in the group
{
local vehlist=AIVehicleList_Group(groupID);
local total=0;
foreach (veh, dummy in vehlist)	total+=cCarrier.GetNumberOfWagons(veh);
return total;
}

function cCarrier::CanAddThatLength(vehID, wagonID)
// return true if we could add another wagonID to vehID
{
if (!AIVehicle.IsValidVehicle(vehID) || !AIVehicle.IsValidVehicle(wagonID))
		{ DError("Invalid vehicleID : "+vehID+" & "+wagonID,2,"cCarrier::GetTrainLength"); return 0; }
local maxlength=16*5; // TODO: not hardcode a train length
local vehicleL=AIVehicle.GetLength(vehID);
local wagonL=AIVehicle.GetLength(vehID);
return ((wagonL+vehicleL) <= maxlength);
}

function cCarrier::CreateTrainsEngine(engineID, depot, cargoID)
// Create vehicle engineID at depot
{
if (!AIEngine.IsValidEngine(engineID))	return -1;
local price=cEngine.GetPrice(engineID);
INSTANCE.bank.RaiseFundsBy(price);
if (!INSTANCE.bank.CanBuyThat(price))	DInfo("We lack money to buy "+AIEngine.GetName(engineID)+" : "+price,1,"cCarrier::CreateTrainsEngine");
local vehID=AIVehicle.BuildVehicle(depot, engineID);
if (!AIVehicle.IsValidVehicle(vehID))	{ DInfo("Failure to buy "+AIEngine.GetName(engineID),1,"cCarrier::CreateTrainsEngine"); return -1; }
cEngine.Update(vehID);
// get & set refit cost
local testRefit=AIAccounting();
if (!AIVehicle.RefitVehicle(vehID, cargoID))
	{
	DError("We fail to refit the engine, maybe we run out of money ?",1,"cCarrier::CreateTrainEngine");
	}
else	{
	local refitprice=testRefit.GetCosts();
	cEngine.SetRefitCost(engineID, cargoID, refitprice, AIVehicle.GetLength(vehID));
	}
testRefit=null;
return vehID;
}

function cCarrier::AddNewTrain(uid, wagonNeed, depot)
// Called when creating a route, as no train is there no need to worry that much
{
local road=cRoute.GetRouteObject(uid);
if (road==null)	return -1;
local locotype=INSTANCE.carrier.ChooseRailEngine(road.source.specialType, road.cargoID);
if (locotype==null)	return -1;
local wagontype=INSTANCE.carrier.ChooseRailWagon(road.cargoID, road.source.specialType, locotype);
if (wagontype==null)	return -1;
local confirm=false;
//local depot=road.source.GetRailDepot();
local wagonID=null;
//if (depot==-1)	{ DError("Station "+road.source.name+" doesn't have a valid depot",1,"cCarrier::AddNewTrain"); return -1; }
local pullerID=INSTANCE.carrier.CreateTrainsEngine(locotype, depot, road.cargoID);
if (pullerID==-1)	{ DError("Cannot create the train engine "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain"); return -1; }
local another=null; // use to get a new wagonID, but this one doesn't need to be buy
PutSign(depot,"Depot");
print("BREAKPOINT");
local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
wagonlist.Valuate(AIEngine.IsBuildable);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.IsWagon);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.CanRunOnRail, road.source.specialType);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.CanRefitCargo, road.cargoID);
wagonlist.KeepValue(1);
local wagonTestList=AIList();
local ourMoney=INSTANCE.bank.GetMaxMoneyAmount();
local lackMoney=false;
while (!confirm)
	{
	lackMoney=!cBanker.CanBuyThat(cEngine.GetPrice(wagontype, road.cargoID));
	wagonTestList.Clear();
	wagonTestList.AddList(wagonlist);
	if (lackMoney)
		{
		DError("We don't have enought money to buy "+cEngine.GetName(wagontype),2,"cCarrier::AddNewTrain");
		wagonID==-1;
		}
	else	wagonID=INSTANCE.carrier.CreateTrainsEngine(wagontype, depot, road.cargoID);
	// now that the wagon is create, we know its capacity with any cargo
	if (wagonID==-1)
		{
		DError("Cannot create the wagon "+cEngine.GetName(wagontype),2,"cCarrier::AddNewTrain");
		}
	wagonTestList.Valuate(cEngine.IsCompatible, locotype); // kick out incompatible wagon
	wagonTestList.KeepValue(1);
	wagonTestList.Valuate(cEngine.GetCapacity, road.cargoID);
	wagonTestList.Sort(AIList.SORT_BY_VALUE,false);
	wagonTestList.KeepValue(cEngine.GetCapacity(wagonTestList.Begin(),road.cargoID)); // keep wagons == to that top capacity
	wagonTestList.Sort(AIList.SORT_BY_VALUE, true); // and put cheapest one first
	if (wagonTestList.IsEmpty())	another=null;
					else	another=wagonTestList.Begin();
	print("wagontype="+wagontype+" another="+another+" wprice="+cEngine.GetPrice(wagontype,road.cargoID)+" aprice="+cEngine.GetPrice(another,road.cargoID)+" size:"+wagonTestList.Count()+" "+wagonTestList.IsEmpty());
	if (another==wagontype && another!=null) // same == cannot find a better one or we have no more choice
		{
		// try attach it
		confirm=AIVehicle.MoveWagonChain(wagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID)-1);
		if (!confirm)
			{
			DInfo("Wagon "+AIEngine.GetName(wagontype)+" is not usable with "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain");
			cEngine.Incompatible(wagontype, locotype);
			}
		}
	else	wagontype=another;
	INSTANCE.NeedDelay(20);
	if (wagonID!=-1)	AIVehicle.SellVehicle(wagonID); // and finally sell the test wagon
	if (another==null)
		{
		if (lackMoney)	DError("Find some wagons that might work with that train engine "+cEngine.GetName(locotype)+", but cannot try them as we lack money",2,"cCarrier::AddNewTrain");
				else	DError("Can't find any wagons usable with that train engine "+cEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
		if (pullerID!=null)	AIVehicle.SellVehicle(pullerID);
		if (lackMoney)	return -2;
				else	return -3;
		}
	AIController.Sleep(1); // we should rush that, but it might be too hard without a pause
	}
//local deletetrain=false;
for (local i=0; i < wagonNeed; i++)
	{
	wagonID=INSTANCE.carrier.CreateTrainsEngine(wagontype, depot, road.cargoID);
	if (wagonID!=-1)
		if (!AIVehicle.MoveWagonChain(wagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID) - 1))
			{
			DError("Wagon "+AIEngine.GetName(wagontype)+" cannot be attach to "+AIEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
			}
	}
AIGroup.MoveVehicle(road.groupID, pullerID);
if (INSTANCE.carrier.TrainSetOrders(pullerID))	AIVehicle.StartStopVehicle(pullerID);
							else	deletetrain=true;

INSTANCE.NeedDelay(200);
return pullerID;
}

function cCarrier::AddWagon(uid, wagonNeed)
// Add wagons to route uid, handle the train engine by buying it if need
{
// TODO: handle getting all trains to depot before doing buys
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
local totalWagons=cCarrier.GetWagonsInGroup(road.groupID)+wagonNeed;
local vehlist=AIVehicleList_Group(road.groupID);
local numTrains=vehlist.Count();
local stationLen=road.source.locations.GetValue(19)*16; // station depth is @19
local result=null;
print("number of trains on road ="+numTrains);
if (numTrains == 0)
	{
	local stop=false;
	while (!stop)
		{
		result=INSTANCE.carrier.AddNewTrain(uid, totalWagons, road.source.GetRailDepot());
		stop=true;
		if (result == -3)	stop=false;
		if (AIVehicle.IsValidVehicle(result))	stop=true;
		}
	if (AIVehicle.IsValidVehicle(result))
		{
		if (cCarrier.GetNumberOfWagons(result)==0 || cCarrier.GetNumberOfLoco(result)==0)
			{
			DInfo("Deleting train as it lack wagons or an engine",2,"cCarrier::AddWagon");
			AIVehicle.SellVehicle(result);
			return false;
			}
		while (AIVehicle.GetLength(result) > stationLen)
			{
			DInfo("Selling a wagon to met station length restrictions of "+stationLen,2,"cCarrier::AddWagon");
			local wagondelete=cCarrier.GetWagonFromVehicle(result);
			if (!AIVehicle.SellWagon(result, wagondelete))
				{
				DInfo("Hmmm cannot delete that wagon : "+wagondelete,2,"cCarrier::AddWagon");
				return false;
				}
			}
		DInfo("Adding a new train to "+road.name,0,"cCarrier::AddWagon");
		}
	}
return true;
}

