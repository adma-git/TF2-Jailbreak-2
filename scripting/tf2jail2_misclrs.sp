#pragma semicolon 1

#define PLUGIN_AUTHOR "adma"
#define PLUGIN_VERSION "1.00"

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>
#include <tf2>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>
#include <tf2items_giveweapon>

//Our Includes
#include <tf2jail2/tf2jail2_lastrequests>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#include <tf2jail2/tf2jail2_maptriggers>
#include <tf2jail2/tf2jail2_warden>
#define REQUIRE_PLUGIN

#pragma newdecls required

Handle g_hRRRTimer = null,
g_iHnSGuardTimer = null,
g_hHnSHideTimer = null,
g_hHnSSeekTimer = null;

int g_iRRRTime,
g_iHnSHideTime,
g_iHnSSeekTime,
g_iHnSGuardTime;

UserMsg g_FadeUserMsgId;

ConVar convar_HnSGuardTime, convar_HnSHideTime, convar_HnSSeekTime, convar_RRRTime, convar_LGRGravity;

public Plugin myinfo = 
{
	name = "TF2Jail2 Miscellaneous Last Requests",
	author = PLUGIN_AUTHOR,
	description = "TF2Jail2 Miscellaneous Last Requests",
	version = PLUGIN_VERSION,
	url = "https://callister.tf"
};

public void OnPluginStart()
{
	int iFlags;
	iFlags = GetConVarFlags(FindConVar("mp_friendlyfire")); SetConVarFlags(FindConVar("mp_friendlyfire"), iFlags & ~FCVAR_NOTIFY);
	iFlags = GetConVarFlags(FindConVar("sv_gravity")); SetConVarFlags(FindConVar("sv_gravity"), iFlags & ~FCVAR_NOTIFY);
	g_FadeUserMsgId = GetUserMessageId("Fade");
	
	convar_HnSGuardTime = CreateConVar("tf2jail2_hidenseek_guardtime", "20", "The time guards have to open cell doors", FCVAR_NOTIFY, true, 5.0, true, 60.0);
	convar_HnSHideTime = CreateConVar("tf2jail2_hidenseek_hidetime", "90", "The time prisoners have to hide", FCVAR_NOTIFY, true, 30.0, true, 300.0);
	convar_HnSSeekTime = CreateConVar("tf2jail2_hidenseek_seektime", "180", "The time guards have to seek before round is reset", FCVAR_NOTIFY, true, 30.0, true, 360.0);	
	convar_RRRTime = CreateConVar("tf2jail2_RRR_time", "20", "The time before friendly fire is enabled for Rapid Rocket Round", FCVAR_NOTIFY, true, 0.0, true, 300.0);
	convar_LGRGravity = CreateConVar("tf2jail2_LGR_gravity", "200", "The gravity set for Low Gravity Round", FCVAR_NOTIFY, true, 0.0, true, 800.0);
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage); // Godmode for blues during hide n seek
}

public void TF2Jail2_OnlastRequestRegistrations()
{
	TF2Jail2_RegisterLR("Rapid Rocket Round", _, _, RRR_OnLRRoundActive, RRR_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Low Gravity Round", _, _, LG_OnLRRoundActive, LG_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Hide n Seek", _, _, HnS_OnLRRoundActive, HnS_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Guards Melee Only", _, GMO_OnLRRoundStart, _, _);
	TF2Jail2_RegisterLR("Earthquake Round", _, _, Earthquake_OnLRRoundActive, Earthquake_OnLRRoundEnd);
}

/* Rapid Rocket Round */

public void RRR_OnLRRoundActive(int iChooser)
{
	g_iRRRTime = GetConVarInt(convar_RRRTime);
	g_hRRRTimer = CreateTimer(1.0, Timer_RRRTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TF2Jail2_OpenCells(-1, false, true);
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		GiveValveLauncher(i);
		
	TF2Jail2_LockWarden(true);
}

public void RRR_OnLRRoundEnd(int iChooser)
{
	ClearTimer(g_hRRRTimer);
	SetConVarBool(FindConVar("mp_friendlyfire"), false);
}

public Action Timer_RRRTimer(Handle hTimer)
{
	PrintHintTextToAll("Friendly fire enabled in %i seconds", g_iRRRTime);
	
	if (g_iRRRTime > 0)
		g_iRRRTime--;
	else
	{
		PrintHintTextToAll("Friendly fire enabled!");
		SetConVarBool(FindConVar("mp_friendlyfire"), true);
		g_hRRRTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void GiveValveLauncher(int iClient)
{
	TF2Items_GiveWeapon(iClient, 8018);
}

/* End Rapid Rocket Round */

/* Low Gravity Round */

public void LG_OnLRRoundActive(int iChooser)
{
	SetConVarInt(FindConVar("sv_gravity"), GetConVarInt(convar_LGRGravity));
}

public void LG_OnLRRoundEnd(int iChooser)
{
	SetConVarInt(FindConVar("sv_gravity"), 800);
}

/* End Low Gravity Round */

/* Hide n Seek */

public void HnS_OnLRRoundActive(int iChooser)
{
	TF2Jail2_OpenCells(-1, false, true);
	TF2Jail2_LockWarden(true);
	g_iHnSHideTime = GetConVarInt(convar_HnSHideTime);
	g_iHnSSeekTime = GetConVarInt(convar_HnSSeekTime);
	g_iHnSGuardTime = GetConVarInt(convar_HnSGuardTime);
	g_iHnSGuardTimer = CreateTimer(1.0, Timer_HnSGuardTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
	{
		if (TF2_GetClientTeam(i) == TFTeam_Red)
			TF2_StripToMelee(i);
	}
}

public void HnS_OnLRRoundEnd(int iChooser)
{
	g_iHnSHideTime = 0;
	g_iHnSGuardTime = 0;
	g_iHnSSeekTime = 0;
	ClearTimer(g_hHnSHideTimer);
	ClearTimer(g_hHnSSeekTimer);
	ClearTimer(g_iHnSGuardTimer);
}

public Action Timer_HnSGuardTimer(Handle hTimer)
{
	PrintCenterTextAll("Guards have %i seconds to open the cell doors", g_iHnSGuardTime);
	
	if (g_iHnSGuardTime > 0)
		g_iHnSGuardTime--;
	else
	{
		g_hHnSHideTimer = CreateTimer(1.0, Timer_HnSTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			if (TF2_GetClientTeam(i) == TFTeam_Blue)
			{
				TF2_RespawnPlayer(i);
				PerformBlind(i, 255);
				SetEntityMoveType(i, MOVETYPE_NONE);
			}
		}
		
		g_iHnSGuardTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Timer_HnSTimer(Handle hTimer)
{
	PrintCenterTextAll("Guards start seeking in %i seconds!", g_iHnSHideTime);
	
	if (g_iHnSHideTime > 0)
		g_iHnSHideTime--;
	else
	{
		g_hHnSSeekTimer = CreateTimer(1.0, Timer_HnSSeek, INVALID_HANDLE, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			if (TF2_GetClientTeam(i) == TFTeam_Blue)
			{
				PerformBlind(i, 0);
				SetEntityMoveType(i, MOVETYPE_WALK);
			}
		}
		
		PrintCenterTextAll("The guards have been let free!");
		g_hHnSHideTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Timer_HnSSeek(Handle hTimer)
{
	PrintHintTextToAll("Teleporting all prisoners and guards to cells in %02d:%02d", g_iHnSSeekTime / 60, g_iHnSSeekTime % 60);
	
	if (g_iHnSSeekTime > 0)
		g_iHnSSeekTime--;
	else
	{
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
			TF2_RespawnPlayer(i);
				
		TF2Jail2_LockWarden(false);
		PrintCenterTextAll("The prisoners and guards have been teleported back to the cell area and warden has been unlocked.");
		g_hHnSSeekTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWep, float fDmgForce[3], float fDmgPos[3], int iDmgCustom)
{
	if ((MaxClients+1 > iVictim > 0) && (MaxClients+1 > iAttacker > 0) && TF2_GetClientTeam(iVictim) == TFTeam_Blue && ((175 < g_iHnSSeekTime) || g_iHnSGuardTime >= 0))
	{
		char sBuffer[MAX_NAME_LENGTH];
		
		TF2Jail2_GetCurrentLR(sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "Hide n Seek"))
		{
			fDamage = 0.0;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

/* End Hide n Seek */

/* Guards Melee Only */

public void GMO_OnLRRoundStart(int chooser)
{
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
	{
		if (TF2_GetClientTeam(i) == TFTeam_Blue)
			TF2_StripToMelee(i);
	}
}

/* End Guards Melee Only */

/* Earthquake Round */

public void Earthquake_OnLRRoundActive(int chooser)
{
	ScreenShakeAll(SHAKE_START, 10.0, 10.0, 999.0);
}

public void Earthquake_OnLRRoundEnd(int chooser)
{
	ScreenShakeAll(SHAKE_STOP, 0.0, 0.0, _);
}

/* End Earthquake Round */

bool ClearTimer(Handle &hTimer)
{
	if (hTimer != null)
	{
		KillTimer(hTimer);
		hTimer = null;
		return true;
	}
	
	return false;
}

void PerformBlind(int target, int amount)
{
	int targets[2];
	targets[0] = target;

	int duration = 1000;
	int time = 10;
	
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
		pb.SetInt("hold_time", time);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(duration);
		bf.WriteShort(time);
		bf.WriteShort(flags);
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}

	EndMessage();
}