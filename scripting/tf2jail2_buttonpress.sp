#pragma semicolon 1

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <sourcemod-misc>
#include <colorvariables>
#include <tf2jail2/tf2jail2_lastrequests>
#include <tf2jail2/tf2jail2_warden>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#define REQUIRE_PLUGIN

#pragma newdecls required

public Plugin myinfo = 
{
	name = "TF2Jail2 Button Presses",
	author = PLUGIN_AUTHOR,
	description = "Notify server of button presses,",
	version = PLUGIN_VERSION,
	url = "https://callister.tf"
};

public void OnPluginStart()
{
	HookEntityOutput("func_button", "OnPressed", Hook_OnPressed);
}

public void Hook_OnPressed(const char[] output, int ent, int activator, float delay)
{
	if (0 < activator <= MaxClients && IsClientInGame(activator))
	{
		char sEnt[MAX_NAME_LENGTH];
		GetEntPropString(ent, Prop_Data, "m_iName", sEnt, sizeof(sEnt));
		
		if (TF2_GetClientTeam(activator) == TFTeam_Red)
		{
			if (TF2Jail2_IsFreeday(activator))
				CPrintToChatAll("%s Freeday {mediumslateblue}%N {default} pressed button {mediumslateblue}%s.", g_sGlobalTag, activator, sEnt);
		}
		
		if (TF2_GetClientTeam(activator) == TFTeam_Blue)
		{
			if (TF2Jail2_GetWarden() == activator)
				CPrintToChatAll("%s Warden {mediumslateblue}%N {default} pressed button {mediumslateblue}%s.", g_sGlobalTag, activator, sEnt);
			else
				CPrintToChatAll("%s Guard {mediumslateblue}%N {default} pressed button {mediumslateblue}%s.", g_sGlobalTag, activator, sEnt);
		}
	}
}
