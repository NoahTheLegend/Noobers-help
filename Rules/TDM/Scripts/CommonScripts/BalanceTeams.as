// Weighted team balancing for BOT n PLAYER by Koi

#include "BaseTeamInfo.as";
#include "RulesCore.as";
#include "BotVars.as";

#define SERVER_ONLY

const float PLAYER_TO_BOT_RATIO =  1.0f; // used by old code
const float BOT_RATIO_PER_PLAYER = 0.0f; // add N amount of bots (rounded to floor) per player, negative value works oppositely

void onInit(CRules@ this)
{
	this.set_u32("match_count", 0);
	this.set_bool("managed teams", true); // core shouldn't try to manage the teams
	onRestart(this);
}

void onRestart(CRules@ this)
{
	this.add_u32("match_count", 1);

	Random@ r_seed = Random(Maths::Pow(this.get_u32("match_count"), 2));

	int rnd = r_seed.NextRanged(100);
	bool left = rnd < 50; // left team = players team

	u8 ply_team = left ? 1 : 0;
	u8 bot_team = left ? 0 : 1;

	this.set_s8("ply_team", ply_team);
	this.set_u8("bot_team", bot_team);

	// always 0 ply 1 bot on first match
	warn("current match teams: plys "+this.get_s8("ply_team")+" / bots "+this.get_u8("bot_team"));

	BalanceAll(this);
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	RulesCore@ core;
	this.get("core", @core);

	if (core !is null)
	{
		core.ChangePlayerTeam(player, getSmallestWeightedTeam(player, core.teams));
	}
}

void onPlayerRequestTeamChange(CRules@ this, CPlayer@ player, u8 newTeam)
{
	RulesCore@ core;
	this.get("core", @core);

	if (core !is null)
	{
		if (newTeam == 255) // auto-assign when a player changes to team 255 (-1)
		{
			newTeam = getSmallestWeightedTeam(player, core.teams);
		}

		core.ChangePlayerTeam(player, newTeam);
	}
}

int fill = 0;

s32 getSmallestWeightedTeam(CPlayer@ player, BaseTeamInfo@[]@ teams)
{
	if (player !is null)
	{
		CRules@ rules = getRules();
		u8 ply_team = rules.get_s8("ply_team");
		u8 bot_team = rules.get_u8("bot_team");
		
		int team = 0;
		if (player.isBot())
		{
			player.server_setCharacterName("Enemy");
			if (fill>0)
			{
				player.server_setCharacterName("Ally");
				team = ply_team;
				fill--;
			}
			else team = bot_team;
		}
		else team = ply_team;


		error("assigning new team to player: "+player.getUsername()+" "+team);
		return team;
	}
	// else return default random
	return (teams[0].players_count - (teams[1].players_count + 1) / PLAYER_TO_BOT_RATIO) < -0.0001f ? 0 : 1;
}

void BalanceAll(CRules@ this)
{
	s8 plys = 0;
	for (u8 i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ p = getPlayer(i);
		if (p is null || p.getTeamNum() == this.getSpectatorTeamNum() || p.isBot()) continue;
		plys++;
	}

	fill = getPlayersCount()/2-plys-(Maths::Floor(f32(plys)*BOT_RATIO_PER_PLAYER));
	getNet().server_SendMsg("Scrambling the teams...");

	RulesCore@ core;
	this.get("core", @core);
	CRules@ rules = getRules();

	if(core !is null)
	{
		int playerCount = getPlayerCount();

		string[] playerNames;

		int remaining = 0;

		for (int i = 0; i < playerCount; i++)
		{
			CPlayer@ p = getPlayer(i);
			if (p.isBot()) playerNames.push_back(p.getUsername());
			else playerNames.insertAt(0, p.getUsername());
		}

		for(int i = 0; i < playerNames.size(); i++)
		{
			CPlayer@ player = getPlayerByUsername(playerNames[i]);

			if (player.getTeamNum() != this.getSpectatorTeamNum())
			{
				core.ChangePlayerTeam(player, getSmallestWeightedTeam(player, core.teams));
			}
		}
	}
}

