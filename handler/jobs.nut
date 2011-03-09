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


// I've learned a lot from rondje's code about squirrel, thank you guys !



class cJobs
{
static	database = {};
static	jobIndexer = AIList();	// this list have all UID in the database, value = ranking
static	jobDoable = AIList();	// same as upper, but only doable ones, value = ranking
static	distanceLimits = [0, 0];	// store [min, max] distances we can do, share to every instance so we can discover if this change
static	TRANSPORT_DISTANCE=[50,150,200, 40,80,110, 40,90,150, 50,150,200];


static	function GetJobObject(UID)
		{
		return UID in cJobs.database ? cJobs.database[UID] : null;
		}

	sourceID		= null;	// id of industry/town
	source_location	= null;	// location of source
	targetID		= null;	// id of industry/town
	target_location 	= null;	// location of target
	cargoID		= null;	// cargo id
	roadType		= null;	// AIVehicle.RoadType
	UID			= null;	// a UID for the job
	parentID		= null;	// a UID that a similar job will share with another (like other tansport or other destination)
	isUse			= null;	// is build & in use
	cargoValue		= null;	// value for that cargo
	cargoAmount		= null;	// amount of cargo at source
	distance		= null;	// distance from source to target
	moneyToBuild	= null;	// money need to build the job
	moneyGains		= null;	// money we should grab from doing the job
	source_istown	= null;	// if source is a town
	target_istown	= null;	// if target is a town
	isdoable		= null;	// true if we can actually do that job (if isUse -> false)
	ranking		= null;	// our ranking system
	foule			= null;	// number of opponent/stations near it

	constructor()
		{
		sourceID		= null;
		source_location	= null;
		targetID		= null;
		target_location	= null;
		cargoID		= null;
		roadType		= null;
		UID			= null;
		parentID		= 0;
		isUse			= false;
		cargoValue		= 0;
		cargoAmount		= 0;
		distance		= 0;
		moneyToBuild	= 0;
		moneyGains		= 0;
		source_istown	= false;
		target_istown	= false;
		isdoable		= true;
		ranking		= 0;
		foule			= 0;
		}
}

function cJobs::CheckLimitedStatus()
// Check & set the limited status
	{
	local oldmax=distanceLimits[1];
	local testLimitChange= GetTransportDistance(AIVehicle.VT_RAIL, false, INSTANCE.bank.unleash_road); // get max distance a train could do
	if (oldmax != distanceLimits[1])
	DInfo("JOBS -> Distance limit status change to "+INSTANCE.bank.unleash_road,2);
	}

function cJobs::Save()
// save the job
	{
	local dualrouteavoid=cJobs();
	dualrouteavoid.UID=null;
	dualrouteavoid.sourceID=this.targetID;
	dualrouteavoid.targetID=this.sourceID;
	dualrouteavoid.roadType=this.roadType;
	dualrouteavoid.cargoID=this.cargoID;
	dualrouteavoid.source_istown=this.target_istown;
	dualrouteavoid.target_istown=this.source_istown;
	dualrouteavoid.GetUID();
	if (dualrouteavoid.UID in database) // this remove cases where Paris->Nice(pass/bus) Nice->Paris(pass/bus)
		{
		DWarn("JOBS -> Job "+this.UID+" is a dual route. Dropping job",2);
		dualrouteavoid=null;
		return ;
		}
	dualrouteavoid=null;
	local jobinfo=AICargo.GetCargoLabel(this.cargoID)+"-"+cRoute.RouteTypeToString(this.roadType)+" "+this.distance+"m";
	if (this.UID in database)	DWarn("JOBS -> Job "+this.UID+" already in database",2);
		else	{
			DInfo("JOBS -> Adding job "+this.UID+" ("+parentID+") to job database: "+jobinfo,2);
			database[this.UID] <- this;
			jobIndexer.AddItem(this.UID, 1);
			}
	}

function cJobs::GetUID()
// Create a UID for a job, if not in database, add the job to database
// This also update JobIndexer and parentID
// Return the UID for that job
	{
	local uID=null;
	local parentID = null;
	if (this.UID == null && this.sourceID != null && this.targetID != null && this.cargoID != null && this.roadType != null)
			{
			local v1=this.roadType+1;
			local v2=(this.cargoID+10);
			local v3=(this.targetID+100);
			if (this.target_istown)	v3+=1000;
			local v4=(this.sourceID+10000);
			if (this.source_istown) v4+=4000;
			if (this.roadType == AIVehicle.VT_AIR)	parentID = v4+(this.cargoID+100);
							else	parentID = v4+(this.cargoID+1);
			if (this.roadType == AIVehicle.VT_ROAD && this.cargoID == cCargo.GetPassengerCargo())
				{ parentID = v4+(this.cargoID+300); }
			// parentID: prevent a route done by a transport to be done by another transport
			// As paris->anywhere(v/bus)[parentID=1000] paris->anywhere(pass/train)[parentID=1000]
			// the aircraft different ID means aircraft could always be build, even a bus is doing the job already
			uID = (v3*v4)+(v1*v2);
			this.UID=uID;
			this.parentID=parentID;
		//DInfo("JOBS -> "+uID+" src="+this.sourceID+" tgt="+this.targetID+" crg="+this.cargoID+" rt="+this.roadType);
			}
	return this.UID;
	}

function cJobs::RankThisJob()
// rank the current job
	{
	local valuerank=0;
	local stationrank=0;
	local cargorank=this.cargoValue;
	if (INSTANCE.cargo_favorite==this.cargoID)	cargorank=((20*cargoValue)/100)+cargoValue;// 20% bonus fav cargo
	valuerank= cargorank * cargoAmount;
	if (this.source_istown)
		{
		stationrank= (100- this.foule);
		if (INSTANCE.fairlevel == 2)	stationrank=100; // no malus for level 2
		}
	else	switch (INSTANCE.fairlevel)
			{	
			case	0:
				stationrank= (100 - (this.foule *100));	// give up when 1 station is present
			break;
			case	1:
				stationrank= (100- (this.foule *100));	// give up when 2 stations are there
			break;
			case	2:
				stationrank= (100- (this.foule *100));	// give up after 4 stations
			break;
			}
	if (stationrank <=0 && INSTANCE.fairlevel > 0)	stationrank=1;
	// even crowd, one small chance to get pickup with 1&2 fairlevel, fairlevel 0 will never do that job
	this.ranking = stationrank * valuerank;
	}

function cJobs::RefreshValue(jobID)
// refresh the datas from object
	{
	::AIController.Sleep(1);
	if (jobID == 0 || jobID == 1)	return; // don't refresh virtual routes
	local myjob = cJobs.GetJobObject(jobID);
	if (myjob == null) return null;
	local badind=false;
	if (!myjob.source_istown && !AIIndustry.IsValidIndustry(myjob.sourceID))	badind=true;
	if (!myjob.target_istown && !AIIndustry.IsValidIndustry(myjob.targetID))	badind=true;
	if (badind)
		{
		DInfo("JOBS -> Removing bad industry from the job pool: "+myjob.UID,0);
		local deadroute=cRoute.GetRouteObject(myjob.UID);
		if (deadroute != null)	deadroute.RouteIsNotDoable();
		}
	// foule, moneyGains, ranking & cargoAmount
	if (myjob.source_istown)
		{
		myjob.cargoAmount=AITown.GetLastMonthProduction(myjob.sourceID, myjob.cargoID);
		myjob.foule=AITown.GetLastMonthTransported(myjob.sourceID, myjob.cargoID);
		if (myjob.target_istown)
			{
			myjob.cargoAmount=(myjob.cargoAmount+AITown.GetLastMonthProduction(myjob.targetID, myjob.cargoID)) / 2 ;
			myjob.foule+=AITown.GetLastMonthTransported(myjob.targetID, myjob.cargoID);
			}
		}
	else	{ // industry
		myjob.cargoAmount=AIIndustry.GetLastMonthProduction(myjob.sourceID, myjob.cargoID);
		myjob.foule=cRoute.GetAmountOfCompetitorStationAround(myjob.sourceID);
		}
	myjob.RankThisJob();
	}

function cJobs::RefreshAllValue()
// refesh datas of all objects
{
DInfo("Collecting jobs infos, will take time...",0);
local curr=0;
foreach (item, value in cJobs.jobIndexer)
	{
	cJobs.RefreshValue(item);
	curr++;
	if (curr % 5 == 0)
		{
		DInfo(curr+" / "+cJobs.jobIndexer.Count(),0);
		INSTANCE.Sleep(1);
		}
	}
}

function cJobs::QuickRefresh()
// refresh datas on first 8 doable objects
	{
	local smallList=AIList();
	smallList.AddList(cJobs.jobDoable);
	smallList.KeepTop(8);
	foreach (item, value in smallList)
		{
		cJobs.RefreshValue(item);
		}
	smallList.Sort(AIList.SORT_BY_VALUE,false);
	return smallList;
	}

function cJobs::GetRanking(jobID)
// return the ranking for jobID
	{
	local myjob = cJobs.GetJobObject(jobID);
	if (myjob == null) return 0;
	return myjob.ranking;
	}

function cJobs::GetNextJob()
// Return the next job UID to do, -1 if we have none to do
	{
	INSTANCE.jobs.UpdateDoableJobs();
	//INSTANCE.NeedDelay(100);
	local smallList=QuickRefresh();
	if (smallList.IsEmpty())	{ DInfo("Can't find any good jobs to do",1); return -1; }
	smallList.Sort(AIList.SORT_BY_VALUE, false);
	return smallList.Begin();
	}

function cJobs::CreateNewJob(srcID, tgtID, src_istown, cargo_id, road_type)
	{
	local newjob=cJobs();
	newjob.sourceID = srcID;
	newjob.targetID = tgtID;
	newjob.source_istown = src_istown;
	// filters unwanted jobs, don't let aircraft do something other than pass/mail
	if (road_type == AIVehicle.VT_AIR && (cargo_id != cCargo.GetMailCargo() && cargo_id != cCargo.GetPassengerCargo())) return;
	//if (cargo_id == cCargo.GetMailCargo())	return;
	// only pass & mail for aircraft
	if (cargo_id == cCargo.GetMailCargo() && road_type != AIVehicle.VT_AIR && road_type != AIVehicle.VT_ROAD) return;
	// only do mail with aircraft & trucks
	newjob.target_istown = cCargo.IsCargoForTown(cargo_id);
	if (newjob.source_istown)	newjob.source_location=AITown.GetLocation(srcID);
			else		newjob.source_location=AIIndustry.GetLocation(srcID);
	if (newjob.target_istown)	newjob.target_location=AITown.GetLocation(tgtID);
			else		newjob.target_location=AIIndustry.GetLocation(tgtID);
	newjob.distance=AITile.GetDistanceManhattanToTile(newjob.source_location, newjob.target_location);
	newjob.roadType=road_type;
	newjob.cargoID=cargo_id;
	local money = 0;
	local clean= AITile.GetBuildCost(AITile.BT_CLEAR_HOUSE);
	local engine=0;
	local engineprice=0;
	local daystransit=0;
	switch (newjob.roadType)
		{
		case	AIVehicle.VT_ROAD:
			// 2 vehicle + 2 stations + 2 depot + 4 destuction + 4 road for entry and length*road
			engine=INSTANCE.carrier.ChooseRoadVeh(cargo_id);
			if (engine != null)	engineprice=AIEngine.GetPrice(engine);
					else	engineprice=500000000;
			money+=engineprice*2;
			money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_TRUCK_STOP));
			money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_DEPOT));
			money+=4*clean;
			money+=(4+distance)*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD));
			daystransit=16;
		break;
		case	AIVehicle.VT_RAIL:
			local rtype=AIRail.GetCurrentRailType();
			// 1 vehicle + 2 stations + 2 depot + 4 destuction + 3 tracks entries and length*rail
			engine=INSTANCE.carrier.ChooseRailVeh();
			if (engine != null)	engineprice=AIEngine.GetPrice(engine);
					else	engineprice=500000000;
			money+=engineprice*2; // this should cover some wagons costs
			money+=(2+5)*(AIRail.GetBuildCost(rtype, AIRail.BT_STATION)); // station train 5 length
			money+=2*(AIRail.GetBuildCost(rtype, AIRail.BT_DEPOT));
			money+=4*clean;
			money+=(3+distance)*(AIRail.GetBuildCost(rtype, AIRail.BT_TRACK));
			daystransit=4;
		break;
		case	AIVehicle.VT_WATER: //TODO: finish it
			// 2 vehicle + 2 stations + 2 depot
//			engine=INSTANCE.carrier.ChooseRoadVeh(cargo_id);
			engine=null;
			if (engine != null)	engineprice=AIEngine.GetPrice(engine);
					else	engineprice=500000000;
			money+=engineprice*2;
			money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DOCK));
			money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DEPOT));
			daystransit=32;
		break;
		case	AIVehicle.VT_AIR:
			// 2 vehicle + 2 airports
			engine=INSTANCE.carrier.ChooseAircraft(cargo_id,AircraftType.EFFICIENT);
			if (engine != null)	engineprice=AIEngine.GetPrice(engine);
					else	engineprice=500000000;
			engineprice=AIEngine.GetPrice(engine);
			money+=engineprice*2;
			money+=2*(AIAirport.GetPrice(INSTANCE.builder.GetAirportType()));
			daystransit=6;
		break;
		}
	newjob.cargoValue=AICargo.GetCargoIncome(newjob.cargoID, newjob.distance, daystransit);
	newjob.moneyToBuild=money;
	newjob.GetUID();
	newjob.Save();
	INSTANCE.jobs.RefreshValue(newjob.UID); // update ranking, cargo amount, foule values, must be call after GetUID
	}

function cJobs::GetTransportDistance(transport_type, get_min, limited)
// Return the transport distance a transport_type could do
// get_min = true return minimum distance
// get_min = false return maximum distance
	{
	local small=1000;
	local big=0;
	local target=transport_type * 3;
	local toret=0;
	for (local i=0; i < TRANSPORT_DISTANCE.len(); i++)
		{
		local min=TRANSPORT_DISTANCE[i];
		local lim=TRANSPORT_DISTANCE[i+1];
		local max=TRANSPORT_DISTANCE[i+2];
		if (target == i)
			{
			if (get_min)	toret=min;
				else	toret=(limited) ? lim : max;
			}
		if (min < small)	small=min;
		if (lim > big)		big=lim;
		i+=2; // next iter
		}
	distanceLimits[0]=small;
	distanceLimits[1]=big;
	return toret;
	}

function cJobs::GetJobTarget(src_id, cargo_id, src_istown)
// return an AIList with all possibles destinations, values are location
	{
	local retList=AIList();
	local srcloc=null;
	local rmax=GetTransportDistance(0,false,false); // just to make sure min&max are init
	if (src_istown)	srcloc=AITown.GetLocation(src_id);
			else	srcloc=AIIndustry.GetLocation(src_id);
	if (cCargo.IsCargoForTown(cargo_id))
		{
		retList=AITownList();
		retList.Valuate(AITown.GetPopulation);
		retList.Sort(AIList.SORT_BY_VALUE,false);
		retList.KeepTop(10);
		retList.Valuate(AITown.GetDistanceManhattanToTile, srcloc);
		retList.KeepBetweenValue(distanceLimits[0], rmax);
		retList.Valuate(AITown.GetLocation);
		}
	else	{
		retList=AIIndustryList_CargoAccepting(cargo_id);
		retList.Valuate(AIIndustry.GetDistanceManhattanToTile, srcloc);
		retList.KeepBetweenValue(distanceLimits[0], rmax);
		retList.Valuate(AIIndustry.GetLocation);
		}
	return retList;
	}

function cJobs::GetJobSourceCargoList(src_id, src_istown)
// Return a list of all cargos produce at source
	{
	local cargoList=AIList();
	if (src_istown)
		{
		cargoList.AddItem(cCargo.GetPassengerCargo(), 1);
		cargoList.AddItem(cCargo.GetMailCargo(), 1);
		}
	else	cargoList=AICargoList_IndustryProducing(src_id);
	return cargoList;
	}

function cJobs::GetTransportList(distance)
// Return a list of transport we can use
	{
	// road assign as 2, trains assign as 1, air assign as 4, boat assign as 3
	// it's just AIVehicle.VehicleType+1
	local v_train=1;
	local v_boat =1;
	local v_air  =1;
	local v_road =1;
	local tweaklist=AIList();
	local road_maxdistance=GetTransportDistance(AIVehicle.VT_ROAD,false,false);
	local road_mindistance=GetTransportDistance(AIVehicle.VT_ROAD,true,false);
	local rail_maxdistance=GetTransportDistance(AIVehicle.VT_RAIL,false,false);
	local rail_mindistance=GetTransportDistance(AIVehicle.VT_RAIL,true,false);
	local air_maxdistance=GetTransportDistance(AIVehicle.VT_AIR,false,false);
	local air_mindistance=GetTransportDistance(AIVehicle.VT_AIR,true,false);
	local water_maxdistance=GetTransportDistance(AIVehicle.VT_WATER,false,false);
	local water_mindistance=GetTransportDistance(AIVehicle.VT_WATER,true,false);
	//DInfo("Distances: Truck="+road_mindistance+"/"+road_maxdistance+" Aircraft="+air_mindistance+"/"+air_maxdistance+" Train="+rail_mindistance+"/"+rail_maxdistance+" Boat="+water_mindistance+"/"+water_maxdistance,2);
	local goal=distance;
	if (goal >= road_mindistance && goal <= road_maxdistance)	{ tweaklist.AddItem(1,2*v_road); }
//	if (goal >= rail_mindistance && goal <= rail_maxdistance)	{ tweaklist.AddItem(0,1*v_train); }
	if (goal >= air_mindistance && goal <= air_maxdistance)		{ tweaklist.AddItem(3,4*v_air); }
//	if (goal >= water_mindistance && goal <= water_maxdistance)	{ tweaklist.AddItem(2,3*v_boat); }
	tweaklist.RemoveValue(0);
	return tweaklist;
	}

function cJobs::IsTransportTypeEnable(transport_type)
// return true if that transport type is enable in the game
	{
	switch (transport_type)
		{
		case	AIVehicle.VT_ROAD:
		return	(INSTANCE.use_road);
		case	AIVehicle.VT_AIR:
		return	(INSTANCE.use_air);
		case	AIVehicle.VT_RAIL:
		return	(INSTANCE.use_train);
		case	AIVehicle.VT_WATER:
		return	(INSTANCE.use_boat);
		}
	}
	
function cJobs::JobIsNotDoable(uid)
// set the undoable status for that jobs & rebuild our index
	{
	local badjob=cJobs.GetJobObject(uid);
	badjob.isdoable=false;
	cJobs.UpdateDoableJobs();
	}

function cJobs::UpdateDoableJobs()
// Update the doable status of the job indexer
	{
	INSTANCE.jobs.CheckLimitedStatus();
	DInfo("Analysing the job pool",0);
	local parentListID=AIList();
	INSTANCE.jobs.jobDoable.Clear();
	//local curr=0;
	foreach (id, value in INSTANCE.jobs.jobIndexer)
		{
		if (id == 0 || id == 1)	continue;
//		INSTANCE.builder.DumpJobs(id);
//		INSTANCE.NeedDelay(20);
/*		curr++;
		if (curr % 5 == 0)
			{
			DInfo(curr+" / "+INSTANCE.jobs.jobIndexer.Count(),0);
			INSTANCE.Sleep(1);
			}*/
		local doable=1;
		local myjob=cJobs.GetJobObject(id);
		doable=myjob.isdoable;
		// not doable if not doable
		switch (myjob.roadType)
			{
			case	AIVehicle.VT_AIR:
				if (!INSTANCE.use_air)	doable=false;
				if (INSTANCE.carrier.ChooseAircraft(myjob.cargoID)==-1)	doable=false;
			break;
			case	AIVehicle.VT_ROAD:
				if (!INSTANCE.use_road)	doable=false;
				if (INSTANCE.carrier.ChooseRoadVeh(myjob.cargoID)==-1)	doable=false;
			break;
			case	AIVehicle.VT_WATER:
				if (!INSTANCE.use_boat)	doable=false;
			break;
			case	AIVehicle.VT_RAIL:
				if (!INSTANCE.use_train)	doable=false;
				if (!INSTANCE.carrier.ChooseRailVeh())	doable=false;
			break;
			}
		// not doable if disabled
		if (doable && myjob.isUse)	doable=false;
		// not doable if already done
		if (doable && myjob.ranking==0)	doable=false;
		// not doable if ranking is at 0
		if (doable)	doable=(cBanker.CanBuyThat(myjob.moneyToBuild));
		// not doable if not enough money
		if (doable)
		// not doable if max distance is limited and lower the job distance
			{
			local curmax = INSTANCE.jobs.GetTransportDistance(myjob.roadType, false, !INSTANCE.bank.unleash_road);
			if (curmax < myjob.distance)	doable=false;
			}
		if (doable)
		// not doable if any parent is already in use
		if (parentListID.HasItem(myjob.parentID))	doable=false;
								else	parentListID.AddItem(myjob.parentID,1);
		if (doable)	{ myjob.jobIndexer.SetValue(id, myjob.ranking); myjob.jobDoable.AddItem(id, myjob.ranking); }
			else	myjob.jobIndexer.SetValue(id, 0);
		//if (doable)	DInfo("Doable job "+myjob.UID+" rank="+myjob.ranking,2);
		}
	INSTANCE.jobs.jobDoable.Sort(AIList.SORT_BY_VALUE, false);
	DInfo("JOBS -> "+INSTANCE.jobs.jobIndexer.Count()+" jobs found",2);
	DInfo("JOBS -> "+INSTANCE.jobs.jobDoable.Count()+" jobs doable",2);
	//foreach (id, value in jobDoable)	{ DInfo("After update: "+id+" - "+value,2); }
	}

function cJobs::AddNewIndustryOrTown(industryID, istown)
// Add a new industry/town job: this will add all possibles jobs doable with it (transport type + all cargos)
	{
	local position=0;
	if (istown)	position=AITown.GetLocation(industryID);
		else	position=AIIndustry.GetLocation(industryID);
	local cargoList=GetJobSourceCargoList(industryID, istown);
	foreach (cargoid, cargodummy in cargoList)
		{
		local targetList=GetJobTarget(industryID, cargoid, istown);
		foreach (destination, locations in targetList)
			{
			distance=AITile.GetDistanceManhattanToTile(position, locations)
			// now find possible ways to transport that
			local transportList=GetTransportList(distance);
			foreach (transtype, dummy2 in transportList)
				{
				this.UID=null;
				CreateNewJob(industryID, destination, istown, cargoid, transtype);
				}
			}
		}
	}

function cJobs::DeleteJob(uid)
// Remove a job from our job pool
	{
	if (uid in cJobs.database)
		{
		DInfo("JOBS -> Removing job #"+uid+" from database",2);
		delete cJobs.database[uid];
		cJobs.jobIndexer.RemoveItem(uid);
		cJobs.jobDoable.RemoveItem(uid);
		}
	}

function cJobs::PopulateJobs()
// Find towns and industries and add any jobs we could do with them
{
local indjobs=AIIndustryList();
local townjobs=AITownList();
townjobs.Valuate(AITown.GetPopulation);
townjobs.Sort(AIList.SORT_BY_VALUE,false);
townjobs.KeepTop(40);
//indjobs.KeepTop(0);
local curr=0;
DInfo("Finding all industries & towns jobs, this will take a while !",0);
foreach (ID, dummy in indjobs)
	{
	AddNewIndustryOrTown(ID, false);
	curr++;
	if (curr % 4 == 0)
		{
		DInfo(curr+" / "+(indjobs.Count()+townjobs.Count()));
		INSTANCE.Sleep(1);
		}
	}
foreach (ID, dummy in townjobs)
	{
	AddNewIndustryOrTown(ID, true);
	curr++;
	if (curr % 4 == 0)
		{
		DInfo(curr+" / "+(indjobs.Count()+townjobs.Count()));
		INSTANCE.Sleep(1);
		}
	}
//cJobs.RefreshAllValue();
}