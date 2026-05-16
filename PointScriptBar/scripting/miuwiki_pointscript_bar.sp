#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Point Script Bar",
	author = "Miuwiki",
	description = "Provide point script bar native to use in game",
	version = PLUGIN_VERSION,
	url = "http://www.miuwiki.site"
}

#define DEBUG 1

#define L4D2_MAXPLAYERS 64

#define MAX_TEXT_LENGTH 128
#define GAME_DATA   "miuwiki_pointscript_bar"
#define GRAVE_MODEL "models/w_models/weapons/w_eq_incendiary_ammopack.mdl"

/**
 * =========================================================================
 * KNOW ISSUE:
 * 1. text and subtext need 1 - 5s delay to show after point be create.
 * so don't use the bar immedately after OnClientPutInServer().
 * 
 * =========================================================================
 */

Handle g_SDKCall_ChangeTransmit;
Handle g_SDKCall_SetUseString;
Handle g_SDKCall_SetSubString;

DynamicHook g_DynamicHook_PointScriptUseTarget_UpdateTransmitState;
// DynamicHook g_DynamicHook_PointScriptUseTarget_Activate;

enum struct PointScriptBar
{
    // state
    bool  text_available;
    
    // user changeable information
	bool  pause;
	char  text[MAX_TEXT_LENGTH];
	char  subtext[MAX_TEXT_LENGTH];
    float persent;
	float duration;

    // user unchangeable information
    bool  showing;
    bool  locked;
    float starttime;
    float endtime;
    
}

enum struct GlobalPlayerData
{
	// pointscript entity state
	int  ref_point;
	int  ref_dynamic;
    char linkstr[128];

	// player bar info
	PointScriptBar bar;
	
    int userid;
	
    void InitPointBar(int userid)
	{
		FormatEx(this.linkstr, sizeof(this.linkstr), "%f-PointScriptBar-%d", GetRandomFloat(), userid);
        this.userid      = userid;
        this.ref_dynamic = CreatePointDynamic(this.linkstr);
        this.ref_point   = CreatePointScript(this.linkstr);

        this.bar.text_available = false;
        this.bar.endtime        = 0.0;
        this.bar.locked         = false;
	}

	void RemovePointBar()
	{
		int point   = EntRefToEntIndex(this.ref_point);
		int dynamic = EntRefToEntIndex(this.ref_dynamic);

		if( point > 31 && IsValidEntity(point) )
			RemoveEntity(point);

		if( dynamic > 31 && IsValidEntity(dynamic) )
			RemoveEntity(dynamic);

		// Set these state to -1 whatever entity has been remove or not. I don't care about the leak entity :)
		this.ref_dynamic   = -1;
		this.ref_point     = -1;
		this.linkstr	   = "";

		this.bar.text_available = false;
        this.bar.endtime        = 0.0;
        this.bar.locked         = false;
	}

    void UpdatePointBar()
	{
        // Actually IsValidEntity() can directly check reference of entity.
        if( !IsValidEntity(this.ref_dynamic) )
        {
            this.ref_dynamic = CreatePointDynamic(this.linkstr);
            this.bar.text_available = false;
            this.bar.endtime        = 0.0;
            this.bar.locked         = false;
        }
			
		if( !IsValidEntity(this.ref_point) )
		{
            this.ref_point = CreatePointScript(this.linkstr);
            this.bar.text_available = false;
            this.bar.endtime        = 0.0;
            this.bar.locked         = false;
        }
		
        if( this.ref_point == -1 || this.ref_dynamic == -1 )
        {
            LogError("PointBar.UpdatePointBar: invalid entity index of point script or point dynamic, skip this update frame");
            return;
        }

        int   point     = EntRefToEntIndex(this.ref_point);
        int   client    = GetClientOfUserId(this.userid);
        float now       = GetGameTime();
		
        if( now - GetEntPropFloat(point, Prop_Send, "m_flCreateTime") < 1.0 ) // see know issue 1.
            this.bar.text_available = false;
        else
            this.bar.text_available = true;

		if( !this.bar.text_available || now > this.bar.endtime )
		{
			this.bar.showing = false;
            this.bar.locked  = false;
			SetEntProp(point, Prop_Send, "m_bCanShowBuildPanel", 0);
            SetEntPropEnt(client, Prop_Send, "m_hBuildableButtonUseEnt", -1); 
			SetEntPropFloat(point, Prop_Send, "m_flPreviousProgressPercent", 0.0);
			return;
		}

		// PrintToChat(this.client, "showing your bar");
        this.bar.showing = true;
		SetEntProp(point, Prop_Send, "m_bCanShowBuildPanel", 1);
        SetEntPropEnt(client, Prop_Send, "m_hBuildableButtonUseEnt", EntRefToEntIndex(this.ref_dynamic)); // this is important
		
		SDKCall(g_SDKCall_SetUseString, point, this.bar.text);
		SDKCall(g_SDKCall_SetSubString, point, this.bar.subtext);

		if( this.bar.pause )
        {
            this.bar.starttime = now - (this.bar.persent * this.bar.duration);
            this.bar.endtime   = now + (1 - this.bar.persent) * this.bar.duration;
        }
        else
		{
			this.bar.persent = (now - this.bar.starttime) / (this.bar.duration);
            if( this.bar.persent < 0.0 || this.bar.persent > 1.0 )
            {
                this.bar.showing = false;
                this.bar.locked  = false;
                SetEntProp(point, Prop_Send, "m_bCanShowBuildPanel", 0);
                SetEntPropEnt(client, Prop_Send, "m_hBuildableButtonUseEnt", -1); 
                SetEntPropFloat(point, Prop_Send, "m_flPreviousProgressPercent", 0.0);
                return;
            }
			// this.bar.persent = (0.0 <= this.bar.persent <= 1.0) ? this.bar.persent : 0.0;
		}

		SetEntPropFloat(point, Prop_Send, "m_flPreviousProgressPercent", this.bar.persent);
		SetEntPropFloat(point, Prop_Data, "m_flDuration", this.bar.duration);
	}

    void ApplyDuration(float duration, bool locked)
    {
        this.bar.locked      = locked;
		this.bar.duration    = duration <= 0.0 ? 0.0 : duration;
        this.bar.starttime   = GetGameTime() - (this.bar.persent * this.bar.duration);
        this.bar.endtime     = this.bar.starttime + duration;
    }
}

GlobalPlayerData
	player[L4D2_MAXPLAYERS + 1];
    
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if( GetEngineVersion() != Engine_Left4Dead2 ) // only support left4dead2
		return APLRes_SilentFailure;

	RegPluginLibrary("miuwiki_pointscript_bar");
	/**
	 * These for methodmap point script bar
	 */
    // CreateNative("PointScriptBar.PointScriptBar", Native_PointScriptBar_GetAvailable);
    CreateNative("PointScriptBar.IsAvailable.get", Native_PointScriptBar_GetAvailable);
    CreateNative("PointScriptBar.IsShowing.get", Native_PointScriptBar_GetShowing);
	CreateNative("PointScriptBar.duration.get", Native_PointScriptBar_GetDuration);
    CreateNative("PointScriptBar.Apply", Native_PointScriptBar_Apply);
    CreateNative("PointScriptBar.persent.get", Native_PointScriptBar_GetPersent);
    CreateNative("PointScriptBar.persent.set", Native_PointScriptBar_SetPersent);
    CreateNative("PointScriptBar.pause.get", Native_PointScriptBar_GetPause);
    CreateNative("PointScriptBar.pause.set", Native_PointScriptBar_SetPause);
    
    CreateNative("PointScriptBar.GetText", Native_PointScriptBar_GetText);
    CreateNative("PointScriptBar.SetText", Native_PointScriptBar_SetText);
	CreateNative("PointScriptBar.GetSubText", Native_PointScriptBar_GetSubText);
    CreateNative("PointScriptBar.SetSubText", Native_PointScriptBar_SetSubText);
    return APLRes_Success;
}

any Native_PointScriptBar_GetAvailable(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    return player[client].bar.text_available;
}

any Native_PointScriptBar_GetShowing(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    return GetEntProp(player[client].ref_point, Prop_Send, "m_bCanShowBuildPanel") == 1;
}

any Native_PointScriptBar_GetDuration(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    return player[client].bar.duration;
}

any Native_PointScriptBar_Apply(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);

    if( !player[client].bar.showing )
    {
        player[client].ApplyDuration(GetNativeCell(2), GetNativeCell(4));
        return 1;
    }
    else if( GetNativeCell(3) == true && !player[client].bar.locked ) // force && not locked
    {
        player[client].ApplyDuration(GetNativeCell(2), GetNativeCell(4));
        return 1;
    }
    
    return 0;
}

any Native_PointScriptBar_GetPersent(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    return player[client].bar.persent;
}

any Native_PointScriptBar_SetPersent(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    float persent = GetNativeCell(2);

    player[client].bar.persent = persent <= 0.0 ? 0.0 : persent;
    return 0;
}

any Native_PointScriptBar_GetText(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    
    SetNativeString(2, player[client].bar.text, MAX_TEXT_LENGTH);
    return 0;
}

any Native_PointScriptBar_SetText(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    char text[MAX_TEXT_LENGTH];
    GetNativeString(2, text, sizeof(text));
    FormatEx(player[client].bar.text, MAX_TEXT_LENGTH, "%s", text);
    return 0;
}

any Native_PointScriptBar_GetSubText(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    
    SetNativeString(2, player[client].bar.subtext, MAX_TEXT_LENGTH);
    return 0;
}

any Native_PointScriptBar_SetSubText(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    char subtext[MAX_TEXT_LENGTH];
    GetNativeString(2, subtext, sizeof(subtext));
    FormatEx(player[client].bar.subtext, MAX_TEXT_LENGTH, "%s", subtext);
    return 0;
}

any Native_PointScriptBar_GetPause(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);

    return player[client].bar.pause;
}

any Native_PointScriptBar_SetPause(Handle plugin, int arg_num)
{
    int client = GetNativeCell(1);
    bool pause = GetNativeCell(2);
    player[client].bar.pause = pause;
    return 0;
}


public void OnPluginStart()
{
    LoadGameData();

    // HookEvent("round_start", Event_RoundStart);
	// RegConsoleCmd("sm_showmybar", Cmd_ShowMybar);
}

public void OnClientPutInServer(int client)
{
	if( IsFakeClient(client) )
		return;
	
	player[client].InitPointBar(GetClientUserId(client));
	SDKHook(client, SDKHook_PostThinkPost, SDKCallback_OnClientPostThink);
}

void SDKCallback_OnClientPostThink(int client)
{
	player[client].UpdatePointBar();
}

public void OnClientDisconnect(int client)
{
	player[client].RemovePointBar();
}

Action SDKCallback_DynamicUse(int entity, int client)
{
	return Plugin_Stop;
}

Action SDKCallback_PointUse(int entity, int client)
{
	return Plugin_Stop;
}

Action SDKCallback_TransimitDynamic(int entity, int client)
{
	if( entity == EntRefToEntIndex(player[client].ref_dynamic) )
		return Plugin_Continue;

	return Plugin_Stop;
}
Action SDKCallback_TransimitPoint(int entity, int client)
{
	if( entity == EntRefToEntIndex(player[client].ref_point) )
		return Plugin_Continue;

	return Plugin_Stop;
}

MRESReturn DHookCallback_CPointScriptUseTarget_UpdateTransmitState(int entity, DHookReturn hReturn)
{
    // see https://github.com/goldeneye-source/ges-code/blob/2630cd8ef3d015af53c72ec2e19fc1f7e7fe8d9d/public/edict.h#L86

	// transmit = FL_EDICT_FULLCHECK	(0<<0), transmit, check every time.
	// transmit = FL_EDICT_ALWAYS		(1<<3), transmit, always.
	// transmit = FL_EDICT_DONTSEND	    (1<<4), never transmit
	// transmit = FL_EDICT_PVSCHECK	    (1<<5), transmit, check every time if in PVS

    // important! since 'point_script_use_target' default is FL_EDICT_ALWAYS, SDKHook_SetTransmit doesn't effect it.
    // we need it only show to the relative client.

	hReturn.Value = SDKCall(g_SDKCall_ChangeTransmit, entity, FL_EDICT_FULLCHECK);

    // LogMessage("================%d transimit has been change to %d", entity, 0);
	return MRES_Supercede;
}

void LoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAME_DATA);
	if(FileExists(sPath) == false) 
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAME_DATA);
	if(hGameData == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAME_DATA);

    char func_name[PLATFORM_MAX_PATH];

    FormatEx(func_name, sizeof(func_name), "%s", "CPointScriptUseTarget::UpdateTransmitState");
    g_DynamicHook_PointScriptUseTarget_UpdateTransmitState = new DynamicHook(hGameData.GetOffset(func_name), HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity);
    if( !g_DynamicHook_PointScriptUseTarget_UpdateTransmitState )
        SetFailState("Failed to create DynamicHook of \"%s\"");

    FormatEx(func_name, sizeof(func_name), "%s", "CBaseEntity::SetTransmitState");
	StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, func_name);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	if( (g_SDKCall_ChangeTransmit = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall of \"%s\"", func_name);

    FormatEx(func_name, sizeof(func_name), "%s", "CPointScriptUseTarget::ScriptSetUseString");
	StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, func_name);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if( (g_SDKCall_SetUseString = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall of \"%s\"", func_name);

    FormatEx(func_name, sizeof(func_name), "%s", "CPointScriptUseTarget::ScriptSetUseSubString");
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, func_name);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if( (g_SDKCall_SetSubString = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall of \"%s\"", func_name);
	delete hGameData;
}

int CreatePointDynamic(const char[] linkstr)
{
    int dynamic = CreateEntityByName("prop_dynamic_override");
    if( dynamic == -1 )
    {
        return -1;
    }

    SetEntityModel(dynamic, GRAVE_MODEL);
    SetEntPropString(dynamic, Prop_Data, "m_iName", linkstr);
    DispatchKeyValue(dynamic, "glowstate", "0");
    DispatchKeyValue(dynamic, "solid", "0");
    TeleportEntity(dynamic, {0.0,0.0,0.0});
    DispatchSpawn(dynamic);
    // ActivateEntity(dynamic);
    SetEntityRenderMode(dynamic, RENDER_NONE);
    SDKHook(dynamic, SDKHook_SetTransmit, SDKCallback_TransimitDynamic); // never transmit to client.
    SDKHook(dynamic, SDKHook_Use, SDKCallback_DynamicUse);
    return EntIndexToEntRef(dynamic);
}

int CreatePointScript(const char[] linkstr)
{
    int point = CreateEntityByName("point_script_use_target");
    if( point == -1 )
    {
        return -1;
    }
        
    SetEntPropString(point, Prop_Data, "m_sUseModelName", linkstr);
    SetEntPropString(point, Prop_Send, "m_sUseString", "");
    SetEntPropString(point, Prop_Send, "m_sUseSubString", "");
    SetEntPropFloat(point, Prop_Data, "m_flDuration", 5.0);
    SetEntPropFloat(point, Prop_Send, "m_flPreviousProgressPercent", 0.0);
    SetEntProp(point, Prop_Send, "m_bCanShowBuildPanel", 0);
    
    g_DynamicHook_PointScriptUseTarget_UpdateTransmitState.HookEntity(Hook_Pre, point, DHookCallback_CPointScriptUseTarget_UpdateTransmitState);
    SDKHook(point, SDKHook_SetTransmit, SDKCallback_TransimitPoint); // only transimit to owner client.
    SDKHook(point, SDKHook_Use, SDKCallback_PointUse);

    DispatchSpawn(point);
    ActivateEntity(point);
    
    return EntIndexToEntRef(point);
}

public void OnMapStart()
{
	PrecacheModel(GRAVE_MODEL);
}