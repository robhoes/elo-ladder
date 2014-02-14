// compare function for sorting
function compare(a, b)
{
	if (a < b) return -1;
	if (a > b) return 1;
	return 0;
}

function bold(s)
{
	return '<strong>' + s + '</strong>';
}

function make_table(rows, header)
{
	var table = document.createElement('table');
	var head = true;

	function make_tr(row)
	{
		var tr = document.createElement('tr');
		table.appendChild(tr);

		function make_td(x)
		{
			var td = document.createElement(head == true ? 'th' : 'td');
			td.innerHTML = x
			tr.appendChild(td);
		}
		row.forEach(make_td);

		return tr;
	}
	make_tr(header);
	head = false;
	rows.forEach(make_tr);

	return table
}

function build_ladder()
{
	var div = document.getElementById('results');
	div.innerHTML = "<h2>Ladder</h2>";

	players.sort(function(a, b){return -compare(a.ratings[0], b.ratings[0])});
	var active_players = players.filter(function(a){return a.active});
	var inactive_players = players.filter(function(a){return !a.active});

	function build_rows(ps, active)
	{
		var i = 1;
		var rows = ps.map(function(p){
			var last = p.ratings[0];
			var diff = Math.round(last - p.ratings[1]);
			if (active)
				return [
					i++,
					p.name,
					Math.round(last),
					'<span class=' + (diff > 0 ? '"up">+' : '"down">') + diff + '</span>',
					p.points_won + " / " + p.game_count
				]
			else
				return [
					p.name,
					Math.round(last),
					p.points_won + " / " + p.game_count
				]
		}
		);
		return rows;
	}

	var rows = build_rows(active_players, true);
	var table = make_table(rows, ["Rank", "Name", "Rating", "Diff", "Score / Games"]);
	div.appendChild(table);

	div.innerHTML += "<h2>Retired Players</h2>";
	var rows = build_rows(inactive_players, false);
	var table = make_table(rows, ["Name", "Rating", "Score / Games"]);
	div.appendChild(table);
}

function string_of_result(result)
{
	switch(result) {
	case 1: return "1 - 0"
	case 0: return "0 - 1"
	default: return "0.5 - 0.5"
	}
}

function refresh_games_table(div, x)
{
	var filtered_games = games.filter(function(g){
		return x == "" || g.name1 == x || g.name2 == x});

	var rows = filtered_games.reverse().map(function(p){
		return [
			p.date,
			p.name1,
			p.name2,
			string_of_result(p.result)
		]}
	);

	var table = make_table(rows, ["Date", "White", "Black", "Result"]);
	if (div.hasChildNodes())
		div.removeChild(div.firstChild);
	div.appendChild(table);
}

function build_names_menu(menu, onchange)
{
	menu.onchange = onchange;

	var option = document.createElement("option");
	option.value = "";
	option.innerHTML = "All";
	menu.appendChild(option);

	var names = players.map(function(p){return p.name});
	names.sort();
	names.map(function(n){
		var option = document.createElement("option");
		option.value = n;
		option.innerHTML = n;
		menu.appendChild(option);
	});
}

function build_games()
{
	var div = document.getElementById("results");
	div.innerHTML = "<h2>Past Games</h2>";

	var menu = document.createElement("select");
	div.appendChild(menu);

	var games_table = document.createElement("div");
	div.appendChild(games_table);

	build_names_menu(menu, function(){refresh_games_table(games_table, this.value)});

	refresh_games_table(games_table, "");
}

function build_suggestions()
{
	var div = document.getElementById("results");
	div.innerHTML = "<h2>Next Games</h2>";

	var rows = suggestions.map(function(p){
		return [
			p.name1,
			p.name2
		]}
	);

	var table = make_table(rows, ["White", "Black"]);
	div.appendChild(table);
}

function refresh_stats_table(div, x)
{
	var filtered_stats = stats.filter(function(s){
		return x == "" || s.name1 == x || s.name2 == x});

	var count = 0, wins = 0, draws = 0, losses = 0, balance = 0;
	var rows = filtered_stats.map(function(p){
		count += p.count;
		draws += p.draws;
		if (p.name2 == x) {
			wins += p.losses;
			losses += p.wins;
			balance -= p.balance;
			return [
				p.name2,
				p.name1,
				p.count,
				p.losses,
				p.draws,
				p.wins,
				-p.balance
			]
		}
		else {
			wins += p.wins;
			losses += p.losses;
			balance += p.balance;
			return [
				p.name1,
				p.name2,
				p.count,
				p.wins,
				p.draws,
				p.losses,
				p.balance
			]
		}
	});
	rows.push(["", "", bold(count), bold(wins), bold(draws), bold(losses), bold(balance)]);

	var table = make_table(rows, ["Player 1", "Player 2", "Games", "Wins*", "Draws*", "Losses*", "Colour Balance**"]);
	if (div.hasChildNodes()) {
		div.removeChild(div.firstChild);
		div.removeChild(div.firstChild);
	}
	div.appendChild(table);

	div.innerHTML += "<p>* For Player 1.<br />\
		** The number of games Player 1 had white minus the number of games Player 2 had white.</p>";
}

function build_stats()
{
	var div = document.getElementById("results");
	div.innerHTML = "<h2>Stats</h2>";

	var menu = document.createElement("select");
	div.appendChild(menu);

	var stats_table = document.createElement("div");
	div.appendChild(stats_table);

	build_names_menu(menu, function(){refresh_stats_table(stats_table, this.value)});

	refresh_stats_table(stats_table, "");
}

function build_graph()
{
	var div = document.getElementById("results");
	div.innerHTML = '<h2>Graph</h2><a href="ladder.png"><img src="ladder.png" style="width:500px" /></a>';
}

function build()
{
	build_ladder();
}
