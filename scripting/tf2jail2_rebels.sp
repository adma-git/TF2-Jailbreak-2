//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2jail2/tf2jail2_rebels>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Announce;
ConVar convar_RebelTimer;

//Forwards
Handle g_hForward_OnRebel_Post;

//Globals
bool g_bLate;
bool g_bIsMarkedRebel[MAXPLAYERS + 1];
Handle g_hRebelTimer[MAXPLAYERS + 1];
int g_iParticle[MAXPLAYERS + 1][2];

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Rebels",
	author = "Keith Warren (Sky Guardian)",
	description = "Handles and keeps track of all rebels for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_rebels");

	CreateNative("TF2Jail2_IsRebel", Native_IsRebel);

	g_hForward_OnRebel_Post = CreateGlobalForward("TF2Jail2_OnRebel_Post", ET_Ignore, Param_Cell);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_rebels_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Announce = CreateConVar("sm_tf2jail2_rebels_announce", "1", "Announce to players once someone becomes a rebel.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_RebelTimer = CreateConVar("sm_tf2jail2_rebels_timer", "30.0", "Time to keep rebel on a client, resets on damage.", FCVAR_NOTIFY, true, 0.0);

	HookEvent("player_hurt", Event_OnPlayerHurt);
	HookEvent("player_death", Event_OnPlayerDeath_Pre, EventHookMode_Pre);
}

public void OnMapStart()
{
	for (int i = 0; i < sizeof(g_iParticle); i++)
	{
		g_iParticle[i][0] = -1;
		g_iParticle[i][1] = -1;
	}
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}

		g_bLate = false;
	}
}

public void OnClientPutInServer(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	g_bIsMarkedRebel[client] = false;
	delete g_hRebelTimer[client];
}

public void OnClientDisconnect(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	g_bIsMarkedRebel[client] = false;
	delete g_hRebelTimer[client];
}

//////////////////////////////////////////////////
//Events

public Action Event_OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int userid_attacker = GetEventInt(event, "attacker");

	int client = GetClientOfUserId(userid);
	int attacker = GetClientOfUserId(userid_attacker);
	
	RemoveParticles2(client);

	if (!GetConVarBool(convar_Status) || !IsPlayerIndex(client) || !IsPlayerIndex(attacker))
	{
		return Plugin_Continue;
	}

	TFTeam team = TF2_GetClientTeam(client);
	TFTeam team_attacker = TF2_GetClientTeam(attacker);

	if (team_attacker == TFTeam_Red && team == TFTeam_Blue)
	{
		SetEventBroadcast(event, true);
	}

	return Plugin_Continue;
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
		MarkRebel(attacker);
	}
}

void MarkRebel(int client)
{
	if (!g_bIsMarkedRebel[client])
	{
		RemoveParticles2(client);
		AttachParticle2(client, "superrare_burning2", "effect_hand_R");
		SetEntityRenderColor(client, 0, 255, 0, 255);
		g_bIsMarkedRebel[client] = true;
		CPrintToChat(client, "%s You have been marked as a rebel.", g_sGlobalTag);

		if (GetConVarBool(convar_Announce))
		{
			CPrintToChatAll("%s {mediumslateblue}%N {default}has been marked as a Rebel!", g_sGlobalTag, client);
		}

		Call_StartForward(g_hForward_OnRebel_Post);
		Call_PushCell(client);
		Call_Finish();
	}

	delete g_hRebelTimer[client];
	g_hRebelTimer[client] = CreateTimer(GetConVarFloat(convar_RebelTimer), Timer_DisableRebel, GetClientUserId(client), TIMER_REPEAT);
}

void AttachParticle2(int iClient, char[] sParticleType, char[] sBoneAttachment)
{
	for (int i = 0; i <= 1; i++)
	{
		if (g_iParticle[iClient][i] != -1)
			continue;
		
		g_iParticle[iClient][i] = CreateEntityByName("info_particle_system");
		char sName[128];
		
		if (IsValidEdict(g_iParticle[iClient][i]))
		{
			float position[3];
			GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);
			
			TeleportEntity(g_iParticle[iClient][i], position, NULL_VECTOR, NULL_VECTOR);
			
			DispatchKeyValue(iClient, "targetname", sName);
			
			DispatchKeyValue(g_iParticle[iClient][i], "targetname", "tf2particle");
			DispatchKeyValue(g_iParticle[iClient][i], "parentname", sName);
			DispatchKeyValue(g_iParticle[iClient][i], "effect_name", sParticleType);
			DispatchSpawn(g_iParticle[iClient][i]);
			SetVariantString("!activator");
			AcceptEntityInput(g_iParticle[iClient][i], "SetParent", iClient, g_iParticle[iClient][i], 0);
			
			if (strlen(sBoneAttachment) > 0)
			{
				SetVariantString(sBoneAttachment);
				AcceptEntityInput(g_iParticle[iClient][i], "SetParentAttachmentMaintainOffset", g_iParticle[iClient][i], g_iParticle[iClient][i], 0);
			}
			
			ActivateEntity(g_iParticle[iClient][i]);
			AcceptEntityInput(g_iParticle[iClient][i], "start");
			
			break;
		}
	}
}

void RemoveParticles2(int iClient)
{
	for (int i = 0; i <= 1; i++)
	{
		if (g_iParticle[iClient][i] != -1)
		{
			if (IsValidEdict(g_iParticle[iClient][i]))
				AcceptEntityInput(g_iParticle[iClient][i], "Kill");
				
			g_iParticle[iClient][i] = -1;
		}
	}
}

//////////////////////////////////////////////////
//Timers

public Action Timer_DisableRebel(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!GetConVarBool(convar_Status))
	{
		g_hRebelTimer[client] = null;
		return Plugin_Stop;
	}

	RemoveParticles2(client);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	g_bIsMarkedRebel[client] = false;

	g_hRebelTimer[client] = null;
	return Plugin_Stop;
}

//////////////////////////////////////////////////
//Natives

public int Native_IsRebel(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_bIsMarkedRebel[client];
}
