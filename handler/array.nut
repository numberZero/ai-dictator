// This is where we do Datas handling

class cEndDepot
{
	DEPOT = null;
	constructor()
	{
	DEPOT =
		{
		id = -1,
		name="none",
		istown = false,
		distance = 0,
		ranking = 0
		}
	}
}

class cStation
{
	STATION = null;
	bestWay= null;			// hold our best entry/exit
	constructor()
	{
		STATION = {
		station_id = -1,	// the real stationID
		direction = -1,		// the direction of the station
//		depot_id = -1,		// the real depotID
		query=-1,		// Last query for a connection, it's our entry or exit point location
		haveEntry = true,	// station have an usable entry
		haveExit = true,	// station have an usable exit
		railtype = -1,		// 0 : boat
					// 1 : PT_SMALL_PLANE
					// 2 : PT_BIG_PLANE
					// 3 : PT_HELICOPTER
					// 10: BUS_STOP
					// 11: TRUCK_STOP
					// 20+: Trains + railtype value (so >20 railtype=that-20)
		type = -1,		// type = how our station is configure
					// -1: invalid station
					// for boats, no usage
					// for aircraft
					// # : AT_SMALL, AT_LARGE...
					// for road
					// 0 : no more upgrade status					
					// 1 : single station
					// 2 : dual station
					// 0 : no more upgrade status
					// 1 : 1 station
					// 2 : 2 station - 1xentry 1xexit
					// 3 : 2 station - 2xentry
					// 4 : 2 station - 2xexit
					// 5 : 3+ stations 1 entry only
					// 6 : 3+ stations 1 entry 1 exit
		size = 1,		// station width
		e_count=0,		// number of trains using station entry / or vehicle number for other vehicle
		e_depot=-1,		// the depot ID of the depot at exit / or real depot id for other vehicle
		e_loc=0,		// 3rd tile in front of the station entry (1=feu, 2=cross, 3=feu)
		e_link=0,		// tile where to pathfind
		s_count=0,		// number of trains using station exit
		s_depot=-1,		// the depot ID of the depot at station exit
		s_loc=0,		// 3rd tile in front of the station exit (1=feu, 2=cross, 3=feu)
		s_link=0,		// tile where to pathfind
		}
		bestWay=-1;

	}
}

class cCheminItem
{
	ROUTE = null;
	badLocation= null;
	constructor()
	{
		badLocation=[];		// we will hold here all locations where a train station isn't able to be functional
		ROUTE = {
		uniqID = 0,		// an uniqID to identify the ROUTE
		isServed = false,	// if true we use that ROUTE
		//railtype = -1,	// railtype the connection use
		vehicule= 0,		// number of veh using it
		kind=-1,		// type of vehicle on road, 1000=aircraft network
		status=1,		// 0 - undoable
					// 1 - not done yet
					// 2 - need a destination pickup
					// 3 - source/destination find compatible station or create new
					// 4 - need build source station
					// 5 - need build destination station
					// 6 - need do pathfinding
					// 100 - all done, route is ok
					// 999 - route is in a virtual network
					// 666 - route is on error, need repair
		length=0,		// distance from src to dst
		groupe_id=-1,		// groupID
		groupe_name="none",	// groupe name

		src_id = -1,		// industry/town id of starting (a producer)
		src_name = "none",	// name
		src_istown = false,	// a town or not
		src_place= -1,		// location on map
		src_station= -1,	// an index to the station array
		src_entry= -1,		// for trains, true if we are connect to station entry, false we're connect to station exit
					// for road, always true
					// for aircraft, true if we are an airport false if we are a platform
		dst_id = -1,
		dst_name = "none",
		dst_istown= false,
		dst_place= -1,
		dst_station= -1,	// an index to the station array
		dst_entry= -1,		// destination station entry/exit connection

		ranking=0,     		// estimated value of building & do that ROUTE
		handicap=0,		// on failure for a reason, downrank it
		foule=0,    		// crowd stations get also a malus
		cargo_id=-1,		
		cargo_name="none",        
		cargo_value=0,       
		cargo_amount=0,
		}
	}
}


function cChemin::GListGetIndex(idx)
// return real index in our array for a relative idx pos
{
local dummy=cStation();
local realidx=idx*dummy.STATION.len();
if (idx >= root.chemin.GListGetSize() || idx < 0)
	{
	DInfo("Warning: index out of limits with GList !!! idx="+idx+" realidx="+realidx+" GList.len="+root.chemin.GList.len(),1);
	realidx=0;
	}
return realidx;
}

function cChemin::GListDeleteItem(idx)
// Delete item at pos
{
local start=root.chemin.GListGetIndex(idx);
local dummy=cStation();
local end=start+dummy.STATION.len()-1;
//DInfo("Removing from GList from start="+start+" end="+end,2);
local purgeArray=[];
for (local i=0; i < root.chemin.GList.len(); i++)
	{
	if ((i < start) || (i > end))
		{
		purgeArray.push(root.chemin.GList[i]);
		}
	}
root.chemin.GList=purgeArray;
}

function cChemin::GListAddItem(obj)
// Add an new item to GList
// This add dummy space, as we will call GListUpdateItem to update the values
{
local dummy=cStation();
for (local i=0; i < (dummy.STATION.len()); i++)
	{ root.chemin.GList.push("dummy_station"); }
local start=root.chemin.GList.len()/(dummy.STATION.len())-1;
root.chemin.GListUpdateItem(start,obj);
}

function cChemin::GListUpdateItem(idx,obj)
// Update item #idx with obj
{
local start=root.chemin.GListGetIndex(idx);
local next=start;
root.chemin.GList[next]=obj.STATION.station_id;	next++;
root.chemin.GList[next]=obj.STATION.direction;	next++;
//root.chemin.GList[next]=obj.STATION.depot_id;	next++;
root.chemin.GList[next]=obj.STATION.query;	next++;
root.chemin.GList[next]=obj.STATION.haveEntry;	next++;
root.chemin.GList[next]=obj.STATION.haveExit;	next++;
root.chemin.GList[next]=obj.STATION.railtype;	next++;
root.chemin.GList[next]=obj.STATION.type;	next++;
root.chemin.GList[next]=obj.STATION.size;	next++;
root.chemin.GList[next]=obj.STATION.e_count;	next++;
root.chemin.GList[next]=obj.STATION.e_depot;	next++;
root.chemin.GList[next]=obj.STATION.e_loc;	next++;
root.chemin.GList[next]=obj.STATION.e_link;	next++;
root.chemin.GList[next]=obj.STATION.s_count;	next++;
root.chemin.GList[next]=obj.STATION.s_depot;	next++;
root.chemin.GList[next]=obj.STATION.s_loc;	next++;
root.chemin.GList[next]=obj.STATION.s_link;
//DInfo("Update station #"+idx,2);
root.chemin.GListDumpOne(idx);	
}

function cChemin::GListGetItem(idx)
// Get item #idx with obj
{
local obj=cStation();
local next=root.chemin.GListGetIndex(idx);
if (idx >= root.chemin.GListGetSize())
	{ DWarn("Not a valid GList index !"); return false;}
obj.STATION.station_id=root.chemin.GList[next];	next++;
obj.STATION.direction=root.chemin.GList[next];	next++;
//obj.STATION.depot_id=root.chemin.GList[next];	next++;
obj.STATION.query=root.chemin.GList[next];	next++;
obj.STATION.haveEntry=root.chemin.GList[next];	next++;
obj.STATION.haveExit=root.chemin.GList[next];	next++;
obj.STATION.railtype=root.chemin.GList[next];	next++;
obj.STATION.type=root.chemin.GList[next];	next++;
obj.STATION.size=root.chemin.GList[next];	next++;
obj.STATION.e_count=root.chemin.GList[next];	next++;
obj.STATION.e_depot=root.chemin.GList[next];	next++;
obj.STATION.e_loc=root.chemin.GList[next];	next++;
obj.STATION.e_link=root.chemin.GList[next];	next++;
obj.STATION.s_count=root.chemin.GList[next];	next++;
obj.STATION.s_depot=root.chemin.GList[next];	next++;
obj.STATION.s_loc=root.chemin.GList[next];	next++;
obj.STATION.s_link=root.chemin.GList[next];	
return obj;	
}

function cChemin::GListGetSize()
{
local dummy=cStation();
return root.chemin.GList.len() / dummy.STATION.len();
}

function cChemin::DListGetSize()
{
local dummy=cEndDepot();
return root.chemin.DList.len() / dummy.DEPOT.len();
}

function cChemin::DListGetIndex(idx)
// this function return the real index in our array for a relative idx position
{
local dummy=cEndDepot();
local realidx=idx*dummy.DEPOT.len();
if (idx > root.chemin.DListGetSize() || idx < 0)
	{
	DWarn("Warning: index out of limits with DList !!! idx="+idx+" realidx="+realidx+" DList.len="+root.chemin.DList.len(),1);
	realidx=0;
	}
return realidx;
}

function cChemin::DListReset()
// just to reset our DList to create a new one
{
root.chemin.DList=[];
}

function cChemin::DListAddItem(obj)
// Add an new item to DList
// This add dummy space, as we will call DListUpdateItem to really add some values
{
local dummy=cEndDepot();
for (local i=0; i < (dummy.DEPOT.len()); i++)
	{ root.chemin.DList.push("dummy_EndDepot"); }
local start=root.chemin.DList.len()/(dummy.DEPOT.len())-1;
root.chemin.DListUpdateItem(start,obj);
}

function cChemin::DListUpdateItem(idx,obj)
// Update item #idx with obj
{
local start=root.chemin.DListGetIndex(idx);
local next=start;
root.chemin.DList[next]=obj.DEPOT.id;	next++;
root.chemin.DList[next]=obj.DEPOT.name;	next++;
root.chemin.DList[next]=obj.DEPOT.istown;	next++;
root.chemin.DList[next]=obj.DEPOT.distance;	next++;
root.chemin.DList[next]=obj.DEPOT.ranking;
}

function cChemin::DListGetItem(idx)
// get item idx in DList
{
local ret=cEndDepot();
local start=root.chemin.DListGetIndex(idx);
local next=start;
ret.DEPOT.id=root.chemin.DList[next];	next++;
ret.DEPOT.name=root.chemin.DList[next];	next++;
ret.DEPOT.istown=root.chemin.DList[next];	next++;
ret.DEPOT.distance=root.chemin.DList[next];	next++;
ret.DEPOT.ranking=root.chemin.DList[next];	
return ret;
}

function cChemin::RListDeleteItem(idx)
// Delete item at pos
{
local start=root.chemin.RListGetIndex(idx);
local end=start+root.chemin.Item.ROUTE.len()-1;
//DInfo("Removing from RList start="+start+" end="+end,2);
local purgeArray=[];
for (local i=0; i < root.chemin.RList.len(); i++)
	{
	if ((i < start) || (i > end))
		{
		purgeArray.push(root.chemin.RList[i]);
		}
	}
root.chemin.RList=purgeArray;
}

function cChemin::RListGetSize()
{
local dummy=cCheminItem();
return root.chemin.RList.len() / dummy.ROUTE.len();
}

function cChemin::RListGetIndex(idx)
// this function return the real index in our array for a relative idx position
{
local dummy=cCheminItem();
local realidx=idx*dummy.ROUTE.len();
if (idx > root.chemin.RListGetSize() || idx < 0)
	{
	DInfo("Warning: index out of limits with RList !!! idx="+idx+" realidx="+realidx+" RList.len="+root.chemin.RList.len(),1);
	realidx=0;
	}
return realidx;
}

function cChemin::RListUpdateItem(idx,road)
// Update the RList idx with road datas
{
local dummy = cCheminItem();
local start=root.chemin.RListGetIndex(idx);
//DInfo("Updating: idx="+idx+" start="+start+" end="+end,2);
local next=start;
root.chemin.RList[next]=road.ROUTE.uniqID;		next++;
root.chemin.RList[next]=road.ROUTE.isServed;		next++;
//root.chemin.RList[next]=road.ROUTE.railtype;		next++;
root.chemin.RList[next]=road.ROUTE.vehicule;		next++;
root.chemin.RList[next]=road.ROUTE.kind;		next++;
root.chemin.RList[next]=road.ROUTE.status;		next++;
root.chemin.RList[next]=road.ROUTE.length;		next++;
root.chemin.RList[next]=road.ROUTE.groupe_id;		next++;
root.chemin.RList[next]=road.ROUTE.groupe_name;		next++;
root.chemin.RList[next]=road.ROUTE.src_id;		next++;
root.chemin.RList[next]=road.ROUTE.src_name;		next++;
root.chemin.RList[next]=road.ROUTE.src_istown;		next++;
root.chemin.RList[next]=road.ROUTE.src_place;		next++;
root.chemin.RList[next]=road.ROUTE.src_station;		next++;
root.chemin.RList[next]=road.ROUTE.src_entry;		next++;
root.chemin.RList[next]=road.ROUTE.dst_id;		next++;
root.chemin.RList[next]=road.ROUTE.dst_name;		next++;
root.chemin.RList[next]=road.ROUTE.dst_istown;		next++;
root.chemin.RList[next]=road.ROUTE.dst_place;		next++;
root.chemin.RList[next]=road.ROUTE.dst_station;		next++;
root.chemin.RList[next]=road.ROUTE.dst_entry;		next++;
root.chemin.RList[next]=road.ROUTE.ranking;		next++;
root.chemin.RList[next]=road.ROUTE.handicap;		next++;	
root.chemin.RList[next]=road.ROUTE.foule;		next++;	
root.chemin.RList[next]=road.ROUTE.cargo_id;		next++;
root.chemin.RList[next]=road.ROUTE.cargo_name;		next++;
root.chemin.RList[next]=road.ROUTE.cargo_value;		next++;
root.chemin.RList[next]=road.ROUTE.cargo_amount;	
//root.job.RListDump();
}

function cChemin::RListAddItem(road)
// Add an item to our list, an item is a road
{
local dummy = cCheminItem();
local oneItemSize=dummy.ROUTE.len();
for (local i=0; i < oneItemSize; i++)
	{
	root.chemin.RList.push(0);
	}
local lastItem=(root.chemin.RList.len()/oneItemSize)-1;
//DInfo("oneSize="+oneItemSize+" LastEntryLoc="+lastItem+" size="+root.chemin.RList.len(),2);
root.chemin.RListUpdateItem(lastItem,road);
// now update our list with our road values
// this way we re-use the RListUpdateItem function instead of creating one to add them
}

function cChemin::RListGetItem(idx)
// return a ROUTE fill with the idx datas from the array
{
local toReturn=cCheminItem();
local next=root.chemin.RListGetIndex(idx);
//DInfo("RListGetITem="+idx+" next="+next,2);
toReturn.ROUTE.uniqID=root.chemin.RList[next];		next++;
toReturn.ROUTE.isServed=root.chemin.RList[next];	next++;
//toReturn.ROUTE.railtype=root.chemin.RList[next];	next++;
toReturn.ROUTE.vehicule=root.chemin.RList[next];	next++;
toReturn.ROUTE.kind=root.chemin.RList[next];		next++;
toReturn.ROUTE.status=root.chemin.RList[next];		next++;
toReturn.ROUTE.length=root.chemin.RList[next];		next++;
toReturn.ROUTE.groupe_id=root.chemin.RList[next];	next++;
toReturn.ROUTE.groupe_name=root.chemin.RList[next];	next++;
toReturn.ROUTE.src_id=root.chemin.RList[next];		next++;
toReturn.ROUTE.src_name=root.chemin.RList[next];	next++;
toReturn.ROUTE.src_istown=root.chemin.RList[next];	next++;
toReturn.ROUTE.src_place=root.chemin.RList[next];	next++;
toReturn.ROUTE.src_station=root.chemin.RList[next];	next++;
toReturn.ROUTE.src_entry=root.chemin.RList[next];	next++;
toReturn.ROUTE.dst_id=root.chemin.RList[next];		next++;
toReturn.ROUTE.dst_name=root.chemin.RList[next];	next++;
toReturn.ROUTE.dst_istown=root.chemin.RList[next];	next++;
toReturn.ROUTE.dst_place=root.chemin.RList[next];	next++;
toReturn.ROUTE.dst_station=root.chemin.RList[next];	next++;
toReturn.ROUTE.dst_entry=root.chemin.RList[next];	next++;
toReturn.ROUTE.ranking=root.chemin.RList[next];		next++;
toReturn.ROUTE.handicap=root.chemin.RList[next];	next++;
toReturn.ROUTE.foule=root.chemin.RList[next];		next++;
toReturn.ROUTE.cargo_id=root.chemin.RList[next];	next++;
toReturn.ROUTE.cargo_name=root.chemin.RList[next];	next++;
toReturn.ROUTE.cargo_value=root.chemin.RList[next];	next++;
toReturn.ROUTE.cargo_amount=root.chemin.RList[next];	next++;
return toReturn;
}


/*

DIR_NW(0) & DIR_SE(1) -> NW_SE
DIR_NE(2) & DIR_SW(3) -> NE_SW


NW_SE = \
NE_SW = --







*/
