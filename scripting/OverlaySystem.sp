#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

ConVar	g_cPathToDeathOverlay;
ConVar	g_cDeathOverlay;
ConVar	g_cDeathOverlayTimer;
ConVar	g_cDeathOverlayPostTimer;

ConVar	g_cPathToSpawnOverlay;
ConVar	g_cSpawnOverlay;
ConVar	g_cSpawnOverlayTimer;

ConVar	g_cPathToWelcomeOverlay;
ConVar	g_cWelcomeOverlay;
ConVar	g_cWelcomeOverlayTimer;

ConVar	g_cFlagHide;
ConVar	g_cCmdOverlay;

int		g_iSpecReplay;
char	sOverlaypath[PLATFORM_MAX_PATH];
char	g_szFlag[PLATFORM_MAX_PATH];
bool	g_bCSGO;
bool	g_bJoinOverlay[MAXPLAYERS + 1] = true;
bool	g_bHideOverlay[MAXPLAYERS + 1];
Handle	g_hKillSpawnTimer[MAXPLAYERS + 1];
Handle	g_hKillWelcomeTimer[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[OS] Overlay System",
	description = "Visual advertising system. After death, before the put in server etc.",
	author = "suremiur (Sure666), helped Rostu and Discord band.",
	version = "2.0",
	url = "vk.com/suremiur"
};

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);

	if (GetEngineVersion() == Engine_CSGO)
	{
		g_iSpecReplay = GetConVarInt(FindConVar("spec_replay_enable"));
		g_bCSGO	= true;
	}

	g_cDeathOverlay				= CreateConVar("sm_death_overlay_enable", "0", "Включить оверлей после смерти?",_,true,0.0,true,1.0);
	g_cDeathOverlayTimer		= CreateConVar("sm_death_overlay_time", "0.0", "Время в секундах СКОЛЬКО показывать оверлей игроку после смерти. Где 0.0 - показывать оверлей на все время пока игрок мертв.",_,true,0.0,true,20.0);
	g_cDeathOverlayPostTimer	= CreateConVar("sm_death_overlay_post_time", "0.0", "Время в секундах ЧЕРЕЗ СКОЛЬКО секунд ПОСЛЕ смерти показывать оверлей. Где 0.0 - мгновенно.",_,true,0.0,true,20.0);
	g_cPathToDeathOverlay		= CreateConVar("sm_death_path_overlay", "", "Путь к ОВЕРЛЕЮ после СМЕРТИ, БЕЗ папки materials/ и БЕЗ указания расширения.");

	g_cSpawnOverlay				= CreateConVar("sm_spawn_overlay_enable", "0", "Включить оверлей для игрока после каждого спавна?",_,true,0.0,true,1.0);
	g_cSpawnOverlayTimer		= CreateConVar("sm_spawn_overlay_time", "10.0", "Время в секундах, сколько показывать оверлей игроку при спавне. Где 0.0 - постоянно.",_,true,0.0,true,30.0);
	g_cPathToSpawnOverlay		= CreateConVar("sm_spawn_path_overlay", "", "Путь к ОВЕРЛЕЮ при СПАВНЕ, БЕЗ папки materials/ и БЕЗ указания расширения.");

	g_cWelcomeOverlay			= CreateConVar("sm_welcome_overlay_enable", "0", "Включить вступительный оверлей?",_,true,0.0,true,1.0);
	g_cWelcomeOverlayTimer		= CreateConVar("sm_welcome_overlay_time", "10.0", "Время в секундах, сколько показывать оверлей при заходе игрока?",_,true,0.0,true,30.0);
	g_cPathToWelcomeOverlay		= CreateConVar("sm_welcome_path_overlay", "", "Путь к ВСТУПИТЕЛЬНОМУ ОВЕРЛЕЮ, БЕЗ папки materials/ и БЕЗ указания расширения.");

	g_cFlagHide					= CreateConVar("sm_hide_overlay_flag", "", "Флаг, при наличии которого, пользователю не будут показываться оверлеи. Можно указывать несколько флагов, например bzaj.");
	g_cCmdOverlay				= CreateConVar("sm_cmd_overlay", "0", "1 - включить возможность игрокам отключать оверлеи через команду !overlay, 0 - отключить.",_,true,0.0,true,1.0);

	RegConsoleCmd("overlay", HideOverlayCmd);

	AutoExecConfig(true, "OverlaySystem");
}

public void OnMapStart()
{
	char file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof file, "configs/overlay_downloads.ini");
	File fileh = OpenFile(file, "r");
	if (fileh != null)
	{
		char sBuffer[256];
		char sBuffer_full[PLATFORM_MAX_PATH];

		while(ReadFileLine(fileh, sBuffer, sizeof sBuffer ))
		{
			TrimString(sBuffer);
			if ( sBuffer[0]  && sBuffer[0] != '/' && sBuffer[1] != '/' )
			{
				FormatEx(sBuffer_full, sizeof(sBuffer_full), "materials/%s", sBuffer);
				if (FileExists(sBuffer_full))
				{
					PrecacheDecal(sBuffer, true);
					AddFileToDownloadsTable(sBuffer_full);
					PrintToServer("[OS] All right, check your work!");
				}
				else
				{
					PrintToServer("[OS] File does not exist, check your path to overlay! %s", sBuffer_full);
				}
			}
		}
		delete fileh;

	}

}

public void Event_PlayerTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iUserId = hEvent.GetInt("userid");
	int iClient = GetClientOfUserId(iUserId);
	int OldTeam = GetEventInt(hEvent, "oldteam");

	if (OldTeam == 0)
	{
		g_bJoinOverlay[iClient] = true;
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	int iUserId = GetClientUserId(iClient);
	int l_EnableOverlayWelcome = g_cWelcomeOverlay.IntValue;
	float l_TimerWelcomeOverlay = g_cWelcomeOverlayTimer.FloatValue;

	GetConVarString(g_cFlagHide, g_szFlag, sizeof(g_szFlag));

	if(!iClient || IsFakeClient(iClient) || CheckAdminFlags(iClient, ReadFlagString(g_szFlag)))
	{
		return;
	}

	if(l_EnableOverlayWelcome == 1 && l_TimerWelcomeOverlay > 0.0)
		{
			g_hKillWelcomeTimer[iClient] = CreateTimer(10.0, Timer_ToWelcome, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		}
}


public Action Timer_ToWelcome (Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	int l_EnableOverlayWelcome = g_cWelcomeOverlay.IntValue;
	float l_TimerWelcomeOverlay = g_cWelcomeOverlayTimer.FloatValue;

	if(iClient)
	{
		ShowWelcomeOverlayToClient(iClient);
		CreateTimer(l_TimerWelcomeOverlay, Timer_WelcomeOverlay, iUserId, TIMER_FLAG_NO_MAPCHANGE);
	}
	if(l_EnableOverlayWelcome == 1 && g_hKillWelcomeTimer[iClient])
	{
		KillTimer(g_hKillWelcomeTimer[iClient]);
		g_hKillWelcomeTimer[iClient] = null;
	}
	return Plugin_Stop;
}

public Action Timer_WelcomeOverlay (Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);

	if(iClient && !g_hKillSpawnTimer[iClient])
	{
		ResetOverlayToClient(iClient);
	}
	return Plugin_Stop;
}

public void Event_PlayerDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int	iUserId = hEvent.GetInt("userid");
	int iClient = GetClientOfUserId(iUserId);
	int l_EnableOverlayDeath = g_cDeathOverlay.IntValue;
	int l_EnableOverlaySpawn = g_cSpawnOverlay.IntValue;
	float l_TimerPostOverlay = g_cDeathOverlayPostTimer.FloatValue;

	GetConVarString(g_cFlagHide, g_szFlag, sizeof(g_szFlag));

	ResetOverlayToClient(iClient);

	if(!iClient || IsFakeClient(iClient) || CheckAdminFlags(iClient, ReadFlagString(g_szFlag)) || g_bHideOverlay[iClient])
	{
	    return;
	}

	if(l_EnableOverlayDeath == 1)
	{
		if (g_iSpecReplay && g_bCSGO)
		{
			CreateTimer(9.3, Timer_Death, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		}
		else if (l_TimerPostOverlay > 0.0)
		{
			CreateTimer(l_TimerPostOverlay, Timer_PostOverlay, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		}
		if (!g_hKillWelcomeTimer[iClient])
		{
			ShowDeathOverlayToClient(iClient);
		}
	}
	if(l_EnableOverlaySpawn == 1 && g_hKillSpawnTimer[iClient])
	{
		KillTimer(g_hKillSpawnTimer[iClient]);
		g_hKillSpawnTimer[iClient] = null;
	}
	if(g_bJoinOverlay[iClient])
	{
		g_bJoinOverlay[iClient] = false;
	}
}

public Action Timer_Death (Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	float l_TimerPostOverlay = g_cDeathOverlayPostTimer.FloatValue;

	if(!iClient && !IsPlayerAlive(iClient))
	{
		return Plugin_Continue;
	}
	if(l_TimerPostOverlay == 0.0)
	{
		ShowDeathOverlayToClient(iClient);
	}
	if(l_TimerPostOverlay > 0.0)
	{
		CreateTimer(l_TimerPostOverlay, Timer_PostOverlay, iUserId, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action Timer_DeathOverlay (Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);

	if(iClient && !IsPlayerAlive(iClient))
	{
		ResetOverlayToClient(iClient);
	}
	return Plugin_Stop;
}

public Action Timer_PostOverlay (Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	int l_EnableOverlayDeath = g_cDeathOverlay.IntValue;
	float l_TimerDeath = g_cDeathOverlayTimer.FloatValue;

	if(iClient && !IsPlayerAlive(iClient))
	{
		ShowDeathOverlayToClient(iClient);

		if(l_TimerDeath > 0.0 && l_EnableOverlayDeath == 1)
		{
			CreateTimer(l_TimerDeath, Timer_DeathOverlay, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Stop;
}

public void Event_PlayerSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iUserId = hEvent.GetInt("userid");
	int iClient = GetClientOfUserId(iUserId);
	float l_SpawnOverlayTime = g_cSpawnOverlayTimer.FloatValue;
	int l_EnableOverlayDeath = g_cDeathOverlay.IntValue;
	int l_EnableOverlaySpawn = g_cSpawnOverlay.IntValue;

	GetConVarString(g_cFlagHide, g_szFlag, sizeof(g_szFlag));

	if(!iClient || IsFakeClient(iClient) || CheckAdminFlags(iClient, ReadFlagString(g_szFlag)) || g_bHideOverlay[iClient])
	{
	    return;
	}
	if(l_EnableOverlayDeath == 1 && l_EnableOverlaySpawn == 0)
	{
		ResetOverlayToClient(iClient);
	}
	if(g_bJoinOverlay[iClient])
	{
		g_bJoinOverlay[iClient] = false;
	}
	else if(l_EnableOverlaySpawn == 1 && !g_bJoinOverlay[iClient] && !g_hKillWelcomeTimer[iClient])
	{
		ShowSpawnOverlayToClient(iClient);

		if(l_SpawnOverlayTime > 0.0)
		{
			g_hKillSpawnTimer[iClient] = CreateTimer(l_SpawnOverlayTime, Timer_Spawn, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_Spawn (Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);

	if((iClient) && !IsFakeClient(iClient))
	{
		ResetOverlayToClient(iClient);
	}
	g_hKillSpawnTimer[iClient] = null;
	return Plugin_Stop;
}

bool CheckAdminFlags(int iClient, int g_iFlag)
{
    int iUserFlags = GetUserFlagBits(iClient);
    if(iUserFlags & g_iFlag)
        return true;
    else
        return false;
}

public Action HideOverlayCmd(int iClient, int args)
{
	int l_EnableHideOverlay = g_cCmdOverlay.IntValue;

	if(l_EnableHideOverlay == 0)
	{
		return Plugin_Stop;
	}
	else
	{
		g_bHideOverlay[iClient] = !(g_bHideOverlay[iClient]);

		if(g_bHideOverlay[iClient])
		{
			PrintToChat(iClient, "[OS] Вы деактивировали показ оверлеев.");
		}
		if(!g_bHideOverlay[iClient])
		{
			PrintToChat(iClient, "[OS] Вы активировали показ оверлеев.");
		}
	}

	return Plugin_Handled;
}

void ShowDeathOverlayToClient(int iClient)
{
	g_cPathToDeathOverlay.GetString(sOverlaypath, sizeof (sOverlaypath));
	ClientCommand(iClient, "r_screenoverlay \"%s\"", sOverlaypath);
}

void ShowSpawnOverlayToClient(int iClient)
{
	g_cPathToSpawnOverlay.GetString(sOverlaypath, sizeof (sOverlaypath));
	ClientCommand(iClient, "r_screenoverlay \"%s\"", sOverlaypath);
}

void ShowWelcomeOverlayToClient(int iClient)
{
	g_cPathToWelcomeOverlay.GetString(sOverlaypath, sizeof (sOverlaypath));
	ClientCommand(iClient, "r_screenoverlay \"%s\"", sOverlaypath);
}

void ResetOverlayToClient(int iClient)
{
	ClientCommand(iClient, "r_screenoverlay 0");
}
