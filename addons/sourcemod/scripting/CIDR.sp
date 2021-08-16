#pragma semicolon 1

#include <multicolors>

#pragma newdecls required

#define CHAT_PREFIX     "{fullred}[CIDR]{white}"

#define PLUGIN_VERSION  "2.2"

public Plugin myinfo = 
{
	name        = "CIDR Block",
	author      = "Bottiger, maxime1907",
	description = "Block IPS with CIDR notation",
	version     = PLUGIN_VERSION,
	url         = "http://skial.com"
};

bool g_late, g_loaded;

Handle g_path, g_min, g_max, g_expire;
ConVar g_cRejectMsg;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_late = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    CreateConVar("sm_cidr_version", PLUGIN_VERSION, "Block CIDR", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

    g_path = CreateConVar("sm_cidr_path", "configs/cidrblock.cfg", "Path to block list.");
    g_cRejectMsg = CreateConVar("sm_cidr_reject_message", "You are banned from this server", "Message that banned users will see.");

    RegAdminCmd("sm_cidr_reload", Command_Reload, ADMFLAG_BAN, "Clear banlist and reload bans from file.");
    RegAdminCmd("sm_cidr_add", Command_Add, ADMFLAG_RCON, "Add CIDR to banlist.");

    g_min = CreateArray();
    g_max = CreateArray();
    g_expire = CreateArray();
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
    bool blocked = IsBlocked(client);

    if (blocked)
    {
        char myRejectMsg[255];
        g_cRejectMsg.GetString(myRejectMsg, sizeof(myRejectMsg));
        strcopy(rejectmsg, sizeof(myRejectMsg), myRejectMsg);
    }
    return !blocked;
}

public void OnConfigsExecuted()
{
    CIDR_Load();
}

public Action Command_Reload(int client, int args)
{
    CIDR_Reload();

    if (IsValidClient(client))
    {
        char target[PLATFORM_MAX_PATH];
        GetConVarString(g_path, target, sizeof(target));

        CPrintToChat(client, "%s Cleared cached banlist and reloaded %s.", CHAT_PREFIX, target);
    }

    return Plugin_Handled;
}

public Action Command_Add(int client, int args)
{
    char cmd[32];
    char ipRange[32];
    char sTime[32];
    char playerName[64];
    char reason[255];

    if (args < 4)
    {
        if (IsValidClient(client))
        {
            GetCmdArg(0, cmd, sizeof(cmd));
            CPrintToChat(client, "%s Usage: {cyan}%s 1.2.3.4/30 10800 \"Boss\" \"Using AimBot + SpinHack\"", CHAT_PREFIX, cmd);
            CPrintToChat(client, "%s IP Range helper", CHAT_PREFIX);
            CPrintToChat(client, "{cyan}1.2.3.4/30 {white}(blocks 1.2.3.4 - 1.2.3.4) (PC)");
            CPrintToChat(client, "{cyan}1.2.3.4/24 {white}(blocks 1.2.3.0 - 1.2.3.255) (Router/House)");
            CPrintToChat(client, "{cyan}1.2.3.4/16 {white}(blocks 1.2.0.0 - 1.2.255.255) (City)");
            CPrintToChat(client, "{cyan}1.2.3.4/8 {white}(blocks 1.0.0.0 - 1.255.255.255) (State)");
        }
        return Plugin_Handled;
    }

    GetCmdArg(1, ipRange, sizeof(ipRange));
    TrimString(ipRange);

    GetCmdArg(2, sTime, sizeof(sTime));
    TrimString(sTime);
    int iTime = StringToInt(sTime);

    GetCmdArg(3, playerName, sizeof(playerName));

    GetCmdArg(4, reason, sizeof(reason));

    if (!AddIP(ipRange, iTime, playerName, reason, client))
        return  Plugin_Handled;

    if (IsValidClient(client))
        CPrintToChat(client, "%s Successfully added ip range {cyan}%s", CHAT_PREFIX, ipRange);

    CIDR_Reload();

    return Plugin_Handled;
}

public void CIDR_Reload()
{
    g_loaded = false;
    g_late = true;

    ClearArray(g_min);
    ClearArray(g_max);
    ClearArray(g_expire);

    CIDR_Load();
}

public void CIDR_Load()
{
    if(!g_loaded)
    {
        g_loaded = true;
        ParseFile();

        if(g_late)
        {
            for (int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i) || IsFakeClient(i))
                    continue;

                if (IsBlocked(i))
                {
                    char myRejectMsg[255];
                    g_cRejectMsg.GetString(myRejectMsg, sizeof(myRejectMsg));
                    KickClient(i, myRejectMsg);
                }
            }
        }
    }
}

stock void ParseFile()
{
    char target[PLATFORM_MAX_PATH];
    char path[PLATFORM_MAX_PATH];
    char line[1024];

    Handle hFile;

    GetConVarString(g_path, target, sizeof(target));
    
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, target);
    hFile = OpenFile(path, "a+r");

    if (hFile == INVALID_HANDLE)
    {
        LogError("Error while trying to create %s", target);
        return;
    }

    while (!IsEndOfFile(hFile) && ReadFileLine(hFile, line, sizeof(line)))
    {
        TrimString(line);
        if(line[0] == '#' || line[0] == '\x00')
            continue;
        
        ParseCIDR(line);
    }

    CloseHandle(hFile);
}

stock bool IsBlocked(int client)
{
    char ip[17];
    GetClientIP(client, ip, sizeof(ip));

    int ipn = inet_aton(ip);
    int entries = GetArraySize(g_min);

    int time = GetTime();

    for (int i = 0; i < entries; i++)
    {
        int min = GetArrayCell(g_min, i);
        int max = GetArrayCell(g_max, i);
        if (ipn >= min && ipn <= max)
        {
            int expire = GetArrayCell(g_expire, i);
            if (expire == 0 || time < expire)
                return true;
        }
    }

    return false;
}

stock bool AddIP(const char[] cidr_string, int time, const char[] playerName, const char[] reason, int adminId)
{
    char target[PLATFORM_MAX_PATH];
    char path[PLATFORM_MAX_PATH];

    Handle hFile;

    GetConVarString(g_path, target, sizeof(target));

    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, target);
    hFile = OpenFile(path, "a+w");

    if (hFile == INVALID_HANDLE)
    {
        LogError("Error while trying to create %s", target);
        return false;
    }

    int currentTime = GetTime();
    int expires = currentTime + (time * 60);
    if (expires < 0 || expires < currentTime)
    {
        if (IsValidClient(adminId))
        {
            CPrintToChat(adminId, "%s Invalid timestamp calculated (Time:{cyan}%d, Timestamp:%d)", CHAT_PREFIX, time, expires);
            CPrintToChat(adminId, "%s If you are willing to permaban someone, please use a time value of 0", CHAT_PREFIX);
        }
        return false;
    }

    if (time == 0) // Permaban
        expires = 0;

    if (!ParseCIDR(cidr_string, true))
    {
        if (IsValidClient(adminId))
        {
            CPrintToChat(adminId, "%s Invalid address/mask provided", CHAT_PREFIX);
            CPrintToChat(adminId, "%s Please verify the ip and range that you provided", CHAT_PREFIX);
        }
        return false;
    }

    char adminSteamID[64];
    char adminName[64];
    if (!GetClientAuthId(adminId, AuthId_Steam2, adminSteamID, sizeof(adminSteamID)))
        Format(adminSteamID, sizeof(adminSteamID), "STEAMID_ERROR");
    if (!GetClientName(adminId, adminName, sizeof(adminName)))
        Format(adminName, sizeof(adminName), "NAME_ERROR");

    WriteFileLine(hFile, "%s %d Player: %s Reason: %s AdminSteamID: %s AdminName: %s", cidr_string, expires, playerName, reason, adminSteamID, adminName);

    CloseHandle(hFile);

    return true;
}

stock bool ParseCIDR(const char[] cidr_string, bool testParsing = false)
{
    char cidr[2][19];
    char ip[2][17];

    ExplodeString(cidr_string, " ", cidr, 3, 19);
    ExplodeString(cidr[0], "/", ip, 2, 17);

    int baseip = inet_aton(ip[0]);
    int prefix = StringToInt(ip[1]);
    int expire = StringToInt(cidr[1]);

    if (prefix == 0)
    {
        if (testParsing)
            return false;
        LogError("CIDR prefix 0, clamping to 32. %s", cidr[0]);
        prefix = 32;
    }

    if (testParsing)
        return true;

    int shift = 32 - prefix;
    int mask  = (1 << shift) - 1;
    int start = baseip >> shift << shift;
    int end   = start | mask;

    PushArrayCell(g_min, start);
    PushArrayCell(g_max, end);
    PushArrayCell(g_expire, expire);

    return true;
}

stock int inet_aton(const char[] ip)
{
    char pieces[4][16];
    int nums[4];

    if (ExplodeString(ip, ".", pieces, 4, 16) != 4)
        return 0;

    nums[0] = StringToInt(pieces[0]);
    nums[1] = StringToInt(pieces[1]);
    nums[2] = StringToInt(pieces[2]);
    nums[3] = StringToInt(pieces[3]);

    return ((nums[0] << 24) | (nums[1] << 16) | (nums[2] << 8) | nums[3]);
}

stock bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}