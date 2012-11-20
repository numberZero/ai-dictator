/* -*- Mode: C++; tab-width: 6 -*- */ 
/**
 *    This file is part of DictatorAI
 *    (c) krinn@chez.com
 *
 *    It's free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 2 of the License, or
 *    any later version.
 *
 *    You should have received a copy of the GNU General Public License
 *    with it.  If not, see <http://www.gnu.org/licenses/>.
 *
**/

class cRoute extends cClass
	{
static	database = {};
static	RouteIndexer = AIList();	// list all UID of routes we are handling
static	GroupIndexer = AIList();	// map a group->UID, item=group, value=UID
static	RouteDamage = AIList(); 	// list of routes that need repairs
static	WorldTiles = AIList();		// tiles we own, hard to get
static	VirtualAirGroup = [-1,-1,0];	// [0]=networkpassenger groupID, [1]=networkmail groupID [2]=total capacity of aircrafts in network

static	function GetRouteObject(UID)
		{
		if (UID in cRoute.database)	return cRoute.database[UID];
						else	{
							cRoute.RouteRebuildIndex();
							return null;
							}
		}

	UID			= null;	// UID for that route, 0/1 for airnetwork, else = the one calc in cJobs
	Name			= null;	// Name of the route
	SourceProcess	= null;	// link to source process
	TargetProcess	= null;	// link to target process
	SourceStation	= null;	// link to source station
	TargetStation	= null;	// link to target station
	VehicleCount	= null;	// numbers of vehicle using it
	VehicleType		= null;	// type of vehicle using that route (It's enum RouteType)
	StationType		= null;	// type of station (it's AIStation.StationType)
	RailType		= null;	// type of rails in use, same as the first working station done
	Distance		= null;	// farest distance from source station to target station
	Status		= null;	// current status of the route
						// 0 - need a destination pickup
						// 1 - source/destination find compatible station or create new
						// 2 - need build source station
						// 3 - need build destination station
						// 4 - need do pathfinding
						// 5 - need checks
						// 100 - all done, finish route
	GroupID		= null;	// groupid of the group for that route
	CargoID		= null;	// the cargo id
	DateVehicleDelete = null;	// date of last time we remove a vehicle
	DateHealthCheck	= null;	// date of last time we check route health
	Source_RailEntry	= null;	// if rail, do trains use that station entry=true, or exit=false
	Target_RailEntry	= null;	// if rail, do trains use that station entry=true, or exit=false
	Primary_RailLink	= null;	// true if we have build the main connecting rails from source to target station
	Secondary_RailLink= null;	// true if we also buld the alternate path from source to target
	Twoway		= null;	// if source station and target station accept but also produce, it's a twoway route

	constructor()
		{ // * are saved variables
		UID			= null;
		Name			= "UNKNOWN route";
		SourceProcess	= null;
		TargetProcess	= null;
		SourceStation	= null;
		TargetStation	= null;
		VehicleCount	= 0;
		VehicleType		= null;		// *
		StationType		= null;
		RailType		= null;
		Distance		= 0;
		Status		= 0;			// *
		GroupID		= null;		// *
		CargoID		= null;
		DateVehicleDelete = 0;
		DateHealthCheck	= 0;
		Source_RailEntry	= null;		// *
		Target_RailEntry	= null;		// *
		Primary_RailLink	= false;		// *
		Secondary_RailLink= false;		// *
		Twoway		= false;
		this.ClassName = "cRoute";
		}
	}

function cRoute::Load(uid)
// Get a route object
{
	local thatroute=cRoute.GetRouteObject(uid);
	if (thatroute == null)	{ DWarn("Invalid routeID : "+uid+". Cannot get object",1); return false; }
	return thatroute;
}

function cRoute::RouteTypeToString(that_type)
// return a string for that_type road type
{
	switch (that_type)
		{
		case	RouteType.RAIL:
			return "Trains";
		case	RouteType.ROAD:
			return "Bus & Trucks";
		case	RouteType.WATER:
			return "Boats";
		case	RouteType.AIR:
		case	RouteType.AIRMAIL:
		case	RouteType.AIRNET:
		case	RouteType.AIRNETMAIL:
			return "Big Aircrafts";
		case	RouteType.SMALLAIR:
		case	RouteType.SMALLMAIL:
			return "Small Aircrafts";
		case	RouteType.CHOPPER:
			return "Choppers";
		}
	return "unkown";
}

function cRoute::GetRouteName(uid)
{
	local road = cRoute.Load(uid);
	if (!road)	return "Invalid Route "+uid;
	return road.Name;
}

function cRoute::SetRouteName()
// set a string for that route
{
	local name="### Invalid route";
	local vroute = false;
	local rtype=cRoute.RouteTypeToString(this.VehicleType);
	if (this.UID == 0) // ignore virtual route, use by old savegame
		{
		name="Virtual Air Passenger Network for "+cCargo.GetCargoLabel(this.CargoID)+" using "+rtype;
		vroute=true;
		}
	if (this.UID == 1)
		{
		name="Virtual Air Mail Network for "+cCargo.GetCargoLabel(this.CargoID)+" using "+rtype;
		vroute=true;
		}
	local src=(typeof(this.SourceStation) == "instance");
	local dst=(typeof(this.TargetStation) == "instance");
	if (vroute)	this.Name = name;
		else	{
			if (src)	src=this.SourceStation.s_Name;
				else	src=this.SourceProcess.Name;
			if (dst)	dst=this.TargetStation.s_Name;
				else	dst=this.TargetProcess.Name;
			this.Name="#"+this.UID+": From "+src+" to "+dst+" for "+cCargo.GetCargoLabel(this.CargoID)+" using "+rtype;
			}
}

function cRoute::RouteInitNetwork()
// Add the network routes to the database
	{
	local passRoute=cRoute();
	passRoute.UID=0;
	passRoute.CargoID=cCargo.GetPassengerCargo();
	passRoute.VehicleType = RouteType.AIRNET;
	passRoute.StationType = AIStation.STATION_AIRPORT;
	passRoute.Status=100;
	passRoute.Distance = 1000; // a dummy distance start value
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	passRoute.GroupID=n;
	cRoute.SetRouteGroupName(passRoute.GroupID, 0, 0, true, true, passRoute.CargoID, true);
	cRoute.VirtualAirGroup[0]=n;
	passRoute.RouteSave();

	local mailRoute=cRoute();
	mailRoute.UID=1;
	mailRoute.CargoID=cCargo.GetMailCargo();
	mailRoute.VehicleType = RouteType.AIRNETMAIL;
	mailRoute.StationType = AIStation.STATION_AIRPORT;
	mailRoute.Status=100;
	mailRoute.Distance = 1000;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	mailRoute.GroupID=n;
	cRoute.SetRouteGroupName(mailRoute.GroupID, 1, 1, true, true, mailRoute.CargoID, true);
	cRoute.VirtualAirGroup[1]=n;
	GroupIndexer.AddItem(cRoute.GetVirtualAirPassengerGroup(),0);
	GroupIndexer.AddItem(cRoute.GetVirtualAirMailGroup(),1);
	mailRoute.SourceStation = passRoute.SourceStation;
	mailRoute.TargetStation = passRoute.TargetStation;
	mailRoute.RouteSave();
	}

function cRoute::GetVirtualAirMailGroup()
// return the groupID for the mail virtual air group
	{
	return cRoute.VirtualAirGroup[1];
	}

function cRoute::GetVirtualAirPassengerGroup()
// return the groupID for the passenger virtual air group
	{
	return cRoute.VirtualAirGroup[0];
	}

function cRoute::RouteSetDistance()
// Setup a route distance
	{
	local a, b= -1;
	if (this.SourceProcess != null)	a=this.SourceProcess.Location;
	if (this.TargetProcess != null)	b=this.TargetProcess.Location;
	if (this.SourceStation != null)	a=this.SourceStation.s_Location;
	if (this.TargetStation != null)	b=this.TargetStation.s_Location;
	if (a > -1 && b > -1)	this.Distance=AITile.GetDistanceManhattanToTile(a,b);
				else	this.Distance=0;
	}