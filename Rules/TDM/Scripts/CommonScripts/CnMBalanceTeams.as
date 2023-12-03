// Weighted team balancing for BOT n PLAYER by Koi

#include "BaseTeamInfo.as";
#include "RulesCore.as";

#define SERVER_ONLY

const float PLAYER_TO_BOT_RATIO =  3.0f / 3.0f; // mice / BOTs

void onInit(CRules@ this)
{
	this.set_u32("match_count", 0);
	this.set_bool("managed teams", true); // core shouldn't try to manage the teams
	onRestart(this);
}

void onRestart(CRules@ this)
{
	BalanceAll(this);

	this.add_u32("match_count", 1);

	Random@ r_seed = Random(Maths::Pow(this.get_u32("match_count"), 2));

	int rnd = r_seed.NextRanged(100);
	bool left = rnd < 50; // left team = players team

	this.set_u8("ply_team_next", left ? 1 : 0);
	this.set_u8("bot_team_next", left ? 0 : 1);

	// always 0 ply 1 bot on first match
	warn("current match teams: "+this.get_u8("ply_team")+" / bot "+this.get_u8("bot_team"));
	warn("next match teams: ply "+this.get_u8("ply_team_next")+" / bot "+this.get_u8("bot_team_next"));
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

s32 getSmallestWeightedTeam(CPlayer@ player, BaseTeamInfo@[]@ teams)
{
	if (player !is null)
	{
		CRules@ rules = getRules();
		u8 ply_team = rules.get_u8("ply_team_next");
		u8 bot_team = rules.get_u8("bot_team_next");
		
		int team = player.isBot() ? bot_team : ply_team;
		error("assigning new team to player: "+player.getUsername()+" "+team);
		return team;
	}
	// else return default random
	return (teams[0].players_count - (teams[1].players_count + 1) / PLAYER_TO_BOT_RATIO) < -0.0001f ? 0 : 1;
}

void BalanceAll(CRules@ this)
{
	getNet().server_SendMsg("Scrambling the teams...");

	// this is running before onRestart(), probably even if i change code blocks order? will test
	// yea probably, who knows kag, but the call order may be different in engine (for onrestart and something that runs balanceall())
	if (this.exists("ply_team_next"))
	{
		this.set_u8("ply_team", this.get_u8("ply_team_next"));
		this.set_u8("bot_team", this.get_u8("bot_team_next"));
	}
	else
	{
		this.set_u8("ply_team", 0);
		this.set_u8("bot_team", 1);
	}

	RulesCore@ core;
	this.get("core", @core);

	if(core !is null)
	{
		int playerCount = getPlayerCount();

		string[] playerNames;

		for (int i = 0; i < playerCount; i++)
		{
			playerNames.push_back(getPlayer(i).getUsername());
		}

		for(int i = 0; i < playerCount; i++)
		{
			int playerIndex = XORRandom(playerCount - i);

			CPlayer@ player = getPlayerByUsername(playerNames[playerIndex]);
			playerNames.removeAt(playerIndex);

			if (player.getTeamNum() != this.getSpectatorTeamNum())
			{
				core.ChangePlayerTeam(player, getSmallestWeightedTeam(player, core.teams));
			}
		}
	}
}