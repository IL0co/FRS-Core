GlobalForward 	forward_OnClientLoaded,
				forward_OnCoreLoaded;

public void OnAllPluginsLoaded()
{
	Call_StartForward(forward_OnCoreLoaded);
	Call_Finish();
}
public void LoadForwards()
{
	forward_OnClientLoaded = new GlobalForward("FRS_OnClientLoaded", ET_Ignore, Param_Cell);
	forward_OnCoreLoaded = new GlobalForward("FRS_OnCoreLoaded", ET_Ignore);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	

	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(error, err_max, "This plugin works only on CS:GO");
		return APLRes_SilentFailure;
	}

	CreateNative("FRS_RemoveKey", Native_RemoveKey);
	CreateNative("FRS_RegisterKey", Native_RegisterKey);
	CreateNative("FRS_UnRegisterMe", Native_UnRegisterMe);
	CreateNative("FRS_SetClientRankId", Native_SetClientRankId);

	RegPluginLibrary("FRS");
	return APLRes_Success;
}

int Native_RemoveKey(Handle plugin, int numParams)
{
	char key[16]; 
	GetNativeString(1, key, sizeof(key));

	for(int poss = 0; poss < MaxRanks; poss++)	if(strcmp(key, RegisterKeys[poss], false) == 0)
	{
		RegisterKeys[poss][0] = '\0';
		RegisterId[poss] = 0;
		
		for(int i = 1; i <= MaxClients; i++) 	if(IsValidPlayer(i))
		{
			iRegisterValue[i][poss] = 0;
			GetMyCount(i);
		}
		

		return true;
	}
	
	return false;
}

int Native_RegisterKey(Handle plugin, int numParams)
{
	char key[16]; 
	GetNativeString(1, key, sizeof(key));

	for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterKeys[poss][0] && strcmp(key, RegisterKeys[poss], false) == 0)
	{
		Format(RegisterKeys[poss], sizeof(RegisterKeys[]), key);
		RegisterId[poss] = view_as<int>(plugin);

		return true;
	}

	for(int poss = 0; poss < MaxRanks; poss++)	if(!RegisterKeys[poss][0])
	{
		Format(RegisterKeys[poss], sizeof(RegisterKeys[]), key);
		RegisterId[poss] = view_as<int>(plugin);

		return true;
	}

	return false;
}

int Native_UnRegisterMe(Handle plugin, int numParams)
{
	for(int poss = 0; poss < MaxRanks; poss++)	if(RegisterId[poss] == view_as<int>(plugin))
	{
		RegisterKeys[poss][0] = '\0';
		RegisterId[poss] = 0;
	}

	for(int i = 1; i <= MaxClients; i++) if(IsValidPlayer(i))
	{
		for(int poss = 0; poss < MaxRanks; poss++)	if(!RegisterKeys[poss][0])
			iRegisterValue[i][poss] = 0;
		
		GetMyCount(i);
	}
}
	
int Native_SetClientRankId(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int RankId = GetNativeCell(2);

	char key[16];
	GetNativeString(3, key, sizeof(key));

	for(int poss = 0; poss < MaxRanks; poss++)	if(strcmp(key, RegisterKeys[poss], false) == 0)
		iRegisterValue[client][poss] = RankId;

	GetMyCount(client);
}

stock void GetMyCount(int client)
{
	iCount[client] = 0;
	for(int poss = 0; poss < MaxRanks; poss++)	if(iRegisterValue[client][poss])
		iCount[client]++;
}