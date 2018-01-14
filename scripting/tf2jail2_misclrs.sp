#pragma semicolon 1

#define PLUGIN_AUTHOR "adma"
#define PLUGIN_VERSION "1.00"

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>
#include <tf2>
#include <tf2attributes>

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
g_hHnSSeekTimer = null,
g_hBluePidgeonTimer = null;

int g_iRRRTime,
g_iHnSHideTime,
g_iHnSSeekTime,
g_iHnSGuardTime,
g_iPHTime;

UserMsg g_FadeUserMsgId;

ConVar convar_HnSGuardTime, convar_HnSHideTime, convar_HnSSeekTime, convar_RRRTime, convar_BluePidgeonTime, convar_LGRGravity;

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
	convar_BluePidgeonTime = CreateConVar("tf2jail2_pidgeon_time", "20", "The time before guards turn into pidgeons.", FCVAR_NOTIFY, true, 0.0, true, 300.0);
	convar_LGRGravity = CreateConVar("tf2jail2_LGR_gravity", "200", "The gravity set for Low Gravity Round", FCVAR_NOTIFY, true, 0.0, true, 800.0);
}

public void OnMapStart()
{
	PrecacheModel("models/buildables/dispenser_lvl3_light.mdl");
	PrecacheModel("models/props_forest/bird.mdl");
	PrecacheSound("vo/halloween_merasmus/sf12_magicwords07.mp3");
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
	TF2Jail2_RegisterLR("Dispenser Round", _, _, Dispenser_OnLRRoundActive, Dispenser_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Pidgeon Hunt", _, _, PH_OnLRRoundActive, PH_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Midget Round", _, _, Midget_OnLRRoundActive, _);
	TF2Jail2_RegisterLR("Air Swim Round", _, _, AS_OnLRRoundActive, _);
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

/* Dispenser Round */

public void Dispenser_OnLRRoundActive(int chooser)
{
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i))
	{
		SetVariantString("models/buildables/dispenser_lvl3_light.mdl");
		AcceptEntityInput(i, "SetCustomModel");
		SetEntProp(i, Prop_Send, "m_bCustomModelRotates", true);
		SetVariantInt(TF2_GetClientTeam(i) == TFTeam_Red ? 1 : 2);
		AcceptEntityInput(i, "Skin");
		
		RemoveValveHat(i, false);
		HideWeapons(i, false);
	}
}

public void Dispenser_OnLRRoundEnd(int chooser)
{
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		SetVariantString("");
		AcceptEntityInput(i, "SetCustomModel");
		
		RemoveValveHat(i, true);
		HideWeapons(i, true);
	}
}

void RemoveValveHat(int client, bool unhide = false)
{
	int edict = MaxClients + 1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_wearable")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFWearable") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}

	edict = MaxClients + 1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_powerup_bottle")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFPowerupBottle") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}
}

void HideWeapons(int client, bool unhide = false)
{
	HideWeaponWearables(client, unhide);
	int m_hMyWeapons = FindSendPropInfo("CTFPlayer", "m_hMyWeapons");

	for (int i = 0, weapon; i < 47; i += 4)
	{
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);

		char classname[64];
		if (weapon > MaxClients && IsValidEdict(weapon) && GetEdictClassname(weapon, classname, sizeof(classname)) && StrContains(classname, "weapon") != -1)
		{
			SetEntityRenderMode(weapon, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
			SetEntityRenderColor(weapon, 255, 255, 255, (unhide ? 255 : 5));
		}
	}
}

void HideWeaponWearables(int client, bool unhide = false)
{
	int edict = MaxClients + 1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_wearable")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFWearable") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642) continue;
			if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}
}

int FindEntityByClassnameSafe(int iStart, const char[] strClassname)
{
	while (iStart > -1 && !IsValidEntity(iStart)) iStart--;
	return FindEntityByClassname(iStart, strClassname);
}

/* End Dispenser Round */

/* Pidgeon Hunt */

public void PH_OnLRRoundActive(int chooser)
{
	g_iPHTime = GetConVarInt(convar_BluePidgeonTime);
	g_hBluePidgeonTimer = CreateTimer(1.0, Timer_BluePidegon, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i))
	{
		if (TF2_GetClientTeam(i) == TFTeam_Red)
		{
			SetEntityMoveType(i, MOVETYPE_NONE);
		}
	}
	
	TF2Jail2_OpenCells(-1, false, true);
	TF2Jail2_LockWarden(true);
}

public void PH_OnLRRoundEnd(int chooser)
{
	SetConVarInt(FindConVar("tf_scout_air_dash_count"), 1);
	ClearTimer(g_hBluePidgeonTimer);
	g_iPHTime = 0;
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		SetVariantString("");
		AcceptEntityInput(i, "SetCustomModel");
		
		RemoveValveHat(i, true);
	}
}

public Action Timer_BluePidegon(Handle hTimer)
{
	PrintCenterTextAll("Guards have %i seconds to open cells and disperse!", g_iPHTime);
	
	if (g_iPHTime > 0)
		g_iPHTime--;
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				if (TF2_GetClientTeam(i) == TFTeam_Blue)
				{
					TF2_SetPlayerClass(i, TFClass_Scout);
					SetEntPropFloat(i, Prop_Send, "m_flMaxspeed", 50.0);
					SetEntityHealth(i, 10);
					SetEntProp(i, Prop_Data, "m_iMaxHealth", 10);
					SetConVarInt(FindConVar("tf_scout_air_dash_count"), 999);
					
					SetVariantString("models/props_forest/bird.mdl");
					AcceptEntityInput(i, "SetCustomModel");
					SetEntProp(i, Prop_Send, "m_bCustomModelRotates", true);
					SetEntPropFloat(i, Prop_Data, "m_flModelScale", 2.0);
					
					TF2_CreateGlow("pidgeon", i, { 0, 255, 0, 255 } );
					RemoveValveHat(i, false);
					RemoveWeapons(i);
				}
				
				if (TF2_GetClientTeam(i) == TFTeam_Red)
				{
					SetEntityMoveType(i, MOVETYPE_WALK);
					TF2_SetPlayerClass(i, TFClass_Scout);
					TF2_RegeneratePlayer(i);
					TF2_StripToMelee(i);
					TF2Items_GiveWeapon(i, 9014);
					TF2Attrib_RemoveByName(i, "no double jump");
					SetPlayerWeaponAmmo(i, 1, 10, 999);
				}
			}
		}	
		
		EmitSoundToAll("vo/halloween_merasmus/sf12_magicwords07.mp3");
		g_hBluePidgeonTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void RemoveWeapons(int client)
{
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);
}

/* End Pidgeon Hunt */

/* Midget Round */

public void Midget_OnLRRoundActive(int chooser)
{
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i))
	{
		SetEntPropFloat(i, Prop_Data, "m_flModelScale", 0.5);
	}
}

/* End Midget Round */

public void AS_OnLRRoundActive(int chooser)
{
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i))
	{
		TF2_AddCondition(i, TFCond_SwimmingNoEffects, TFCondDuration_Infinite);
	}
}

/* End Midget Round */

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