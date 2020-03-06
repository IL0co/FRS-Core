#pragma semicolon 1
#pragma newdecls required

#include <FakeRank_Sync>
#include <sdkhooks>
#include <sdktools>

#define MaxRanks 10

public Plugin myinfo = 
{
	name		= "[FRS] Core",
	version		= "2.0",
	description	= "Sync all Fake Ranks",
	author		= "ღ λŌK0ЌЭŦ ღ ™",
	url			= "https://github.com/IL0co"
}

char RegisterKeys[MaxRanks][16];

int RegisterId[MaxRanks],
	iRegisterValue[MAXPLAYERS+1][MaxRanks];	

int meTime[MAXPLAYERS+1];

Handle AllTimer;
int m_iCompetitiveRanking;

float cTime; 	
int   cSort, cType;
char cPrior[MaxRanks][16];		

#include "fakerank_sync/api.sp"
 
ConVar 	cvar_Time,
		cvar_Sort,
		cvar_Type,
		cvar_Priority;

public void OnPluginStart()
{
	LoadForwards();
	
	(cvar_Time = CreateConVar("sm_sync_time", "2.0", "RU: Время смены одной иконки на другую \n EN: Time for changing one icon to another", _, true, 0.1)).AddChangeHook(OnVarChanged);
	cTime = cvar_Time.FloatValue;

	(cvar_Sort  = CreateConVar("sm_sync_sort", "0", "RU: Тип сортировки: 0 - нету; 1 - по приоритетам; 2 - рандом \nEN: Type of sorting: 0 - no; 1 - by priority; 2 - random", _, true, 0.0, true, 2.0)).AddChangeHook(OnVarChanged);
	cSort = cvar_Sort.IntValue;

	(cvar_Type  = CreateConVar("sm_sync_type", "0", "RU: Тип отображения: 0 - отображать предыдущее при нулях; 1 - пропускать нули (покажет следущую иконку) \nEN: Display Type: 0 - display the previous one at zeros; 1 - skip zeros (will show the next icon)", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cType = cvar_Type.IntValue;

	(cvar_Priority = CreateConVar("sm_sync_priority", "vip;shop", "RU: Приоритет отображения, чем первее в строке, тем выше приоритет \nEN: Display priority, the first in the line, the higher the priority")).AddChangeHook(OnVarChanged);
	ProcessCvarPriority(cvar_Priority);

	if((m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking")) < 1)
		SetFailState("Can't get offset 'm_iCompetitiveRanking'!");

	OnAllPluginsLoaded();
	RestartTimer();
	AutoExecConfig(true, "FRS_Core");

	RegConsoleCmd("sm_frs_snapshot", Cmd_SnapShot, "Takes a snapshot of the entire register and logs into the KV logs with a file");
}

public Action Cmd_SnapShot(int client, int args)
{	
	ReplyToCommand(client, "Снапшот успешно создан!");
	PushToKv();
	return Plugin_Handled;
}

public void OnVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue) 
{
	if(cvar == cvar_Type)	
		cType = cvar.IntValue;

	else if(cvar == cvar_Sort)
	{
		cSort = cvar.IntValue;

		ReloadListToPriorityMode();
	}

	else if(cvar == cvar_Time)
		cTime = cvar.FloatValue;

	else if(cvar == cvar_Priority)
		ProcessCvarPriority(cvar);
	
	RestartTimer();
}

public void OnMapStart()
{
	SDKHook(FindEntityByClassname(-1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);

	char szBuffer[256];
	for(int poss = 1; poss <= 85; poss++)
	{
		Format(szBuffer, sizeof(szBuffer), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", poss);
		if(FileExists(szBuffer))	AddFileToDownloadsTable(szBuffer);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsValidPlayer(client))
		return;

	for(int poss = 0; poss < MaxRanks; poss++)
		iRegisterValue[client][poss] = 0;

	for(int i = 1; i <= MaxClients; i++)	if(client != i && IsValidPlayer(i))
	{
		meTime[client] = meTime[i];
		break;
	}

	CreateTimer(1.0, OnClientLoaded, GetClientUserId(client));
}

public Action OnClientLoaded(Handle timer, any client)
{
	client = GetClientOfUserId(client);

	Call_StartForward(forward_OnClientLoaded);
	Call_PushCell(client);
	Call_Finish();
}

public void OnPlayerRunCmdPost(int client, int buttons)
{
	if(buttons & IN_SCORE)
	{
		StartMessageOne("ServerRankRevealAll", client, USERMSG_BLOCKHOOKS);
		EndMessage();
	}
}

public void OnThinkPost(int iEnt)
{   
	static int id;

	for(int i = 1; i <= MaxClients; i++)	if((id = iRegisterValue[i][meTime[i]]) > 0)
	{
		SetEntData(iEnt, m_iCompetitiveRanking + i*4, id);
	}
} 

public Action TimeTimer(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
	{
		for(int poss = 0; poss < MaxRanks; poss++)
		{
			if(meTime[i]++ >= MaxRanks-1)
				meTime[i] = 0;

			if(!iRegisterValue[i][meTime[i]])
				continue;
				
			if(cType == 0 || cType == 1 && RegisterId[meTime[i]])
				break;
		}
	} 
}

stock void RestartTimer()
{
	for(int i = 1; i <= MaxClients; i++)
		meTime[i] = 0;

	if(AllTimer) delete AllTimer;
	AllTimer = CreateTimer(cTime, TimeTimer, _, TIMER_REPEAT);	
}

stock void ProcessCvarPriority(ConVar cvar)
{
	char sBuffer[10];
	cvar.GetString(sBuffer, sizeof(sBuffer));
	
	TrimString(sBuffer);
	ExplodeString(sBuffer, ";", cPrior, sizeof(cPrior), sizeof(cPrior[]));

	ReloadListToPriorityMode();
}

stock void ReloadListToPriorityMode()
{
	if(cSort == 1)
	{
		for(int poss = 0; poss < sizeof(cPrior); poss++) if(cPrior[poss][0])
			Format(RegisterKeys[poss], sizeof(RegisterKeys), cPrior[poss]);
	}

	else if(cSort == 2)
	{
		SortStrings(RegisterKeys, sizeof(RegisterKeys), Sort_Random);
	}

	OnAllPluginsLoaded();

	for(int i = 1; i <= MaxClients; i++) if(IsValidPlayer(i))
		OnClientPostAdminCheck(i);
}

stock void PushToKv()
{
	KeyValues kv = new KeyValues("fakeranks");

	char name[32];

	if(kv.JumpToKey("Register", true))
	{
		for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterKeys[poss][0])
			kv.SetNum(RegisterKeys[poss], RegisterId[poss]);
	}
	kv.Rewind();

	kv.JumpToKey("Clients", true);
	for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
	{
		Format(name, sizeof(name), "%L", i);
		kv.SavePosition();
		if(kv.JumpToKey(name, true))
		{
			for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterKeys[poss][0] && RegisterId[poss])
				kv.SetNum(RegisterKeys[poss], iRegisterValue[i][poss]);

			int count = 0;
			for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterId[poss])
				count++;

			kv.SetNum("Rank count", count);
		}
		kv.GoBack();
	}

	kv.Rewind();
	kv.ExportToFile("addons/sourcemod/logs/fakerank_snapshot.txt");
	
	delete kv;
}

stock bool IsValidPlayer(int client)
{
	return IsClientAuthorized(client) && IsClientInGame(client) && GetClientTeam(client) > 1;
}
