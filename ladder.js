// compare function for sorting
function compare(a, b)
{
	if (a < b) return -1;
	if (a > b) return 1;
	return 0;
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
	
	players.sort(function(a, b){return -compare(a.ratings[a.ratings.length-1], b.ratings[b.ratings.length-1])});
	
	var i = 1;
	var rows = players.map(function(p){
		var last = p.ratings[p.ratings.length-1];
		var diff = Math.round(last - p.ratings[p.ratings.length-2]);
		return [
			i++,
			p.name + (p.active ? "" : " [inactive]"),
			Math.round(last),
			'<span class=' + (diff > 0 ? '"up">+' : '"down">') + diff + '</span>',
			p.points_won + " / " + p.game_count
		]}
	);
	
	var table = make_table(rows, ["Rank", "Name", "Rating", "Diff", "Score / Games"]);
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
	
	var table = make_table(rows, ["Date", "White", "Black", "Result"]);
	if (div.hasChildNodes())
		div.removeChild(div.firstChild);
	div.appendChild(table);
}

function build_games()
{
	var div = document.getElementById("results");
	div.innerHTML = "<h2>Past Games</h2>";
	
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

function build_graph()
{
	var div = document.getElementById("results");
	div.innerHTML = '<h2>Graph</h2><a href="ladder.png"><img src="ladder.png" style="width:500px" /></a>';
}

function build()
{
	build_ladder();
}
