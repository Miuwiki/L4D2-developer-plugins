#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <miuwiki_pointscript_bar>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Test Bar Plugin",
	author = "Miuwiki",
	description = "Test Bar Plugin",
	version = PLUGIN_VERSION,
	url = "http://www.miuwiki.site"
}

#define L4D2_MAXPLAYERS 64

/**
 * =========================================================================
 * 
 * =========================================================================
 */

public void OnAllPluginsLoaded()
{
    if( !LibraryExists("miuwiki_pointscript_bar") )
        SetFailState("Failed to find required plugin \"miuwiki_pointscript_bar.smx\"");
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_bar", Cmd_BarOnce);
    RegConsoleCmd("sm_bar_persent", Cmd_BarPersent);
    RegConsoleCmd("sm_bar_pause", Cmd_BarPause);
    RegConsoleCmd("sm_bar_random", Cmd_BarRandomText);
}

// start normal bar
Action Cmd_BarOnce(int client, int args)
{
    if( client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) )
        return Plugin_Handled;

    if( args != 0 )
        return Plugin_Handled;
    
    PointScriptBar bar = PointScriptBar(client);
    bar.persent  = 0.0;
    bar.pause    = false;
    bar.SetText("text");
    bar.SetSubText("subtext");

    bar.Apply(5.0);
    PrintToChat(client, "starting bar at once");
    return Plugin_Handled;
}

// start bar at specify persent
Action Cmd_BarPersent(int client, int args)
{
    if( client < 1 || client > MaxClients )
        return Plugin_Handled;

    if( args != 1 )
        return Plugin_Handled;
    
    PointScriptBar bar = PointScriptBar(client);
    bar.persent = GetCmdArgFloat(1);
    bar.pause = false;
    bar.SetText("");
    bar.SetSubText("");

    bar.Apply(10.0);
    PrintToChat(client, "starting bar at %f persent", bar.persent);
    
    return Plugin_Handled;
}
// start bar at 0.2 persent but pause
Action Cmd_BarPause(int client, int args)
{
    if( client < 1 || client > MaxClients )
        return Plugin_Handled;

    if( args != 0 )
        return Plugin_Handled;
    
    PointScriptBar bar = PointScriptBar(client);
    bar.persent = 0.2;
    bar.pause = true;
    bar.SetText("");
    bar.SetSubText("");

    bar.Apply(10.0);
    PrintToChat(client, "starting bar at 0.2 persent but pause");
    
    return Plugin_Handled;
}

Action Cmd_BarRandomText(int client, int args)
{
    if( client < 1 || client > MaxClients )
        return Plugin_Handled;

    if( args != 0 )
        return Plugin_Handled;
    
    PointScriptBar bar = PointScriptBar(client);
    bar.persent = 0.0;
    bar.pause = false;
    bar.SetText("");
    bar.SetSubText("");

    // force to replace, locked bar to prevent it from being replace by others
    if( bar.Apply(10.0, true, true) )
    {
        CreateTimer(0.1, Timer_ShowBarRandomText, GetClientUserId(client), TIMER_REPEAT);
        PrintToChat(client, "starting bar with random text using timer");
    }
    else
    {
        PrintToChat(client, "An locked bar is running, couldn't start a new bar");
    }
    return Plugin_Handled;
}

Action Timer_ShowBarRandomText(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if( client < 1 || client > MaxClients || !IsClientInGame(client) )
        return Plugin_Stop;
    
    static int step;
    PointScriptBar bar = PointScriptBar(client);
    if( bar.pause )
        return Plugin_Continue;

	if( step > 100 )
	{
		step = 0;
		return Plugin_Stop;
	}

    static char text[128];
    FormatEx(text, sizeof(text), "奖品%d", GetRandomInt(1, 1000));

    bar.SetText(text);
    bar.SetSubText(text);

    step++;
    return Plugin_Continue;
}
