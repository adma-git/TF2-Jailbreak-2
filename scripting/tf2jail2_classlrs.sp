#pragma semicolon 1

#define PLUGIN_AUTHOR "adma"
#define PLUGIN_VERSION "1.00"

//Sourcemod Includes
#include <sourcemod>
#include <tf2>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2jail2/tf2jail2_lastrequests>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#define REQUIRE_PLUGIN

#pragma newdecls required

TFClassType TFClass_Forced = TFClass_Unknown;

public Plugin myinfo = 
{
	name = "TF2Jail2 Class Round Last Requests",
	author = PLUGIN_AUTHOR,
	description = "TF2Jail2 Class Round Last Requests",
	version = PLUGIN_VERSION,
	url = "https://callister.tf"
};

public void OnPluginStart()
{
	HookEvent("player_changeclass", OnPlayerChangeClass); // Class Round LR
}

public void TF2Jail2_OnlastRequestRegistrations()
{
	TF2Jail2_RegisterLR("Scout Round", _, Scout_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Soldier Round", _, Soldier_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Pyro Round", _, Pyro_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Demoman Round", _, Demo_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Heavy Round", _, Heavy_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Engineer Round", _, Engi_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Medic Round", _, Medic_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Sniper Round", _, Sniper_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
	TF2Jail2_RegisterLR("Spy Round", _, Spy_OnLRRoundStart, ClassRound_OnLRRoundActive, ClassRound_OnLRRoundEnd);
}

/* Class Round */

public void Scout_OnLRRoundStart(int iChooser) { TFClass_Forced = TFClass_Scout; }
public void Soldier_OnLRRoundStart(int iChooser){ TFClass_Forced = TFClass_Soldier; }
public void Pyro_OnLRRoundStart(int iChooser){ TFClass_Forced = TFClass_Pyro; }
public void Demo_OnLRRoundStart(int iChooser){ TFClass_Forced = TFClass_DemoMan; }
public void Heavy_OnLRRoundStart(int iChooser){ TFClass_Forced = TFClass_Heavy; }
public void Engi_OnLRRoundStart(int iChooser){ TFClass_Forced = TFClass_Engineer; }
public void Medic_OnLRRoundStart(int iChooser){ TFClass_Forced = TFClass_Medic; }
public void Sniper_OnLRRoundStart(int iChooser) { TFClass_Forced = TFClass_Sniper; }
public void Spy_OnLRRoundStart(int iChooser){ TFClass_Forced = TFClass_Spy; }
public void ClassRound_OnLRRoundEnd(int iChooser){ TFClass_Forced = TFClass_Unknown; }

public void ClassRound_OnLRRoundActive(int iChooser)
{
	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		ForceClass(i);
}

public void OnPlayerChangeClass(Event hEvent, const char[] sName, bool bBroadcast) 
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	ForceClass(iClient);
}

void ForceClass(int iClient)
{
	if (TFClass_Forced != TFClass_Unknown)
	{
		TF2_SetPlayerClass(iClient, TFClass_Forced, false);
		
		if (IsPlayerAlive(iClient))
		{
			TF2_RegeneratePlayer(iClient);
		}
	}
}

/* End Class Round */

