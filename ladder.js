// compare function for sorting
function compare(a, b)
{
	if (a < b) return -1;
	if (a > b) return 1;
	return 0;
}

function make_table(rows)
{
	var table = document.createElement('table');

	function make_tr(row)
	{
		var tr = document.createElement('tr');
		table.appendChild(tr);
	
		function make_td(x)
		{
			var td = document.createElement('td');
			td.innerHTML = x
			tr.appendChild(td);
		}
		row.forEach(make_td);
	
		return tr;
	}
	rows.forEach(make_tr);
	
	return table
}

function build_ladder()
{	
	players.sort(function(a, b){return -compare(a.rating, b.rating)});
	
	var i = 1;
	var rows = players.map(function(p){
		return [
			i++,
			p.name,
			Math.round(p.rating),
			p.points_won + " / " + p.game_count
		]}
	);
	
	document.getElementById('ladder').appendChild(make_table(rows));
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
	games.sort(function(a, b){return -compare(a.date, b.date)});
	
	var filtered_games = games.filter(function(g){
		return x == "" || g.name1 == x || g.name2 == x});
	
	var rows = filtered_games.map(function(p){
		return [
			p.date,
			p.name1,
			p.name2,
			string_of_result(p.result)
		]}
	);
	
	if (div.hasChildNodes())
		div.removeChild(div.firstChild);
	div.appendChild(make_table(rows));
}

function build_games()
{
	var div = document.getElementById("games");
	
	var menu = document.createElement("select");
	div.appendChild(menu);
	
	var games_table = document.createElement("div");
	div.appendChild(games_table);
	
	menu.onchange = function(){refresh_games_table(games_table, this.value)};
	
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
	
	refresh_games_table(games_table, "");
}

function build()
{
	build_ladder();
	build_games();
}
