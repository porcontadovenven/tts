#define MIXED_SPELLINGS

#include <open.mp>

#define COLOR_WHITE 0xFFFFFFFF
#define COLOR_GREEN 0x33AA33FF
#define COLOR_RED 0xAA3333FF
#define COLOR_YELLOW 0xFFFF00FF
#define COLOR_BLUE 0x3399FFFF

#define GROVE_SPAWN_X 2495.4172
#define GROVE_SPAWN_Y -1687.8528
#define GROVE_SPAWN_Z 13.5150
#define GROVE_SPAWN_A 2.9052
#define INTRO_MUSIC_URL "http://127.0.0.1:3001/intro.mp3"
#define NPC_HTTP_URL "127.0.0.1:3001/npc"

enum
{
    DIALOG_INVENTORY = 1000
}

new GroveNpcActor = INVALID_ACTOR_ID;
new PlayerText:IntroTitle[MAX_PLAYERS] = {PlayerText:INVALID_TEXT_DRAW, ...};
new PlayerText:IntroSubtitle[MAX_PLAYERS] = {PlayerText:INVALID_TEXT_DRAW, ...};

forward GiveStarterWeapon(playerid);
forward OnNpcResponse(playerid, responseCode, const data[]);

main()
{
    print("----------");
    print("Modo normal carregado.");
    print("----------");
}

stock bool:RequireAdmin(playerid)
{
    if(IsPlayerAdmin(playerid))
    {
        return true;
    }

    SendClientMessage(playerid, COLOR_RED, "Apenas admins RCON podem usar este comando.");
    SendClientMessage(playerid, COLOR_YELLOW, "Entre com: /rcon login sua_senha");
    return false;
}

stock bool:IsValidTarget(playerid, targetid)
{
    if(targetid < 0 || targetid >= MAX_PLAYERS || !IsPlayerConnected(targetid))
    {
        SendClientMessage(playerid, COLOR_RED, "Jogador invalido ou offline.");
        return false;
    }
    return true;
}

stock ApplyGroveStreetArea(playerid)
{
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
}

public GiveStarterWeapon(playerid)
{
    if(!IsPlayerConnected(playerid))
    {
        return 0;
    }

    ResetPlayerWeapons(playerid);
    GivePlayerWeapon(playerid, WEAPON_BRASSKNUCKLE, 1);
    SetPlayerArmedWeapon(playerid, WEAPON_BRASSKNUCKLE);
    return 1;
}

stock Float:GetForwardX(Float:angle, Float:distance)
{
    return distance * floatsin(-angle, degrees);
}

stock Float:GetForwardY(Float:angle, Float:distance)
{
    return distance * floatcos(-angle, degrees);
}

stock CastFireSpell(playerid)
{
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);

    x += GetForwardX(a, 8.0);
    y += GetForwardY(a, 8.0);
    CreateExplosion(x, y, z, 12, 3.0);
    SetPlayerChatBubble(playerid, "Ignis!", 0xFF6633FF, 35.0, 2500);
    return 1;
}

stock ShowWeaponInventory(playerid)
{
    ShowPlayerDialog(
        playerid,
        DIALOG_INVENTORY,
        DIALOG_STYLE_LIST,
        "Inventario de armas",
        "Soco ingles - magia\nTaco de baseball\nCassetete\nFaca\nKatana\nMotosserra\nPistola 9mm\nPistola silenciada\nDesert Eagle\nShotgun\nSawnoff Shotgun\nCombat Shotgun\nUzi\nMP5\nAK-47\nM4\nRifle\nSniper\nRPG\nLanca-chamas\nMinigun\nSpray\nExtintor\nParaquedas",
        "Escolher",
        "Fechar"
    );
    return 1;
}

stock GiveInventoryWeapon(playerid, listitem)
{
    new WEAPON:weaponid = WEAPON_FIST;
    new ammo = 1;

    switch(listitem)
    {
        case 0: { weaponid = WEAPON_BRASSKNUCKLE; ammo = 1; }
        case 1: { weaponid = WEAPON_BAT; ammo = 1; }
        case 2: { weaponid = WEAPON_NITESTICK; ammo = 1; }
        case 3: { weaponid = WEAPON_KNIFE; ammo = 1; }
        case 4: { weaponid = WEAPON_KATANA; ammo = 1; }
        case 5: { weaponid = WEAPON_CHAINSAW; ammo = 1; }
        case 6: { weaponid = WEAPON_COLT45; ammo = 500; }
        case 7: { weaponid = WEAPON_SILENCED; ammo = 500; }
        case 8: { weaponid = WEAPON_DEAGLE; ammo = 250; }
        case 9: { weaponid = WEAPON_SHOTGUN; ammo = 200; }
        case 10: { weaponid = WEAPON_SAWEDOFF; ammo = 200; }
        case 11: { weaponid = WEAPON_SHOTGSPA; ammo = 200; }
        case 12: { weaponid = WEAPON_UZI; ammo = 800; }
        case 13: { weaponid = WEAPON_MP5; ammo = 800; }
        case 14: { weaponid = WEAPON_AK47; ammo = 800; }
        case 15: { weaponid = WEAPON_M4; ammo = 800; }
        case 16: { weaponid = WEAPON_RIFLE; ammo = 200; }
        case 17: { weaponid = WEAPON_SNIPER; ammo = 100; }
        case 18: { weaponid = WEAPON_ROCKETLAUNCHER; ammo = 20; }
        case 19: { weaponid = WEAPON_FLAMETHROWER; ammo = 500; }
        case 20: { weaponid = WEAPON_MINIGUN; ammo = 1000; }
        case 21: { weaponid = WEAPON_SPRAYCAN; ammo = 500; }
        case 22: { weaponid = WEAPON_FIREEXTINGUISHER; ammo = 500; }
        case 23: { weaponid = WEAPON_PARACHUTE; ammo = 1; }
        default: return 0;
    }

    GivePlayerWeapon(playerid, weaponid, ammo);
    SetPlayerArmedWeapon(playerid, weaponid);
    SendClientMessage(playerid, COLOR_GREEN, "Arma equipada pelo inventario.");
    return 1;
}

stock CreateIntroTextdraws(playerid)
{
    if(IntroTitle[playerid] != PlayerText:INVALID_TEXT_DRAW)
    {
        return 1;
    }

    IntroTitle[playerid] = CreatePlayerTextDraw(playerid, 320.0, 145.0, "GROVE STREET");
    PlayerTextDrawAlignment(playerid, IntroTitle[playerid], TEXT_DRAW_ALIGN_CENTER);
    PlayerTextDrawLetterSize(playerid, IntroTitle[playerid], 0.75, 2.8);
    PlayerTextDrawFont(playerid, IntroTitle[playerid], TEXT_DRAW_FONT_2);
    PlayerTextDrawColour(playerid, IntroTitle[playerid], 0x33AA33FF);
    PlayerTextDrawSetOutline(playerid, IntroTitle[playerid], 1);
    PlayerTextDrawSetShadow(playerid, IntroTitle[playerid], 1);

    IntroSubtitle[playerid] = CreatePlayerTextDraw(playerid, 320.0, 185.0, "O soco ingles conjura bola de fogo");
    PlayerTextDrawAlignment(playerid, IntroSubtitle[playerid], TEXT_DRAW_ALIGN_CENTER);
    PlayerTextDrawLetterSize(playerid, IntroSubtitle[playerid], 0.28, 1.2);
    PlayerTextDrawFont(playerid, IntroSubtitle[playerid], TEXT_DRAW_FONT_1);
    PlayerTextDrawColour(playerid, IntroSubtitle[playerid], COLOR_WHITE);
    PlayerTextDrawSetOutline(playerid, IntroSubtitle[playerid], 1);
    return 1;
}

stock ShowIntro(playerid)
{
    CreateIntroTextdraws(playerid);
    PlayerTextDrawShow(playerid, IntroTitle[playerid]);
    PlayerTextDrawShow(playerid, IntroSubtitle[playerid]);
    SetPlayerCameraPos(playerid, 2478.4329, -1710.9310, 28.4379);
    SetPlayerCameraLookAt(playerid, 2495.9001, -1668.1289, 13.3438);
    GameTextForPlayer(playerid, "~g~Bem-vindo", 2500, 3);

    if(strlen(INTRO_MUSIC_URL) > 0)
    {
        PlayAudioStreamForPlayer(playerid, INTRO_MUSIC_URL);
    }
    return 1;
}

stock HideIntro(playerid)
{
    if(IntroTitle[playerid] != PlayerText:INVALID_TEXT_DRAW)
    {
        PlayerTextDrawHide(playerid, IntroTitle[playerid]);
        PlayerTextDrawHide(playerid, IntroSubtitle[playerid]);
    }
    StopAudioStreamForPlayer(playerid);
    SetCameraBehindPlayer(playerid);
    return 1;
}

public OnGameModeInit()
{
    SetGameModeText("Normal");
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_GLOBAL);
    ShowNameTags(true);
    EnableStuntBonusForAll(false);
    UsePlayerPedAnims();
    SetWeather(10);
    SetWorldTime(12);

    AddPlayerClass(0, GROVE_SPAWN_X, GROVE_SPAWN_Y, GROVE_SPAWN_Z, GROVE_SPAWN_A, WEAPON_BRASSKNUCKLE, 1, WEAPON_FIST, 0, WEAPON_FIST, 0);
    AddStaticVehicle(411, 2488.8799, -1683.0916, 13.3381, 270.0, 1, 1);
    AddStaticVehicle(451, 2508.6147, -1672.3223, 13.2001, 90.0, 3, 3);
    AddStaticVehicle(522, 2514.8354, -1687.2024, 13.1967, 90.0, 6, 6);

    GroveNpcActor = CreateActor(105, 2495.9001, -1668.1289, 13.3438, 180.0);
    SetActorInvulnerable(GroveNpcActor, true);
    return 1;
}

public OnPlayerConnect(playerid)
{
    SendClientMessage(playerid, COLOR_GREEN, "Bem-vindo ao servidor.");
    SendClientMessage(playerid, COLOR_WHITE, "Use /help para ver os comandos.");
    SendClientMessage(playerid, COLOR_YELLOW, "O soco ingles dispara bola de fogo.");
    if(strlen(INTRO_MUSIC_URL) > 0)
    {
        PlayAudioStreamForPlayer(playerid, INTRO_MUSIC_URL);
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(IntroTitle[playerid] != PlayerText:INVALID_TEXT_DRAW)
    {
        PlayerTextDrawDestroy(playerid, IntroTitle[playerid]);
        PlayerTextDrawDestroy(playerid, IntroSubtitle[playerid]);
        IntroTitle[playerid] = PlayerText:INVALID_TEXT_DRAW;
        IntroSubtitle[playerid] = PlayerText:INVALID_TEXT_DRAW;
    }
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    SetPlayerPos(playerid, GROVE_SPAWN_X, GROVE_SPAWN_Y, GROVE_SPAWN_Z);
    SetPlayerFacingAngle(playerid, GROVE_SPAWN_A);
    SetPlayerCameraPos(playerid, 2495.8044, -1697.6389, 18.1518);
    SetPlayerCameraLookAt(playerid, GROVE_SPAWN_X, GROVE_SPAWN_Y, GROVE_SPAWN_Z);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    ApplyGroveStreetArea(playerid);
    SetPlayerColor(playerid, COLOR_BLUE);
    SetPlayerPos(playerid, GROVE_SPAWN_X, GROVE_SPAWN_Y, GROVE_SPAWN_Z);
    SetPlayerFacingAngle(playerid, GROVE_SPAWN_A);
    HideIntro(playerid);
    GivePlayerMoney(playerid, 5000);
    GiveStarterWeapon(playerid);
    SetTimerEx("GiveStarterWeapon", 500, false, "i", playerid);
    SetTimerEx("GiveStarterWeapon", 1500, false, "i", playerid);
    return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    SendDeathMessage(killerid, playerid, reason);
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    new cmd[32], params[96];
    SplitCommand(cmdtext, cmd, sizeof cmd, params, sizeof params);

    if(!strcmp(cmd, "/help", true))
    {
        SendClientMessage(playerid, COLOR_YELLOW, "Comandos: /inv, /npc, /kill, /grove, /intro, /stopmusic, /admins, /adminhelp");
        SendClientMessage(playerid, COLOR_WHITE, "Admin RCON: /veh, /fix, /hp, /armour, /weap, /money, /goto, /bring");
        return 1;
    }

    if(!strcmp(cmd, "/inv", true) || !strcmp(cmd, "/inventario", true) || !strcmp(cmd, "/armas", true))
    {
        ShowWeaponInventory(playerid);
        return 1;
    }

    if(!strcmp(cmd, "/npc", true))
    {
        if(strlen(params) < 2)
        {
            SendClientMessage(playerid, COLOR_YELLOW, "Uso: /npc sua mensagem para o NPC.");
            return 1;
        }

        SendClientMessage(playerid, COLOR_YELLOW, "NPC esta pensando...");
        HTTP(playerid, HTTP_POST, NPC_HTTP_URL, params, "OnNpcResponse");
        return 1;
    }

    if(!strcmp(cmd, "/intro", true))
    {
        ShowIntro(playerid);
        return 1;
    }

    if(!strcmp(cmd, "/stopmusic", true))
    {
        StopAudioStreamForPlayer(playerid);
        SendClientMessage(playerid, COLOR_GREEN, "Musica parada.");
        return 1;
    }

    if(!strcmp(cmd, "/kill", true))
    {
        SetPlayerHealth(playerid, 0.0);
        return 1;
    }

    if(!strcmp(cmd, "/grove", true))
    {
        ApplyGroveStreetArea(playerid);
        SetPlayerPos(playerid, GROVE_SPAWN_X, GROVE_SPAWN_Y, GROVE_SPAWN_Z);
        SetPlayerFacingAngle(playerid, GROVE_SPAWN_A);
        SetCameraBehindPlayer(playerid);
        SendClientMessage(playerid, COLOR_GREEN, "Voce voltou para Grove Street.");
        return 1;
    }

    if(!strcmp(cmd, "/admins", true))
    {
        new count = 0, name[MAX_PLAYER_NAME + 1], message[96];
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(IsPlayerConnected(i) && IsPlayerAdmin(i))
            {
                GetPlayerName(i, name, sizeof name);
                format(message, sizeof message, "Admin online: %s (ID %d)", name, i);
                SendClientMessage(playerid, COLOR_GREEN, message);
                count++;
            }
        }
        if(!count)
        {
            SendClientMessage(playerid, COLOR_YELLOW, "Nenhum admin online.");
        }
        return 1;
    }

    if(!strcmp(cmd, "/adminhelp", true))
    {
        SendClientMessage(playerid, COLOR_YELLOW, "Entre como admin com: /rcon login sua_senha");
        SendClientMessage(playerid, COLOR_WHITE, "/veh [modelo] [cor1] [cor2] - cria veiculo. Ex: /veh 411 1 1");
        SendClientMessage(playerid, COLOR_WHITE, "/fix, /hp [id] [vida], /armour [id] [colete], /weap [id] [arma] [municao]");
        SendClientMessage(playerid, COLOR_WHITE, "/money [id] [valor], /goto [id], /bring [id]");
        return 1;
    }

    if(!strcmp(cmd, "/veh", true) || !strcmp(cmd, "/car", true))
    {
        if(!RequireAdmin(playerid)) return 1;

        new modelid = 0, color1 = 1, color2 = 1;
        if(sscanf_iii(params, modelid, color1, color2) < 1 || modelid < 400 || modelid > 611)
        {
            SendClientMessage(playerid, COLOR_YELLOW, "Uso: /veh [modelo 400-611] [cor1] [cor2]. Ex: /veh 411 1 1");
            return 1;
        }

        new Float:x, Float:y, Float:z, Float:a;
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, a);

        new vehicleid = CreateVehicle(modelid, x + 3.0, y, z + 0.5, a, color1, color2, -1);
        PutPlayerInVehicle(playerid, vehicleid, 0);
        SendClientMessage(playerid, COLOR_GREEN, "Veiculo criado.");
        return 1;
    }

    if(!strcmp(cmd, "/fix", true))
    {
        if(!RequireAdmin(playerid)) return 1;
        if(!IsPlayerInAnyVehicle(playerid))
        {
            SendClientMessage(playerid, COLOR_YELLOW, "Voce precisa estar em um veiculo.");
            return 1;
        }
        RepairVehicle(GetPlayerVehicleID(playerid));
        SendClientMessage(playerid, COLOR_GREEN, "Veiculo reparado.");
        return 1;
    }

    if(!strcmp(cmd, "/hp", true))
    {
        if(!RequireAdmin(playerid)) return 1;

        new targetid = playerid, amount = 100;
        sscanf_ii(params, targetid, amount);
        if(!IsValidTarget(playerid, targetid)) return 1;

        SetPlayerHealth(targetid, float(amount));
        SendClientMessage(playerid, COLOR_GREEN, "Vida alterada.");
        return 1;
    }

    if(!strcmp(cmd, "/armour", true) || !strcmp(cmd, "/armor", true))
    {
        if(!RequireAdmin(playerid)) return 1;

        new targetid = playerid, amount = 100;
        sscanf_ii(params, targetid, amount);
        if(!IsValidTarget(playerid, targetid)) return 1;

        SetPlayerArmour(targetid, float(amount));
        SendClientMessage(playerid, COLOR_GREEN, "Colete alterado.");
        return 1;
    }

    if(!strcmp(cmd, "/weap", true) || !strcmp(cmd, "/weapon", true))
    {
        if(!RequireAdmin(playerid)) return 1;

        new targetid, weaponid, ammo = 500;
        if(sscanf_iii(params, targetid, weaponid, ammo) < 2)
        {
            SendClientMessage(playerid, COLOR_YELLOW, "Uso: /weap [id] [arma] [municao]. Ex: /weap 0 31 500");
            return 1;
        }
        if(!IsValidTarget(playerid, targetid)) return 1;

        GivePlayerWeapon(targetid, WEAPON:weaponid, ammo);
        SendClientMessage(playerid, COLOR_GREEN, "Arma entregue.");
        return 1;
    }

    if(!strcmp(cmd, "/money", true))
    {
        if(!RequireAdmin(playerid)) return 1;

        new targetid, amount;
        if(sscanf_ii(params, targetid, amount) < 2)
        {
            SendClientMessage(playerid, COLOR_YELLOW, "Uso: /money [id] [valor]. Ex: /money 0 10000");
            return 1;
        }
        if(!IsValidTarget(playerid, targetid)) return 1;

        GivePlayerMoney(targetid, amount);
        SendClientMessage(playerid, COLOR_GREEN, "Dinheiro entregue.");
        return 1;
    }

    if(!strcmp(cmd, "/goto", true))
    {
        if(!RequireAdmin(playerid)) return 1;

        new targetid;
        if(sscanf_i(params, targetid) < 1 || !IsValidTarget(playerid, targetid)) return 1;

        new Float:x, Float:y, Float:z;
        GetPlayerPos(targetid, x, y, z);
        SetPlayerInterior(playerid, GetPlayerInterior(targetid));
        SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
        SetPlayerPos(playerid, x + 1.5, y, z);
        SendClientMessage(playerid, COLOR_GREEN, "Teleportado.");
        return 1;
    }

    if(!strcmp(cmd, "/bring", true))
    {
        if(!RequireAdmin(playerid)) return 1;

        new targetid;
        if(sscanf_i(params, targetid) < 1 || !IsValidTarget(playerid, targetid)) return 1;

        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);
        SetPlayerInterior(targetid, GetPlayerInterior(playerid));
        SetPlayerVirtualWorld(targetid, GetPlayerVirtualWorld(playerid));
        SetPlayerPos(targetid, x + 1.5, y, z);
        SendClientMessage(playerid, COLOR_GREEN, "Jogador puxado.");
        return 1;
    }

    SendClientMessage(playerid, COLOR_RED, "Comando invalido. Use /help.");
    return 1;
}

public OnNpcResponse(playerid, responseCode, const data[])
{
    if(!IsPlayerConnected(playerid))
    {
        return 1;
    }

    if(responseCode != 200)
    {
        SendClientMessage(playerid, COLOR_RED, "NPC indisponivel no momento.");
        return 1;
    }

    new separator = strfind(data, "|", true);
    new answer[192], audioUrl[160];

    if(separator == -1)
    {
        format(answer, sizeof answer, "NPC: %s", data);
        SendClientMessage(playerid, COLOR_GREEN, answer);
        return 1;
    }

    strmid(answer, data, 0, separator, sizeof answer);
    strmid(audioUrl, data, separator + 1, strlen(data), sizeof audioUrl);

    new message[220];
    format(message, sizeof message, "NPC: %s", answer);
    SendClientMessage(playerid, COLOR_GREEN, message);

    if(strlen(audioUrl) > 8)
    {
        PlayAudioStreamForPlayer(playerid, audioUrl);
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_INVENTORY)
    {
        if(response)
        {
            GiveInventoryWeapon(playerid, listitem);
        }
        return 1;
    }

    return 0;
}

public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    if((newkeys & KEY_FIRE) && !(oldkeys & KEY_FIRE) && GetPlayerWeapon(playerid) == WEAPON_BRASSKNUCKLE)
    {
        return CastFireSpell(playerid);
    }

    return 1;
}

stock SplitCommand(const text[], cmd[], cmdSize, params[], paramsSize)
{
    new i = 0, j = 0;

    while(text[i] > ' ' && j < cmdSize - 1)
    {
        cmd[j++] = text[i++];
    }
    cmd[j] = '\0';

    while(text[i] == ' ')
    {
        i++;
    }

    j = 0;
    while(text[i] != '\0' && j < paramsSize - 1)
    {
        params[j++] = text[i++];
    }
    params[j] = '\0';
    return 1;
}

stock sscanf_i(const input[], &value1)
{
    new index = 0;
    return ReadInt(input, index, value1);
}

stock sscanf_ii(const input[], &value1, &value2)
{
    new index = 0, count = 0;
    count += ReadInt(input, index, value1);
    count += ReadInt(input, index, value2);
    return count;
}

stock sscanf_iii(const input[], &value1, &value2, &value3)
{
    new index = 0, count = 0;
    count += ReadInt(input, index, value1);
    count += ReadInt(input, index, value2);
    count += ReadInt(input, index, value3);
    return count;
}

stock ReadInt(const input[], &index, &value)
{
    while(input[index] == ' ')
    {
        index++;
    }

    if(input[index] == '\0')
    {
        return 0;
    }

    new sign = 1;
    if(input[index] == '-')
    {
        sign = -1;
        index++;
    }

    if(input[index] < '0' || input[index] > '9')
    {
        return 0;
    }

    value = 0;
    while(input[index] >= '0' && input[index] <= '9')
    {
        value = (value * 10) + (input[index] - '0');
        index++;
    }
    value *= sign;
    return 1;
}
