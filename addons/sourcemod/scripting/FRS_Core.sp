#include <FakeRank_Sync>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required


#define MaxRanks 10

public Plugin myinfo = 
{
	name		= "[FRS] Core",
	version		= "2.1.2",
	description	= "Sync all Fake Ranks",
	author		= "iLoco",
	url			= "https://github.com/IL0co"
}

char RegisterKeys[MaxRanks][16];

int RegisterId[MaxRanks],
	iRegisterValue[MAXPLAYERS+1][MaxRanks][2],
	iCount[MAXPLAYERS+1][2];	

bool iIsScore[MAXPLAYERS+1];
int meTime[MAXPLAYERS+1][2];

Handle hTimer, hTimerLeft;
int m_iCompetitiveRanking,
	m_nPersonaDataPublicLevel;

float cTime, cTimeLeft; 	
int   cSort, cSortLeft, cType;
char cPrior[MaxRanks][16];		
bool cUpdateMode, cUpdateOpt;
 
ConVar 	cvar_Time,
		cvar_TimeLeft,
		cvar_Sort,
		cvar_SortLeft,
		cvar_UpdateMode,
		cvar_UpdateOpt,
		cvar_Type,
		cvar_Priority;

#include "fakerank_sync/api.sp"

public void OnPluginStart()
{
	LoadForwards();
	
	(cvar_Time = CreateConVar("sm_sync_time", "2.0", "RU: Время смены одной иконки на другую \n EN: Time for changing one icon to another", _, true, 0.1)).AddChangeHook(OnVarChanged);
	cTime = cvar_Time.FloatValue;

	(cvar_TimeLeft = CreateConVar("sm_sync_time_left", "2.0", "RU: Время смены одной иконки на другую с левой стороны\n EN: Time for changing one icon to another in left side", _, true, 0.1)).AddChangeHook(OnVarChanged);
	cTimeLeft = cvar_TimeLeft.FloatValue;

	(cvar_Sort  = CreateConVar("sm_sync_sort", "0", "RU: Тип сортировки: 0 - нету; 1 - по приоритетам \nEN: Type of sorting: 0 - no; 1 - by priority", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cSort = cvar_Sort.IntValue;

	(cvar_SortLeft  = CreateConVar("sm_sync_sort_left", "0", "RU: Тип сортировки для левой стороны: 0 - нету; 1 - по приоритетам \nEN: Type of sorting in left side: 0 - no; 1 - by priority", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cSortLeft = cvar_SortLeft.IntValue;

	(cvar_Type  = CreateConVar("sm_sync_type", "0", "RU: Тип отображения: 0 - отображать предыдущее при нулях; 1 - пропускать нули (покажет следущую иконку) \nEN: Display Type: 0 - display the previous one at zeros; 1 - skip zeros (will show the next icon)", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cType = cvar_Type.IntValue;

	(cvar_UpdateMode  = CreateConVar("sm_sync_update_mode", "0", "RU: Режим обновления когда смотришь в таб. 0 - \"плавно\"; 1 - резко) \n EN: Update mode when you look at tab. 0 - \"smoothly \"; 1 - sharply", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cUpdateMode = cvar_UpdateMode.BoolValue;

	(cvar_UpdateOpt  = CreateConVar("sm_sync_update_opt", "0", "RU: Как часто обновлять. 0 - всегда; 1 - только когда открыт таб \n EN: ", _, true, 0.0, true, 1.0)).AddChangeHook(OnVarChanged);
	cUpdateOpt = cvar_UpdateOpt.BoolValue;

	(cvar_Priority = CreateConVar("sm_sync_priority", "vip;shop", "RU: Приоритет отображения, чем первее в строке, тем выше приоритет \nEN: Display priority, the first in the line, the higher the priority")).AddChangeHook(OnVarChanged);
	ProcessCvarPriority(cvar_Priority);

	if((m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking")) < 1)
		SetFailState("Can't get offset 'm_iCompetitiveRanking'!");
		
	if((m_nPersonaDataPublicLevel = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel")) < 1)
		SetFailState("Can't get offset 'm_nPersonaDataPublicLevel'!");

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
	else if(cvar == cvar_UpdateOpt)	
		cUpdateOpt = cvar.BoolValue;

	else if(cvar == cvar_Sort)
	{
		cSort = cvar.IntValue;

		if(cSort)
		{
			ClearRegister();
			ReloadListToPriorityMode();
		}
	}
	else if(cvar == cvar_SortLeft)
		cSortLeft = cvar.IntValue;

	else if(cvar == cvar_Time)
		cTime = cvar.FloatValue;
	else if(cvar == cvar_TimeLeft)
		cTimeLeft = cvar.FloatValue;

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
	
	iCount[client][Right] = 0;
	iCount[client][Left] = 0;

	for(int poss = 0; poss < MaxRanks; poss++)
	{
		iRegisterValue[client][poss][Right] = 0;
		iRegisterValue[client][poss][Left] = 0;
	}

	if(cSort != 1)
	{
		for(int i = 1; i <= MaxClients; i++)	if(client != i && IsValidPlayer(i))
		{
			meTime[client][Right] = meTime[i][Right];
			meTime[client][Left] = meTime[i][Left];
			break;
		}
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

public Action OnPlayerRunCmd(int client, int &iButtons)
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
	if(cUpdateOpt)
	{
		bool update;

		for(int i = 1; i <= MaxClients; i++)	if(iIsScore[i])
			update = true;

		if(!update)
			return;
	}

	static int id, oldId[MAXPLAYERS+1][2];

	for(int i = 1; i <= MaxClients; i++)	
	{
		if(!IsValidPlayer(i))
			continue;

		if(!iCount[i][Right])
			SetEntData(iEnt, m_iCompetitiveRanking + i*4, 0);
		else
		{
			if((id = iRegisterValue[i][meTime[i][Right]][Right]) <= 0)
				id = oldId[i][Right];
				
			if(id)
				SetEntData(iEnt, m_iCompetitiveRanking + i*4, id);

			oldId[i][Right] = id;
		}


		if(!iCount[i][Left])
			SetEntData(iEnt, m_nPersonaDataPublicLevel + i*4, 0);
		else
		{
			if((id = iRegisterValue[i][meTime[i][Left]][Left]) <= 0)
				id = oldId[i][Left];

			if(id)
				SetEntData(iEnt, m_nPersonaDataPublicLevel + i*4, id);

			oldId[i][Left] = id;
		}

		if(cUpdateMode && iIsScore[i])
		{
			StartMessageOne("ServerRankRevealAll", i, USERMSG_BLOCKHOOKS);
			EndMessage();
		}
	}
} 

public Action Timer_GenerageId(Handle timer)
{
	static int cycle;
	if(cSort == 1)
	{
		for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
		{
			for(int poss = 0; poss < MaxRanks; poss++)	if(iRegisterValue[i][poss][Right]) 
			{
				meTime[i][Right] = poss;
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
			{
				meTime[i][Right] = cycle;
			}
	
			else if(cType == 1)
			{
				for(int poss = 0; poss < MaxRanks; poss++)
				{
					if(meTime[i][Right]++ >= MaxRanks-1)
						meTime[i][Right] = 0;

					if(!RegisterId[meTime[i][Right]])
						continue;
					
					if(iRegisterValue[i][meTime[i][Right]][Right])
						break;
				}
			}
		} 
	}
}

public Action Timer_GenerageIdLeft(Handle timer)
{
	static int cycle;
	if(cSortLeft == 1)
	{
		for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
		{
			for(int poss = 0; poss < MaxRanks; poss++)	if(iRegisterValue[i][poss][Left]) 
			{
				meTime[i][Left] = poss;
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
			{
				meTime[i][Left] = cycle;
			}
	
			else if(cType == 1)
			{
				for(int poss = 0; poss < MaxRanks; poss++)
				{
					if(meTime[i][Left]++ >= MaxRanks-1)
						meTime[i][Left] = 0;

					if(!RegisterId[meTime[i][Left]])
						continue;
					
					if(iRegisterValue[i][meTime[i][Left]][Left])
						break;
				}
			}
		} 
	}
}

stock void RestartTimer()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		meTime[i][Right] = 0;
		meTime[i][Left] = 0;
	}

	if(hTimer) delete hTimer;
	if(hTimerLeft) delete hTimerLeft;

	hTimer = CreateTimer(cTime, Timer_GenerageId, _, TIMER_REPEAT);	
	hTimerLeft = CreateTimer(cTimeLeft, Timer_GenerageIdLeft, _, TIMER_REPEAT);	
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

	char name[64], buff[256];

	if(kv.JumpToKey("ERRORS", true))
	{
		if(kv.JumpToKey("File not Exists", true))
		{
			for(int i = 1; i <= MaxClients; i++)	if(IsValidPlayer(i))
			{
				for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterKeys[poss][0] && RegisterId[poss])
				{
					Format(buff, sizeof(buff), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", iRegisterValue[i][poss][Right]);
					if(!(FileExists(buff) || FileExists(buff, true)))
					{
						ReplaceString(buff, sizeof(buff), "/", "\\");
						if(!kv.JumpToKey(buff, false))
						{
							kv.SetNum(buff, 0);
							kv.GoBack();
						}
					}		

					Format(buff, sizeof(buff), "materials/panorama/images/icons/xp/level%i.png", iRegisterValue[i][poss][Left]);
					if(!(FileExists(buff) || FileExists(buff, true)))	
					{
						ReplaceString(buff, sizeof(buff), "/", "\\");
						if(!kv.JumpToKey(buff, false))
						{
							kv.SetNum(buff, 0);
							kv.GoBack();
						}
					}
					
				}
			}
		}

	}

	kv.Rewind();
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
			if(kv.JumpToKey("Right Side", true))
			{
				kv.SetNum("MY RANK ALL COUNT", iCount[i][Right]);

				for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterKeys[poss][0] && RegisterId[poss])
					kv.SetNum(RegisterKeys[poss], iRegisterValue[i][poss][Right]);
				kv.GoBack();
			}
			if(kv.JumpToKey("Left Side", true))
			{
				kv.SetNum("MY RANK ALL COUNT", iCount[i][Left]);

				for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterKeys[poss][0] && RegisterId[poss])
					kv.SetNum(RegisterKeys[poss], iRegisterValue[i][poss][Left]);
				kv.GoBack();
				kv.GoBack();
			}
		}
		kv.GoBack();
	}

	kv.Rewind();
	kv.ExportToFile("addons/sourcemod/logs/fakerank_snapshot.txt");
	
	delete kv;
}

stock bool IsValidPlayer(int client)
{
	return IsClientAuthorized(client) && IsClientInGame(client) && client;
}
