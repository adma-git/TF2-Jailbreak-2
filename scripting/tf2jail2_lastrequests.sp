//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

#define LR_CALLBACK_CHOSEN 0
#define LR_CALLBACK_ROUNDSTART 1
#define LR_CALLBACK_ROUNDACTIVE 2
#define LR_CALLBACK_ROUNDEND 3

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2jail2/tf2jail2_lastrequests>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#include <tf2jail2/tf2jail2_maptriggers>
#include <tf2jail2/tf2jail2_warden>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_RegiveLR;
ConVar convar_DisplayLR;

//Forwards
Handle g_hForward_LRRegistrations;

//Globals
bool g_bLate;
UserMsg g_FadeUserMsgId;

ArrayList g_hLastRequests_List;
StringMap g_hLastRequests_Disabled;
StringMap g_hLastRequests_NextRound;
StringMap g_hLastRequests_GrantLR;
StringMap g_hLastRequests_Events;

StringMap g_hTrie_LRCalls;

char g_sPrevLRName[MAX_NAME_LENGTH];
char g_sCurrentLRName[MAX_NAME_LENGTH];
char g_sNextLRName[MAX_NAME_LENGTH];
char g_sCustomLR[32];

int g_iClientLR;
int g_iPrevClientLR;
bool g_bLRNextRound;
bool g_bGrantLR;
bool g_bGrantedLR;
Handle g_hHud_LastRequest;

int g_iCustomLR;

bool bHasFreeday[MAXPLAYERS + 1];
bool bShouldGiveFreeday[MAXPLAYERS + 1];
int iChosen;

bool g_bActiveRound;
bool g_bNewMap;

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Last Requests",
	author = "Keith Warren (Sky Guardian)",
	description = "Handles all last requests for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_lastrequests");

	CreateNative("TF2Jail2_RegisterLR", Native_RegisterLR);
	CreateNative("TF2Jail2_ExecuteLR", Native_ExecuteLR);
	CreateNative("TF2Jail2_GiveLR", Native_GiveLR);
	CreateNative("TF2Jail2_GrantedLR", Native_GrantedLR);
	CreateNative("TF2Jail2_IsFreeday", Native_IsFreeday);
	CreateNative("TF2Jail2_IsPendingFreeday", Native_IsPendingFreeday);
	CreateNative("TF2Jail2_GetCurrentLR", Native_GetCurrentLR);
	CreateNative("TF2Jail2_GetNextLR", Native_GetNextLR);

	g_hForward_LRRegistrations = CreateGlobalForward("TF2Jail2_OnlastRequestRegistrations", ET_Ignore);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_lastrequests_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_RegiveLR = CreateConVar("sm_tf2jail2_regive_lr", "1", "Allow last request to be given when a next round last request is active.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_DisplayLR = CreateConVar("sm_tf2jail2_display_lr", "1", "Show the last request at the bottom.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_lr", Command_GiveLastRequest, "Give a prisoner a last request as Warden or Admin.");
	RegConsoleCmd("sm_glr", Command_GiveLastRequest, "Give a prisoner a last request as Warden or Admin.");
	RegConsoleCmd("sm_givelr", Command_GiveLastRequest, "Give a prisoner a last request as Warden or Admin.");
	RegConsoleCmd("sm_givelastrequest", Command_GiveLastRequest, "Give a prisoner a last request as Warden or Admin.");

	RegConsoleCmd("sm_llrs", Command_ListLastRequests, "List all last requests available on the server.");
	RegConsoleCmd("sm_listlrs", Command_ListLastRequests, "List all last requests available on the server.");
	RegConsoleCmd("sm_listlastrequests", Command_ListLastRequests, "List all last requests available on the server.");

	RegConsoleCmd("sm_culr", Command_CurrentLastRequest, "Displays the current last request that's active.");
	RegConsoleCmd("sm_currentlr", Command_CurrentLastRequest, "Displays the current last request that's active.");
	RegConsoleCmd("sm_currentlastrequest", Command_CurrentLastRequest, "Displays the current last request that's active.");

	RegAdminCmd("sm_cllr", Command_ClearLastRequest, ADMFLAG_SLAY, "Clears the currently active last request.");
	RegAdminCmd("sm_clearlr", Command_ClearLastRequest, ADMFLAG_SLAY, "Clears the currently active last request.");
	RegAdminCmd("sm_clearlastrequest", Command_ClearLastRequest, ADMFLAG_SLAY, "Clears the currently active last request.");

	RegAdminCmd("sm_forcelr", Command_ForceLastRequest, ADMFLAG_SLAY, "Force a last request to execute and automatically cancel the current one if it exists.");
	RegAdminCmd("sm_reloadlrs", Command_RegisterLRs, ADMFLAG_SLAY, "Re-Register all last requests.");

	RegAdminCmd("sm_givefreeday", Command_GiveFreeday, ADMFLAG_SLAY, "Give a player a freeday the current round.");
	RegAdminCmd("sm_givefreedaynextround", Command_GiveFreedayNextRound, ADMFLAG_SLAY, "Give a player a freeday the current round next round.");

	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("arena_round_start", Event_OnRoundActive);
	HookEvent("teamplay_round_active", Event_OnRoundActive);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_hurt", Event_OnPlayerHurt);

	g_hLastRequests_List = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
	g_hLastRequests_Disabled = CreateTrie();
	g_hLastRequests_NextRound = CreateTrie();
	g_hLastRequests_Events = CreateTrie();
	g_hLastRequests_GrantLR = CreateTrie();

	g_hTrie_LRCalls = CreateTrie();

	g_FadeUserMsgId = GetUserMessageId("Fade");
	g_hHud_LastRequest = CreateHudSynchronizer();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage); // Godmode for freedays && lr receiver
}

public void OnMapEnd()
{
	g_iPrevClientLR = 0;
	ClearLastRequest(-1, false);
}

public void OnMapStart()
{
	g_bNewMap = true;

	PrecacheSound("coach/coach_attack_here.wav");
}

public void OnConfigsExecuted()
{
	ParseLastRequests();

	if (g_bLate)
	{
		g_bNewMap = false;

		g_bLate = false;
	}
}

public void OnAllPluginsLoaded()
{
	ReloadLastRequests();
}

public void OnPluginEnd()
{
	ClearLastRequest(-1, false);
}

public void OnClientDisconnect(int client)
{
	bHasFreeday[client] = false;
	bShouldGiveFreeday[client] = false;

	if (g_bLRNextRound && GetClientUserId(client) == g_iClientLR)
	{
		CPrintToChatAll("%s {mediumslateblue}%N {default}has disconnected during their last request.", g_sGlobalTag, client);
		ClearLastRequest(-1, false);
	}

	if (g_iCustomLR)
	{
		CPrintToChatAll("%s {mediumslateblue}%N {default}has disconnected while typing their custom last request.", g_sGlobalTag, client);
		ClearLastRequest(-1, false);
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (GetClientUserId(client) == g_iClientLR && g_iCustomLR)
	{
		PrintCenterTextAll(sArgs);
		CPrintToChatAll("%s {mediumslateblue}%N's {default}custom last request is: %s", g_sGlobalTag, client, sArgs);
		strcopy(g_sCustomLR, sizeof(g_sCustomLR), sArgs);
		AttachParticle(client, "merasmus_dazed_bits", 2.0);

		ClearLastRequest(-1, false);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

//////////////////////////////////////////////////
//TF2Jail Forwards

public void TF2Jail2_OnWardenPhaseEnd_Post(int warden)
{
	if (warden == NO_WARDEN && strlen(g_sCurrentLRName) == 0 && strlen(g_sNextLRName) == 0 && g_bActiveRound)
	{
		ExecuteLastRequest(0, "Freeday For All No Warden");
	}
}

//////////////////////////////////////////////////
//Commands

public Action Command_GiveLastRequest(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowGiveLastRequestMenu(client, CheckCommandAccess(client, "tf2jail2_override_givelrmenu", ADMFLAG_SLAY));
	return Plugin_Handled;
}

public Action Command_ListLastRequests(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	Menu menu = CreateMenu(MenuHandler_ListLRs);
	SetMenuTitle(menu, "Last Requests List:");

	for (int i = 0; i < GetArraySize(g_hLastRequests_List); i++)
	{
		char sName[MAX_NAME_LENGTH];
		GetArrayString(g_hLastRequests_List, i, sName, sizeof(sName));

		bool disabled;
		GetTrieValue(g_hLastRequests_Disabled, sName, disabled);

		AddMenuItem(menu, "", sName, disabled ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No LRs Available]", ITEMDRAW_DISABLED);
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Action Command_CurrentLastRequest(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	if (strlen(g_sCurrentLRName) > 0)
	{
		CPrintToChat(client, "%s Current last request is: %s", g_sGlobalTag, g_sCurrentLRName);
	}
	else
	{
		CPrintToChat(client, "%s No last request is currently active.", g_sGlobalTag);
	}

	return Plugin_Handled;
}

public Action Command_ClearLastRequest(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ClearLastRequest(client, true);
	return Plugin_Handled;
}

public Action Command_ForceLastRequest(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowLastRequestMenu(client, client, true);
	return Plugin_Handled;
}

public Action Command_RegisterLRs(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ReloadLastRequests(client);
	return Plugin_Handled;
}

public Action Command_GiveFreeday(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArgString(sTarget, sizeof(sTarget));

	int target = FindTarget(client, sTarget, true, false);

	if (target == -1)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}Target is invalid, please try again.", g_sGlobalTag);
		return Plugin_Handled;
	}

	MakeClientFreeday(target, client, true);
	return Plugin_Handled;
}

public Action Command_GiveFreedayNextRound(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArgString(sTarget, sizeof(sTarget));

	int target = FindTarget(client, sTarget, true, false);

	if (target == -1)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}Target is invalid, please try again.", g_sGlobalTag);
		return Plugin_Handled;
	}

	bShouldGiveFreeday[client] = true;
	CPrintToChatAll("%s {mediumslateblue}%N {default}has given {mediumslateblue}%N {default}a freeday next round!", g_sGlobalTag, client, target);
	return Plugin_Handled;
}

//////////////////////////////////////////////////
//Events

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (g_bNewMap)
	{
		g_bNewMap = false;

		ExecuteLastRequest(0, "Freeday For All First Day");
	}
	
	if (strlen(g_sNextLRName) > 0)
		strcopy(g_sCurrentLRName, MAX_NAME_LENGTH, g_sNextLRName);
		
	strcopy(g_sPrevLRName, MAX_NAME_LENGTH, g_sCurrentLRName);
	
	g_sNextLRName[0] = '\0';
	ExecuteLRCallback(g_iClientLR, g_sCurrentLRName, LR_CALLBACK_ROUNDSTART);
	
	g_iPrevClientLR = g_iClientLR;
	g_iClientLR = 0;
	g_bGrantedLR = false;
	g_bLRNextRound = false;
	
	if (GetConVarBool(convar_DisplayLR))
	{
		SetHudTextParams(0.4, 0.95, 99999.0, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowSyncHudText(i, g_hHud_LastRequest, "Last request: %s", strlen(g_sCustomLR) > 0 ? g_sCustomLR : g_sCurrentLRName);
			}
		}
	}
}

public void Event_OnRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	ExecuteLRCallback(g_iClientLR, g_sCurrentLRName, LR_CALLBACK_ROUNDACTIVE);

	g_sCustomLR[0] = '\0';
	g_bActiveRound = true;
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}
	
	if (strlen(g_sPrevLRName) > 0 && g_bGrantedLR)
		ExecuteLRCallback(g_iPrevClientLR, g_sPrevLRName, LR_CALLBACK_ROUNDEND);
		
	ExecuteLRCallback(g_iClientLR, g_sCurrentLRName, LR_CALLBACK_ROUNDEND);
	ClearLastRequest(-1, false, true);

	g_bActiveRound = false;
}

//////////////////////////////////////////////////
//Stocks

void ReloadLastRequests(int admin = -1)
{
	ClearLastRequest(admin);

	Call_StartForward(g_hForward_LRRegistrations);
	Call_Finish();
}

void ShowGiveLastRequestMenu(int client, bool admin = false)
{
	if (!admin && TF2Jail2_GetWarden() != client)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You are currently not the Warden.", g_sGlobalTag);
		return;
	}
	
	if (strlen(g_sCurrentLRName) > 0)
	{
		if (!GetConVarBool(convar_RegiveLR))
		{
			CPrintToChat(client, "%s {red}ERROR: {default}Last request is currently active already.", g_sGlobalTag); 
			return;
		}
		
		if (!g_bGrantLR)
		{
			CPrintToChat(client, "%s {red}ERROR: {default}Cannot regive last request during %s", g_sGlobalTag, g_sCurrentLRName); 
			return;
		}
			
		if (g_bGrantedLR)
		{
			CPrintToChat(client, "%s {red}ERROR: {default}Last request has already been granted. Type /cllr to clear the last request.", g_sGlobalTag); 
			return;
		}	
	}

	Handle menu = CreateMenu(MenuHandler_GiveLastRequestMenu);
	SetMenuTitle(menu, "TF2Jail 2 - Give A Last Request\n \n");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Red)
		{
			char sName[MAX_NAME_LENGTH];
			GetClientName(i, sName, sizeof(sName));

			char sUserid[64];
			IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));

			AddMenuItem(menu, sUserid, sName);
		}
	}

	PushMenuCell(menu, "admin", admin);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

void ShowLastRequestMenu(int client, int given = -1, bool admin = false)
{
	Handle menu = CreateMenu(MenuHandler_LastRequestMenu);
	SetMenuTitle(menu, "TF2Jail 2 - Last Requests\n \n"); 
	

	AddMenuItem(menu, "", "Random Last Request");
	AddMenuItem(menu, "", "Custom Last Request");
	
	for (int i = 0; i < GetArraySize(g_hLastRequests_List); i++)
	{
		char sName[MAX_NAME_LENGTH];
		GetArrayString(g_hLastRequests_List, i, sName, sizeof(sName));

		bool disabled;
		GetTrieValue(g_hLastRequests_Disabled, sName, disabled);

		AddMenuItem(menu, "", sName, disabled ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No LRs Available]", ITEMDRAW_DISABLED);
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);

	if (given != -1)
	{
		CPrintToChatAll("%s {mediumslateblue}%N {default}has given a last request to {mediumslateblue}%N. %s", g_sGlobalTag, given, client, admin ? "(admin)" : "");
	}
	else
	{
		CPrintToChatAll("%s {mediumslateblue}%N {default}has received a last request. %s", g_sGlobalTag, client, admin ? "(admin)" : "");
	}
	
	g_bGrantedLR = true;
}

bool ExecuteLastRequest(int client, const char[] name, bool next_round = true)
{
	if (client > 0)
	{
		g_iClientLR = GetClientUserId(client);
		AttachParticle(client, "merasmus_dazed_bits", 2.0);
		EmitSoundToAll("sound/coach/coach_attack_here.wav", client);
		CPrintToChatAll("%s {mediumslateblue}%N {default}has executed the last request%s: {mediumslateblue}%s", g_sGlobalTag, client, next_round ? " next round" : "", name);
	}
	else
	{
		EmitSoundToAll("sound/coach/coach_attack_here.wav");
		CPrintToChatAll("%s Console has executed the last request%s: {mediumslateblue}%s", g_sGlobalTag, next_round ? " next round" : "", name);
	}

	GetTrieValue(g_hLastRequests_GrantLR, name, g_bGrantLR);
	GetTrieValue(g_hLastRequests_NextRound, name, g_bLRNextRound);
	strcopy(g_bLRNextRound ? g_sNextLRName : g_sCurrentLRName, MAX_NAME_LENGTH, name);

	if (GetConVarBool(convar_DisplayLR))
	{
		SetHudTextParams(0.4, 0.95, 99999.0, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowSyncHudText(i, g_hHud_LastRequest, "%N selected: %s", client, g_bLRNextRound ? g_sNextLRName : g_sCurrentLRName);
			}
		}
	}

	ExecuteLRCallback(g_iClientLR, g_bLRNextRound ? g_sNextLRName : g_sCurrentLRName, LR_CALLBACK_CHOSEN);

	return true;
}

void ClearLastRequest(int admin = -1, bool announce = true, bool roundreset = false)
{
	if (!roundreset)
	{
		g_iClientLR = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				ClearSyncHud(i, g_hHud_LastRequest);
				RemoveClientFreeday(i, admin);
				bShouldGiveFreeday[i] = false;
			}
		}
	}
	
	g_sCurrentLRName[0] = '\0';	
	g_bLRNextRound = false;
	g_iCustomLR = 0;

	iChosen = 0;

	if (announce)
	{
		char sAdmin[128];

		if (admin != -1)
		{
			FormatEx(sAdmin, sizeof(sAdmin), " by {mediumslateblue}%N{default}", admin);
		}

		CPrintToChatAll("%s The current last request has been cleared%s.", g_sGlobalTag, sAdmin);
	}
}

void ParseLastRequests()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/tf2jail2/lastrequests.cfg");

	KeyValues kv = CreateKeyValues("lastrequests");

	if (FileToKeyValues(kv, sPath) && KvGotoFirstSubKey(kv))
	{
		ClearArray(g_hLastRequests_List);
		ClearTrie(g_hLastRequests_Disabled);
		ClearTrie(g_hLastRequests_NextRound);
		ClearTrie(g_hLastRequests_GrantLR);
		ClearTrieCustom(g_hLastRequests_Events);

		do
		{
			char sName[MAX_NAME_LENGTH];
			KvGetSectionName(kv, sName, sizeof(sName));

			PushArrayString(g_hLastRequests_List, sName);

			bool disabled = KvGetBool(kv, "disabled", false);
			SetTrieValue(g_hLastRequests_Disabled, sName, disabled);

			bool next_round = KvGetBool(kv, "next_round", true);
			SetTrieValue(g_hLastRequests_NextRound, sName, next_round);
			
			bool grant_lr = KvGetBool(kv, "grant_lr", true);
			SetTrieValue(g_hLastRequests_GrantLR, sName, grant_lr);

			if (KvJumpToKey(kv, "events") && KvGotoFirstSubKey(kv))
			{
				StringMap events = CreateTrie();

				do
				{
					char sEvent[MAX_NAME_LENGTH];
					KvGetSectionName(kv, sEvent, sizeof(sEvent));

					if (KvGotoFirstSubKey(kv, false))
					{
						StringMap actions = CreateTrie();

						do
						{
							char sAction[MAX_NAME_LENGTH];
							KvGetSectionName(kv, sAction, sizeof(sAction));

							char sValue[32];
							KvGetString(kv, NULL_STRING, sValue, sizeof(sValue));

							SetTrieString(actions, sAction, sValue);
						}
						while (KvGotoNextKey(kv, false));

						SetTrieValue(events, sEvent, actions);

						KvGoBack(kv);
					}
				}
				while (KvGotoNextKey(kv));

				SetTrieValue(g_hLastRequests_Events, sName, events);

				KvGoBack(kv);
				KvGoBack(kv);
			}
		}
		while(KvGotoNextKey(kv));
	}

	CloseHandle(kv);
	LogMessage("%i last requests loaded.", GetArraySize(g_hLastRequests_List));
}

void ClearTrieCustom(StringMap& lastrequest)
{
	Handle lastrequest_snapshot = CreateTrieSnapshot(lastrequest);

	for (int i = 0; i < TrieSnapshotLength(lastrequest_snapshot); i++)
	{
		int size = TrieSnapshotKeyBufferSize(lastrequest_snapshot, i);

		char[] sKey = new char[size];
		GetTrieSnapshotKey(lastrequest_snapshot, i, sKey, size);

		Handle events;
		if (GetTrieValue(lastrequest, sKey, events) && events != null)
		{
			Handle actions_snapshot = CreateTrieSnapshot(events);

			for (int x = 0; x < TrieSnapshotLength(actions_snapshot); x++)
			{
				int size2 = TrieSnapshotKeyBufferSize(actions_snapshot, x);

				char[] sKey2 = new char[size2];
				GetTrieSnapshotKey(actions_snapshot, x, sKey2, size2);

				Handle actions;
				if (GetTrieValue(events, sKey2, actions) && actions != null)
				{
					CloseHandle(actions);
				}
			}

			CloseHandle(events);
		}
	}

	ClearTrie(lastrequest);
}

void RegisterLR(Handle plugin, const char[] name, TF2Jail2_Func_OnLRChosen onlrchosen = INVALID_FUNCTION, TF2Jail2_Func_OnLRRoundStart onlrroundstart = INVALID_FUNCTION, TF2Jail2_Func_OnLRRoundActive onlrroundactive = INVALID_FUNCTION, TF2Jail2_Func_OnLRRoundEnd onlrroundend = INVALID_FUNCTION)
{
	Handle callbacks[4];

	if (onlrchosen != INVALID_FUNCTION)
	{
		callbacks[LR_CALLBACK_CHOSEN] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(callbacks[LR_CALLBACK_CHOSEN], plugin, onlrchosen);
	}

	if (onlrroundstart != INVALID_FUNCTION)
	{
		callbacks[LR_CALLBACK_ROUNDSTART] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(callbacks[LR_CALLBACK_ROUNDSTART], plugin, onlrroundstart);
	}

	if (onlrroundactive != INVALID_FUNCTION)
	{
		callbacks[LR_CALLBACK_ROUNDACTIVE] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(callbacks[LR_CALLBACK_ROUNDACTIVE], plugin, onlrroundactive);
	}

	if (onlrroundend != INVALID_FUNCTION)
	{
		callbacks[LR_CALLBACK_ROUNDEND] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(callbacks[LR_CALLBACK_ROUNDEND], plugin, onlrroundend);
	}

	SetTrieArray(g_hTrie_LRCalls, name, callbacks, sizeof(callbacks));
}

void ExecuteLRCallback(int clientuid, const char[] name, int callback)
{
	StringMap events;
	GetTrieValue(g_hLastRequests_Events, name, events);
	int client = GetClientOfUserId(clientuid);

	if (events != null)
	{
		StringMap actions;

		switch(callback)
		{
			case LR_CALLBACK_CHOSEN:
			{
				GetTrieValue(events, "lr_chosen", actions);
			}

			case LR_CALLBACK_ROUNDSTART:
			{
				GetTrieValue(events, "round_start", actions);
			}

			case LR_CALLBACK_ROUNDACTIVE:
			{
				GetTrieValue(events, "round_active", actions);
			}

			case LR_CALLBACK_ROUNDEND:
			{
				GetTrieValue(events, "round_end", actions);
			}
		}

		if (actions != null)
		{
			char sValue[64];

			if (GetTrieString(actions, "open_cells", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bOpenCells = view_as<bool>(StringToInt(sValue));

				switch (bOpenCells)
				{
					case true: TF2Jail2_OpenCells(client, true, true);
					case false: TF2Jail2_CloseCells(client, true, true);
				}
			}

			if (GetTrieString(actions, "lock_cells", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bLockCells = view_as<bool>(StringToInt(sValue));

				switch (bLockCells)
				{
					case true: TF2Jail2_LockCells(client, true);
					case false: TF2Jail2_UnlockCells(client, true);
				}
			}

			if (GetTrieString(actions, "lock_warden", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bLockWarden = view_as<bool>(StringToInt(sValue));
				TF2Jail2_LockWarden(bLockWarden);
			}

			if (GetTrieString(actions, "no_warden_phase", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bNoWardenPhase = view_as<bool>(StringToInt(sValue));

				if (bNoWardenPhase)
				{
					TF2Jail2_NoWardenPhase();
				}
			}

			if (GetTrieString(actions, "medic_disabled", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bMedicsDisabled = view_as<bool>(StringToInt(sValue));
				TF2Jail2_ToggleMedicStations(bMedicsDisabled);
			}

			if (GetTrieString(actions, "healthpacks_disabled", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bHealthPacksDisabled = view_as<bool>(StringToInt(sValue));
				TF2Jail2_ToggleHealthKits(bHealthPacksDisabled);
			}

			if (GetTrieString(actions, "ammopacks_disabled", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bAmmoPacksDisabled = view_as<bool>(StringToInt(sValue));
				TF2Jail2_ToggleAmmoPacks(bAmmoPacksDisabled);
			}

			if (GetTrieString(actions, "friendly_fire", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bFriendlyFire = view_as<bool>(StringToInt(sValue));
				SetConVarBool(FindConVar("mp_friendlyfire"), bFriendlyFire);
			}

			if (GetTrieString(actions, "godmode", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bGodmode = view_as<bool>(StringToInt(sValue));

				if (bGodmode)
				{
					ServerCommand("sm_godmode @all 1");
				}
				else
				{
					ServerCommand("sm_godmode @all 0");
				}
			}

			if (GetTrieString(actions, "mirrormode", sValue, sizeof(sValue)) && strlen(sValue) > 0)
			{
				bool bMirrorMode = view_as<bool>(StringToInt(sValue));

				if (bMirrorMode)
				{
					ServerCommand("sm_mirrormode @all 1");
				}
				else
				{
					ServerCommand("sm_mirrormode @all 0");
				}
			}
		}
	}

	Handle callbacks[4];
	if (!GetTrieArray(g_hTrie_LRCalls, name, callbacks, sizeof(callbacks)))
	{
		return;
	}

	if (callbacks[callback] != null && GetForwardFunctionCount(callbacks[callback]) > 0)
	{
		Call_StartForward(callbacks[callback]);
		Call_PushCell(GetClientOfUserId(clientuid));
		Call_Finish();
	}
}

//////////////////////////////////////////////////
//MenuHandlers

public int MenuHandler_GiveLastRequestMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sUserid[64]; char sName[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sUserid, sizeof(sUserid), _, sName, sizeof(sName));

			bool admin = view_as<bool>(GetMenuCell(menu, "admin"));

			if (!admin && TF2Jail2_GetWarden() != param1)
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}You are currently not the Warden.", g_sGlobalTag);
				return;
			}

			int userid = StringToInt(sUserid);
			int target = GetClientOfUserId(userid);

			if (target == 0)
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}Target not found, please try again.", g_sGlobalTag);
				return;
			}

			g_iClientLR = GetClientUserId(param1);
			g_bGrantedLR = true;
			ShowLastRequestMenu(target, param1);
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public int MenuHandler_ListLRs(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{

		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public int MenuHandler_LastRequestMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_bGrantedLR = true;
			char sInfo[32]; char sDisplay[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			if (StrEqual(sDisplay, "Random Last Request"))
			{
				int style = ITEMDRAW_DISABLED;
				while (style == ITEMDRAW_DISABLED && StrEqual(sDisplay, "Random Last Request"))
				{
					int random = GetRandomInt(2, GetMenuItemCount(menu) - 1);					
					GetMenuItem(menu, random, sInfo, sizeof(sInfo), style, sDisplay, sizeof(sDisplay));
				}
			}

			ExecuteLastRequest(param1, sDisplay);
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

//////////////////////////////////////////////////
//Natives

public int Native_RegisterLR(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sName = new char[size + 1];
	GetNativeString(1, sName, size + 1);

	RegisterLR(plugin, sName, view_as<TF2Jail2_Func_OnLRChosen>(GetNativeFunction(2)), view_as<TF2Jail2_Func_OnLRRoundStart>(GetNativeFunction(3)), view_as<TF2Jail2_Func_OnLRRoundActive>(GetNativeFunction(4)), view_as<TF2Jail2_Func_OnLRRoundEnd>(GetNativeFunction(5)));
}

public int Native_ExecuteLR(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(2, size);

	char[] sName = new char[size + 1];
	GetNativeString(2, sName, size + 1);

	ExecuteLastRequest(GetNativeCell(1), sName);
}

public int Native_GiveLR(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	ShowGiveLastRequestMenu(client);
}

public int Native_GrantedLR(Handle plugin, int numParams)
{
	return view_as<bool>(g_bGrantedLR);
}

public int Native_IsFreeday(Handle plugin, int numParams)
{
	return bHasFreeday[GetNativeCell(1)];
}

public int Native_IsPendingFreeday(Handle plugin, int numParams)
{
	return bShouldGiveFreeday[GetNativeCell(1)];
}

public int Native_GetCurrentLR(Handle plugin, int numParams)
{
	SetNativeString(1, g_sCurrentLRName, GetNativeCell(2));
}

public int Native_GetNextLR(Handle plugin, int numParams)
{
	SetNativeString(1, g_sNextLRName, GetNativeCell(2));
}

//////////////////////////////////////////////////
//Last Requests API

public void TF2Jail2_OnlastRequestRegistrations()
{
	TF2Jail2_RegisterLR("Custom Last Request", Custom_OnLRChosen, _, _, _);
	TF2Jail2_RegisterLR("Freeday For All First Day", _, _, FreedayForAllFirstDay_OnLRRoundActive, FreedayForAllFirstDay_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Freeday For All No Warden", FreedayForAllNoWarden_OnLRChosen, _, _, FreedayForAllNoWarden_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Freeday For All", _, _, FreedayForAll_OnLRRoundActive, FreedayForAll_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Freeday For Some", FreedayForSome_OnLRChosen, FreedayForSome_OnLRRoundStart, _, FreedayForSome_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Freeday For Yourself", FreedayForYourself_OnLRChosen, FreedayForYourself_OnLRRoundStart, _, FreedayForYourself_OnLRRoundEnd);
}

//////////////////////////////////////////////////
//Custom Last Request

public void Custom_OnLRChosen(int chooser)
{
	g_iCustomLR = chooser;
	CPrintToChat(chooser, "%s Please type into chat your last request:", g_sGlobalTag);
}

//////////////////////////////////////////////////
//Freeday For All First Day

public void FreedayForAllFirstDay_OnLRRoundActive(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			PerformBlind(i, 255);
			MakeClientFreeday(i, chooser, true);

			TF2_AddCondition(i, TFCond_HalloweenKartNoTurn, 2.5, i);
		}
	}

	PrintCenterTextAll("Freeday for all is active! (First day freeday)");
	CreateTimer(2.5, Timer_DeFade, _, TIMER_FLAG_NO_MAPCHANGE);
	
	TF2Jail2_LockWarden(true);
}

public void FreedayForAllFirstDay_OnLRRoundEnd(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RemoveClientFreeday(i);
		}
	}
}

//////////////////////////////////////////////////
//Freeday For All No Warden

public void FreedayForAllNoWarden_OnLRChosen(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			PerformBlind(i, 255);
			TF2_RespawnPlayer(i);
			MakeClientFreeday(i, chooser);

			TF2_AddCondition(i, TFCond_HalloweenKartNoTurn, 2.5, i);
		}
	}

	PrintCenterTextAll("Freeday for all is active! (No warden)");
	CreateTimer(2.5, Timer_DeFade, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void FreedayForAllNoWarden_OnLRRoundEnd(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RemoveClientFreeday(i);
		}
	}

	TF2Jail2_UnlockCells(chooser);
	TF2Jail2_LockWarden(false);
}

//////////////////////////////////////////////////
//Freeday For All

public void FreedayForAll_OnLRRoundActive(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			PerformBlind(i, 255);
			MakeClientFreeday(i, chooser, true);
		}
	}

	PrintCenterTextAll("Freeday for all is active!");
	CreateTimer(5.0, Timer_DeFade, _, TIMER_FLAG_NO_MAPCHANGE);

	CPrintToChatAll("%s {mediumslateblue}%N {default}has chosen a freeday for all this round.", g_sGlobalTag, chooser);
	
	TF2Jail2_LockWarden(true);
}

public void FreedayForAll_OnLRRoundEnd(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RemoveClientFreeday(i, -1, true);
		}
	}
}

//////////////////////////////////////////////////
//Freeday For Some

public void FreedayForSome_OnLRChosen(int chooser)
{
	iChosen = GetMaximumFreedays();
	bShouldGiveFreeday[chooser] = true;
	ShowFreedayForSomeMenu(chooser);
}

public void FreedayForSome_OnLRRoundStart(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && bShouldGiveFreeday[i])
		{
			MakeClientFreeday(i, chooser, true);
		}
	}
}

public void FreedayForSome_OnLRRoundEnd(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RemoveClientFreeday(i, -1, false);
		}
	}
}

//////////////////////////////////////////////////
//Freeday For Yourself

public void FreedayForYourself_OnLRChosen(int chooser)
{
	bShouldGiveFreeday[chooser] = true;
}

public void FreedayForYourself_OnLRRoundStart(int chooser)
{
	if (IsClientInGame(chooser) && bShouldGiveFreeday[chooser])
	{
		MakeClientFreeday(chooser, chooser, false);
	}
}

public void FreedayForYourself_OnLRRoundEnd(int chooser)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RemoveClientFreeday(i, -1, false);
		}
	}
}

//Everything Else

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	RemoveClientFreeday(client, -1, true);
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int userid_attacker = GetEventInt(event, "attacker");

	int client = GetClientOfUserId(userid);
	int attacker = GetClientOfUserId(userid_attacker);

	if (!GetConVarBool(convar_Status) || !IsPlayerIndex(client) || !IsPlayerIndex(attacker))
	{
		return;
	}

	TFTeam team = TF2_GetClientTeam(client);
	TFTeam team_attacker = TF2_GetClientTeam(attacker);

	if (team_attacker == TFTeam_Red && team == TFTeam_Blue)
	{
		RemoveClientFreeday(attacker, _, false);
	}
}

void MakeClientFreeday(int client, int giver = -1, int announce = true)
{
	if (bHasFreeday[client] || TF2_GetClientTeam(client) != TFTeam_Red)
	{
		return;
	}

	float vecPosition[3];
	GetClientAbsOrigin(client, vecPosition);

	AttachParticle(client, "merasmus_zap_beam_bits", 2.0);
	Uberize(client, true);
	bHasFreeday[client] = true;

	if (announce)
	{
		char sGiver[128];

		if (giver != -1)
		{
			FormatEx(sGiver, sizeof(sGiver), " from {mediumslateblue}%N{default}", giver);
		}

		CPrintToChat(client, "%s You have received a Freeday%s.", g_sGlobalTag, sGiver);
	}
}

void RemoveClientFreeday(int client, int remover = -1, bool announce = true)
{
	if (!bHasFreeday[client])
	{
		return;
	}

	Uberize(client, false);
	bHasFreeday[client] = false;

	if (announce)
	{
		char sRemover[128];

		if (remover != -1)
		{
			FormatEx(sRemover, sizeof(sRemover), " from {mediumslateblue}%N{default}", remover);
		}

		CPrintToChat(client, "%s Your Freeday has been stripped%s.", g_sGlobalTag, sRemover);
	}
}

int GetMaximumFreedays()
{
	int amount;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red)
		{
			amount++;
		}
	}

	if (amount > 2)
	{
		amount = 2;
	}

	return amount;
}

void ShowFreedayForSomeMenu(int client)
{
	if (iChosen <= 0)
	{
		char sBuffer[255];
		strcopy(sBuffer, sizeof(sBuffer), "{mediumslateblue}%N {default}has chosen the following for a freeday: ");

		bool first = true;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && client != i && bShouldGiveFreeday[i])
			{
				Format(sBuffer, sizeof(sBuffer), first ? "%s%N" : "%s, %N", sBuffer, i);
				first = false;
			}
		}

		CPrintToChatAll("%s %s", g_sGlobalTag, sBuffer);
		return;
	}

	Menu menu = CreateMenu(MenuHandler_FreedayForSome);
	SetMenuTitle(menu, "Freeday For Some: [%i]", iChosen);

	AddMenuItemFormat(menu, "", ITEMDRAW_DEFAULT, "--Finished choosing Freedays.");
	AddMenuItemFormat(menu, "", ITEMDRAW_DISABLED, "%N", client);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && client != i && TF2_GetClientTeam(i) == TFTeam_Red)
		{
			char sID[64];
			IntToString(GetClientUserId(i), sID, sizeof(sID));

			AddMenuItemFormat(menu, sID, bShouldGiveFreeday[i] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%N", i);
		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_FreedayForSome(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[64]; char sDisplay[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			if (param2 == 0)
			{
				iChosen = 0;
				ShowFreedayForSomeMenu(param1);
				return;
			}

			int userid = StringToInt(sInfo);
			int client = GetClientOfUserId(userid);

			if (client == 0)
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}Target is no longer available, please try again.", g_sGlobalTag);
				ShowFreedayForSomeMenu(param1);
				return;
			}

			bShouldGiveFreeday[client] = true;
			CPrintToChatAll("%s {mediumslateblue}%N {default}has been given a freeday next round by {mediumslateblue}%N{default}.", g_sGlobalTag, client, param1);
			iChosen--;

			ShowFreedayForSomeMenu(param1);
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void PerformBlind(int target, int amount)
{
	int targets[2];
	targets[0] = target;

	int duration = 5;
	int holdtime = 5;
	int flags;
	if (amount == 0)
	{
		flags = (0x0001 | 0x0010);
	}
	else
	{
		flags = (0x0002 | 0x0008);
	}

	int color[4] = { 0, 0, 0, 0 };
	color[3] = amount;

	Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", duration);
		pb.SetInt("hold_time", holdtime);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(duration);
		bf.WriteShort(holdtime);
		bf.WriteShort(flags);
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}

	EndMessage();
}

void Uberize(int iClient, bool bSet)
{
	if (!IsClientInGame(iClient))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", bSet);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", 2);
}

public Action Timer_DeFade(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			PerformBlind(i, 0);
		}
	}
}

public Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWep, float fDmgForce[3], float fDmgPos[3], int iDmgCustom)
{
	int clientlr = GetClientOfUserId(g_iClientLR);
	if (0 > iVictim > MaxClients
	|| 0 > iAttacker > MaxClients)
	{
		return Plugin_Continue;
	}
	
	if (TF2_GetClientTeam(iAttacker) == TFTeam_Blue && TF2Jail2_GetWarden() != iAttacker && (iVictim == clientlr || bHasFreeday[iVictim]))
	{
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
