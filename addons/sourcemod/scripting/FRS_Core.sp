#pragma semicolon 1
#pragma newdecls required

#include <FakeRank_Sync>
#include <sdkhooks>
#include <sdktools>

#define MaxRanks 10

public Plugin myinfo = 
{
	name		= "[FRS] Core",
	version		= "2.2",
	description	= "Sync all Fake Ranks",
	author		= "ღ λŌK0ЌЭŦ ღ ™",
	url			= "https://github.com/IL0co"
}

char RegisterKeys[MaxRanks][16];

int RegisterId[MaxRanks],
	iRegisterValue[MAXPLAYERS+1][MaxRanks],
	iCount[MAXPLAYERS+1];	

bool iIsScore[MAXPLAYERS+1];
int meTime[MAXPLAYERS+1];
int cycle;

Handle AllTimer;
int m_iCompetitiveRanking;

float cTime; 	
int   cSort, cType;
char cPrior[MaxRanks][16];		
bool cUpdateMode;
 
ConVar 	cvar_Time,
		cvar_Sort,
		cvar_UpdateMode,
		cvar_Type,
		cvar_Priority;

#include "fakerank_sync/api.sp"

public void OnPluginStart()
{
	LoadForwards();
	
	(cvar_Time = CreateConVar("sm_sync_time", "2.0", "RU: Время смены одной иконки на другую \n EN: Time for changing one icon to another", _, true, 0.1)).AddChangeHook(OnVarChanged);
	cTime = cvar_Time.FloatValue;

	(cvar_Sort  = CreateConVar("sm_sync_sort", "0", "RU: Тип сортировки: 0 - нету; 1 - по приоритетам \nEN: Type of sorting: 0 - no; 1 - by priority", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cSort = cvar_Sort.IntValue;

	(cvar_Type  = CreateConVar("sm_sync_type", "0", "RU: Тип отображения: 0 - отображать предыдущее при нулях; 1 - пропускать нули (покажет следущую иконку) \nEN: Display Type: 0 - display the previous one at zeros; 1 - skip zeros (will show the next icon)", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cType = cvar_Type.IntValue;

	(cvar_UpdateMode  = CreateConVar("sm_sync_update_mode", "0", "RU: Режим обновления когда смотришь в таб. 0 - \"плавно\"; 1 - резко) \n EN: Update mode when you look at tab. 0 - \"smoothly \"; 1 - sharply", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cUpdateMode = cvar_UpdateMode.BoolValue;

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
	ReplyToCommand(client, "Snapshot successfully created!");
	PushToKv();
	return Plugin_Handled;
}

public void OnVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue) 
{
	if(cvar == cvar_Type)	
		cType = cvar.IntValue;
	else if(cvar == cvar_UpdateMode)	
		cUpdateMode = cvar.BoolValue;

	else if(cvar == cvar_Sort)
	{
		cSort = cvar.IntValue;

		ClearRegister();
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
	
	iCount[client] = 0;

	for(int poss = 0; poss < MaxRanks; poss++)
		iRegisterValue[client][poss] = 0;

	if(cSort != 1)
	{
		for(int i = 1; i <= MaxClients; i++)	if(client != i && IsValidPlayer(i))
		{
			meTime[client] = meTime[i];
			break;
		}
	}
	// meTime[client] = cycle;

	CreateTimer(1.0, OnClientLoaded, GetClientUserId(client));
}

public Action OnClientLoaded(Handle timer, any client)
{
	client = GetClientOfUserId(client);

	Call_StartForward(forward_OnClientLoaded);
	Call_PushCell(client);
	Call_Finish();
}

public void OnPlayerRunCmdPost(int client, int iButtons)
{
	static bool no_score[MAXPLAYERS+1];

	if(iButtons & IN_SCORE) 
	{
		if(no_score[client])
		{
			if(!cUpdateMode)
			{
				StartMessageOne("ServerRankRevealAll", client, USERMSG_BLOCKHOOKS);
				EndMessage();
			}

			iIsScore[client] = true;
		}
	}
	else if(iIsScore[client])
	{
		iIsScore[client] = false;
	}
	

	no_score[client] = !(iButtons & IN_SCORE);
}

public void OnThinkPost(int iEnt)
{   
	static int Id, oldId[MAXPLAYERS+1];

	for(int i = 1; i <= MaxClients; i++)	
	{
		if(!IsValidPlayer(i))
			continue;

		if(!iCount[i])
			oldId[i] = 0;

		if((Id = iRegisterValue[i][meTime[i]]) <= 0)
			Id = oldId[i];

		SetEntData(iEnt, m_iCompetitiveRanking + i*4, Id);

		oldId[i] = Id;

		if(cUpdateMode && iIsScore[i])
		{
			StartMessageOne("ServerRankRevealAll", i, USERMSG_BLOCKHOOKS);
			EndMessage();
		}
	}
} 

public Action Timer_GenerageId(Handle timer)
{
	if(cSort == 1)
	{
		for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
		{
			for(int poss = 0; poss < MaxRanks; poss++)	if(iRegisterValue[i][poss]) 
			{
				meTime[i] = poss;
				break;
			}
		} 
	}
	else
	{
		for(int poss = 0; poss < MaxRanks; poss++)
		{
			if(cycle++ >= MaxRanks-1)
				cycle = 0;

			if(!RegisterId[cycle])
				continue;
				
			if(cType == 0 || cType == 1 && RegisterId[cycle])
				break;
		}

		for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
		{
			if(cType == 0)
				meTime[i] = cycle;
	
			else if(cType == 1)
			{
				for(int poss = 0; poss < MaxRanks; poss++)
				{
					if(meTime[i]++ >= MaxRanks-1)
						meTime[i] = 0;

					if(!RegisterId[meTime[i]])
						continue;
					
					if(iRegisterValue[i][meTime[i]])
						break;
				}
			}
		} 
	}
}

stock void RestartTimer()
{
	for(int i = 1; i <= MaxClients; i++)
		meTime[i] = 0;

	if(AllTimer) delete AllTimer;
	AllTimer = CreateTimer(cTime, Timer_GenerageId, _, TIMER_REPEAT);	
}

stock void ProcessCvarPriority(ConVar cvar)
{
	char sBuffer[10];
	cvar.GetString(sBuffer, sizeof(sBuffer));

	ClearRegister();

	TrimString(sBuffer);
	ExplodeString(sBuffer, ";", RegisterKeys, sizeof(RegisterKeys), sizeof(RegisterKeys[]));

	ReloadListToPriorityMode();
}

stock void ReloadListToPriorityMode()
{
	OnAllPluginsLoaded();

	for(int i = 1; i <= MaxClients; i++) if(IsValidPlayer(i))
		OnClientPostAdminCheck(i);
}

stock void ClearRegister()
{
	for(int poss = 0; poss < sizeof(cPrior); poss++)
		{
			RegisterKeys[poss][0] = '\0';
			RegisterId[poss] = 0;
		}
}

stock void PushToKv()
{
	KeyValues kv = new KeyValues("fakeranks");

	char name[64];

	if(kv.JumpToKey("Register", true))
	{
		for(int poss = 0; poss < MaxRanks; poss++)
		{
			Format(name, sizeof(name), "%i = %s", poss, RegisterKeys[poss][0] ? RegisterKeys[poss] : "NONE");
			kv.SetNum(name, RegisterId[poss]);
		}
	}
	kv.Rewind();

	kv.JumpToKey("Clients", true);
	int allCount;

	for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))	
		allCount++;

	kv.SetNum("ALL PLAYERS COUNT", allCount);
	

	for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
	{
		Format(name, sizeof(name), "%L", i);
		kv.SavePosition();
		if(kv.JumpToKey(name, true))
		{
			kv.SetNum("MY RANK ALL COUNT", iCount[i]);

			for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterKeys[poss][0] && RegisterId[poss])
				kv.SetNum(RegisterKeys[poss], iRegisterValue[i][poss]);
		}
		kv.GoBack();
	}

	kv.Rewind();
	kv.ExportToFile("addons/sourcemod/logs/fakerank_snapshot.txt");
	
	delete kv;
}

stock bool IsValidPlayer(int client)
{
	return IsClientAuthorized(client) && IsClientConnected(client);
}
