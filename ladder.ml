(* Elo rating calculations *)

module type GAMETYPE = sig
	val description : string
	val get_updates : float -> float -> int -> float -> float * float
	val get_stakes : float -> float -> float * float * float
end

module Chess : GAMETYPE = struct
	let description = "XenServer Chess Ladder"

	let k = 32.

	let get_factor rating =
		10. ** (rating /. 400.)

	let get_expectation rating1 rating2 =
		let factor1 = get_factor rating1 in
		let factor2 = get_factor rating2 in
		factor1 /. (factor1 +. factor2)

	let get_updates rating1 rating2 _ result =
		let expectation = get_expectation rating1 rating2 in
		let update = k *. (result -. expectation) in
		rating1 +. update,
		rating2 -. update

	let get_stakes rating1 rating2 =
		let update result = k *. (result -. get_expectation rating1 rating2) in
		update 1., update 0.5, update 0.
end

module Backgammon : GAMETYPE = struct
	let description = "XenServer Backgammon Ladder"

	let get_expectation rating1 rating2 sqrtlen =
		let ratingdiff = rating2 -. rating1 in
		let exponent = ratingdiff *. sqrtlen /. 2000. in
		1. /. (1. +. 10. ** exponent)

	let get_updates rating1 rating2 len result =
		let sqrtlen = sqrt (float_of_int len) in
		let expectation = get_expectation rating1 rating2 sqrtlen in
		let update = 4. *. sqrtlen *. (result -. expectation) in
		rating1 +. update,
		rating2 -. update

	let get_stakes _ _ = 0., 0., 0.
end

(* ladder *)

module Date = struct
	type t = { id: int; y : int; m : int; d : int }
	let compare t t' = compare (t.y, t.m, t.d) (t'.y, t'.m, t'.d)
	let string_of t = Printf.sprintf "%04d-%02d-%02d" t.y t.m t.d
end
module DateMap = Map.Make(Date)

module Ladder (G : GAMETYPE) = struct

type player = {
	name: string;
	rating: float;
	history: (Date.t * float) list;
	game_count: int;
	points_won: float;
	active: bool;
	id: int;
}

let replace n p l =
	let l = List.remove_assoc n l in
	(n, p) :: l

let (|>) x f = f x

let round_to_int x =
	int_of_float (x +. 0.5)

let json_of_player p =
	let open Json in
	Object [
		"name", String p.name;
		"ratings", Array (List.rev (List.fold_left (fun rs (_, x) -> (Number x) :: rs) [] p.history));
		"game_count", Number (float_of_int p.game_count);
		"points_won", Number p.points_won;
		"active", Boolean p.active;
	]

let json_of_players ps =
	Json.Array (List.map (fun (_, p) -> json_of_player p) ps)

let sort_by_rating players =
	List.sort (fun (_, {rating=r}) (_, {rating=r'}) -> compare r' r) players

let strings_of_ladder players =
	(sort_by_rating players)
	|> List.mapi (fun rank (_, p) ->
		Printf.sprintf "%2d.  %-30s  %-1s  %4d  (%g / %d)" (succ rank) p.name
		(if not p.active then "☠" else "")
			(round_to_int p.rating) p.points_won p.game_count;
	)

let play' p1 p2 len result date =
	let update1, update2 = G.get_updates p1.rating p2.rating len result in
	{p1 with rating = update1; history = (date, update1) :: p1.history;
		game_count = p1.game_count + 1; points_won = p1.points_won +. result},
	{p2 with rating = update2; history = (date, update2) :: p2.history;
		game_count = p2.game_count + 1; points_won = p2.points_won +. 1. -. result}

let string_of_result = function
	| 1. -> "  1 - 0"
	| 0.5 -> "0.5 - 0.5"
	| _ -> "  0 - 1"

let strings_of_games ~rev_chron players games =
	let lines =
		List.map (fun (date, nick1, nick2, len, result) ->
			let player1 = List.assoc nick1 players in
			let player2 = List.assoc nick2 players in
			Printf.sprintf "%s: %20s - %-20s    %s"
				(Date.string_of date) player1.name player2.name
				(string_of_result result)
		) games
	in
	if rev_chron then List.rev lines else lines
	
let json_of_game date name1 name2 len result =
	let open Json in
	Object [
		"date", String (Date.string_of date);
		"name1", String name1;
		"name2", String name2;
		"length", Integer len;
		"result", Number result;
	]
	
let json_of_games players games =
	Json.Array (
		List.map (fun (date, nick1, nick2, len, result) ->
			let player1 = List.assoc nick1 players in
			let player2 = List.assoc nick2 players in
			json_of_game date player1.name player2.name len result
		) games
	)

let csv_strings_of_history players =
	let combined_history =
		List.fold_left (fun combined_h (_, p) ->
			let map = List.fold_left (fun acc (d, r) -> DateMap.add d r acc) DateMap.empty p.history in
			DateMap.fold (fun d rating acc ->
				(* Printf.sprintf "%s: %s %.1f" p.name (Date.string_of d) rating :: acc') *)
				try DateMap.add d ((p.name, rating) :: (DateMap.find d acc)) acc
				with Not_found -> DateMap.add d [(p.name, rating)] acc
			) map combined_h
		) DateMap.empty players
	in
	let headings = "Date," ^
		(List.map (fun (_, p) -> p.name) players |> String.concat ",")
	in
	let lines =
		DateMap.fold (fun d rs acc ->
			let ratings_list =
				List.map (fun (_, p) ->
					try Printf.sprintf "%f" (List.assoc p.name rs)
					with Not_found -> ""
				) players
			in
			(ratings_list |> String.concat ","
				|> Printf.sprintf "%s,%s" (Date.string_of d))
			:: acc
		) combined_history []
	in
	headings :: (List.rev lines)

let gnuplot_strings_of_history players =
	let players = sort_by_rating players |> List.filter (fun (_, p) -> List.length p.history > 1) in
	let open Printf in
	let preamble = [
		"set term pngcairo size 1920,1080 linewidth 1.75 enhanced font \"Droid Sans,18\"";
		"set title '" ^ G.description ^ "' font \"Droid Sans,34\"";
		"set xtics format''";
		"set key rmargin bottom reverse Left";
		"set datafile separator '\\t'";
		"# Border";
		"set style line 200 lc rgb '#000000' lt 1 lw 1";
		"set border 3 back ls 200";
		"# Gridlines";
		"set style line 201 lc rgb '#808080' lt 0 lw 1";
		"set grid back ls 201";
		"# Axis";
		"set xtics nomirror";
		"set ytics nomirror";
		"# Other styling";
		"set pointintervalbox 2";
		]
	in
	let dotted_tails =
		List.map (fun (_, p) ->
			let (latest_d, latest_r) = List.hd p.history in
			sprintf "set arrow from first \"%d\", first %.1f to graph 1, first %.1f nohead lc %d lw 3 lt 0"
				(latest_d.Date.id) latest_r latest_r p.id
		) (List.filter (fun (_, p) -> p.active) players)
	in
	let plot_cmds =
		"plot \\" ::
		List.map (fun (_, p) ->
			sprintf "'-' using 1:2 with linespoints lc %d lw 2 pi -1 pt %d ps 1.2 title '%4d  %s %s', \\"
				p.id p.id (round_to_int p.rating) p.name (if not p.active then "☠" else "")
		) players
	in
	(* Data *)
	List.map (fun (_, p) ->
		List.fold_left (fun acc (d, r) ->
			(sprintf "%d\t%.1f" (d.Date.id) r) :: acc
		) [] (p.history |> List.rev |> List.tl |> List.rev) (* remove the last list element, which is the initial rating of 1500 *)
	) players
	|> List.map (fun l -> l @ ["end"]) |> List.flatten
	|> List.append (preamble @ dotted_tails @ plot_cmds @ ["1 / 0 notitle"])

let play players nick1 nick2 len result date =
	let player1 = List.assoc nick1 players in
	let player2 = List.assoc nick2 players in
	let player1, player2 = play' player1 player2 len result date in
	players |> replace nick1 player1 |> replace nick2 player2

let play_games players games =
	List.fold_left (fun players (date, nick1, nick2, len, result) ->
		play players nick1 nick2 len result date
	) players games

let active_nicks players =
	let nicks = List.fold_left (fun nicks (nick, {active}) -> if active then nick :: nicks else nicks) [] players in
	List.sort compare nicks

let strings_of_stats players stats =
	let print ((nick1, nick2), (count, balance, wins, draws, losses)) =
		let player1 = List.assoc nick1 players in
		let player2 = List.assoc nick2 players in
		Printf.sprintf "%20s - %-20s    %2d %2d %2d %2d %3d" player1.name player2.name count wins draws losses balance
	in
	List.map print stats

let json_of_stat name1 name2 count balance wins draws losses =
	let open Json in
	Object [
		"name1", String name1;
		"name2", String name2;
		"count", Number (float_of_int count);
		"balance", Number (float_of_int balance);
		"wins", Number (float_of_int wins);
		"draws", Number (float_of_int draws);
		"losses", Number (float_of_int losses);
	]

let json_of_stats players stats =
	Json.Array (
		List.map (fun ((nick1, nick2), (count, balance, wins, draws, losses)) ->
			let player1 = List.assoc nick1 players in
			let player2 = List.assoc nick2 players in
			json_of_stat player1.name player2.name count balance wins draws losses
		) stats
	)

let combine l =
	let rec aux k acc emit = function
		| [] -> acc
		| h :: t ->
			if k = 1 then
				aux k (emit [h] acc) emit t
			else
				let new_emit x = emit (h :: x) in
				aux k (aux (k-1) acc new_emit t) emit t
	in
	let emit x acc = x :: acc in
	aux 2 [] emit l

let stats nicks games =
	let nicks = List.sort compare nicks in
	let combinations = combine nicks in
	let combinations = List.map (function [x; y] -> (x, y), (0, 0, 0, 0, 0) | _ -> failwith "boom!") combinations in
	let results = List.fold_left (fun r (_, nick1, nick2, len, result) ->
		let pair, colour, result =
			if compare nick1 nick2 < 0 then
				(nick1, nick2), 1, result
			else
				(nick2, nick1), -1, 1. -. result
		in
		let win, draw, loss = match result with
			| 1. -> 1, 0, 0
			| 0. -> 0, 0, 1
			| _  -> 0, 1, 0
		in
		try
			let count, balance, wins, draws, losses = List.assoc pair r in
			replace pair (count + 1, balance + colour, wins + win, draws + draw, losses + loss) r
		with Not_found -> r
	) combinations games in
	List.sort (fun (_, (x, _, _, _, _)) (_, (y, _, _, _, _)) -> x - y) results

let strings_of_matches players matches =
	let print (nick1, nick2) =
		let player1 = List.assoc nick1 players in
		let player2 = List.assoc nick2 players in
		Printf.sprintf "%20s - %s" player1.name player2.name
	in
	List.map print matches

let json_of_match name1 name2 stake_win stake_draw stake_loss =
	let open Json in
	Object [
		"name1", String name1;
		"name2", String name2;
		"stake_win", Number stake_win;
		"stake_draw", Number stake_draw;
		"stake_loss", Number stake_loss;
	]

let json_of_matches players matches =
	Json.Array (
		List.map (fun ((nick1, nick2), (stake_win, stake_draw, stake_loss)) ->
			let player1 = List.assoc nick1 players in
			let player2 = List.assoc nick2 players in
			json_of_match player1.name player2.name stake_win stake_draw stake_loss
		) matches
	)

let remove_first x l =
	let rec loop ac = function
	| [] -> ac
	| hd :: tl -> if hd = x then ac @ tl else loop (hd :: ac) tl
	in
	loop [] l

let filter_map f l =
	List.fold_left (fun l' a -> match f a with Some x -> x :: l' | None -> l') [] l |> List.rev

let rec setify = function
	| [] -> []
	| (x :: xs) -> if List.mem x xs then setify xs else x :: (setify xs)

let get_stakes players (nick1, nick2) =
	let player1 = List.assoc nick1 players in
	let player2 = List.assoc nick2 players in
	G.get_stakes player1.rating player2.rating

let suggested_matches nicks stats =
	let count_limit = match stats with [] -> 0 | (_, (c, _, _, _, _)) :: _ -> c + 1 in
	let _, matches = List.fold_left (fun (remaining_nicks, matches) ((nick1, nick2), (count, balance, _, _, _)) ->
		if List.mem nick1 remaining_nicks && List.mem nick2 remaining_nicks && count <= count_limit then
			remaining_nicks |> remove_first nick1 |> remove_first nick2,
			if balance < 0 then (nick1, nick2) :: matches else (nick2, nick1) :: matches
		else
			remaining_nicks, matches
	) (nicks, []) stats in
	List.rev matches

let min_score =
	List.fold_left (function
		| None ->
			(function x -> Some x)
		| Some (x, y) ->
			(function (x', y') -> Some (if y' < y then x', y' else x, y))
	) None

let suggested_matches2 players nicks stats =
	filter_map (fun nick ->
		(* take the three least-played games for "nick" *)
		let stats' = List.filter (fun ((nick1, nick2), _) -> nick1 = nick || nick2 = nick) stats in
		let stats' = match stats' with
			| stat1 :: stat2 :: stat3 :: _ -> [stat1; stat2; stat3]
			| _ -> []
		in
		(* of these, pick the opponent that is closest in rating *)
		let games_and_scores = List.map (fun ((nick1, nick2), (count, balance, _, _, _)) ->
			let rating n = (List.assoc n players).rating in
			let score = (rating nick1 -. rating nick2) |> int_of_float |> abs in
			(* assign colour fairly *)
			(if balance < 0 then (nick1, nick2) else (nick2, nick1)), score
		) stats' in
		min_score games_and_scores
	) nicks |> List.map fst |> setify

let suggested_matches3 players nicks stats =
	let counts = ref (List.map (fun nick -> nick, 0) nicks) in
	filter_map (fun nick ->
		(* take the three least-played games for "nick" *)
		let stats' = List.filter (fun ((nick1, nick2), _) -> nick1 = nick || nick2 = nick) stats in
		let stats' = match stats' with
			| stat1 :: stat2 :: stat3 :: _ -> [stat1; stat2; stat3]
			| _ -> []
		in
		(* pick the opponents that has been chosen the least often *)
		let games_and_scores = List.map (fun ((nick1, nick2), (count, balance, _, _, _)) ->
			let score =
				let other = if nick1 <> nick then nick1 else nick2 in
				List.assoc other !counts
			in
			(* assign colour fairly *)
			(if balance < 0 then (nick1, nick2) else (nick2, nick1)), score
		) stats' in
		let result = min_score games_and_scores in
		(* update counts *)
		(match result with
			| Some ((nick1, nick2), _) ->
				let new_count = List.assoc nick1 !counts + 1 in
				counts := replace nick1 new_count !counts;
				let new_count = List.assoc nick2 !counts + 1 in
				counts := replace nick2 new_count !counts
			| None -> ()
		);
		result
	) nicks |> List.map fst |> setify

(* filing *)

let line_stream_of_channel channel =
	Stream.from (fun _ ->
		try Some (input_line channel) with End_of_file -> None
	)

let read_players path =
	let long_time_ago = Date.({id = 0; y = 1970; m = 1; d = 1}) in
	let parse_player_line id line =
		Scanf.sscanf line "%s@,%s@,%f,%b"
			(fun nick name rating active ->
				nick, {name; rating; history = [long_time_ago, rating]; game_count = 0; points_won = 0.; active; id})
	in
	let in_channel = open_in path in
	let players = ref [] in
	let id = ref 0 in
	begin
		try
			Stream.iter (fun line ->
				id := succ !id;
				players := parse_player_line !id line :: !players)
				(line_stream_of_channel in_channel);
			close_in in_channel;
		with e ->
			close_in_noerr in_channel;
			raise e
	end;
	!players


let read_games path =
	let id = ref 0 in
	let parse_game_line line =
		id := succ !id;
		try
			Scanf.sscanf line "%4d-%2d-%2d,%s@,%s@,%d,%f"
				(fun yyyy mm dd nick_w nick_b len res -> Date.({id=(!id); y=yyyy; m=mm; d=dd}), nick_w, nick_b, len, res
			)
		with _ ->
			(* if we don't have a length field, then use 0 *)
			Scanf.sscanf line "%4d-%2d-%2d,%s@,%s@,%f"
				(fun yyyy mm dd nick_w nick_b res -> Date.({id=(!id); y=yyyy; m=mm; d=dd}), nick_w, nick_b, 0, res
			)
	in
	let in_channel = open_in path in
	let games = ref [] in
	begin
		try
			Stream.iter (fun line ->
				games := parse_game_line line :: !games)
				(line_stream_of_channel in_channel);
			close_in in_channel
		with e ->
			close_in_noerr in_channel;
			raise e
	end;
	List.rev !games

let string_of_yaml_header () =
	Printf.sprintf "%s\n%s\n%s" "---" "layout: default" "---"

let string_of_title ?(gh_pages = false) title =
	if gh_pages
	then Printf.sprintf "# %s" title
	else Printf.sprintf "\n%s\n%s" title (String.make (String.length title) '=')

let string_of_heading ?(gh_pages = false) heading =
	if gh_pages
	then Printf.sprintf "### %s" heading
	else Printf.sprintf "\n%s\n%s" heading (String.make (String.length heading) '-')

let string_of_section lines =
	let lines = List.map (fun line -> "    " ^ line) lines in
	String.concat "\n" lines

end

module L = Ladder(Chess)
open L

let print_summary title players_path games_path rev_chron gh_pages =
	let players = read_players players_path in
	let games = read_games games_path in

	if gh_pages then print_endline (string_of_yaml_header ());

	begin match title with
	| Some text -> print_endline (string_of_title ~gh_pages text)
	| None -> ()
	end;

	let players = play_games players games in

	print_endline (string_of_heading ~gh_pages "Ladder");
	print_endline (string_of_section (strings_of_ladder players));

	let nicks = active_nicks players in
	print_endline (string_of_heading ~gh_pages "Suggested games (least played)");
	print_endline (string_of_section (stats nicks games |> suggested_matches3 players nicks |>
		strings_of_matches players));

	print_endline (string_of_heading ~gh_pages "Games");
	print_endline (string_of_section (strings_of_games ~rev_chron players games));
	()

let print_history players_path games_path fmt =
	let players = read_players players_path in
	let games = read_games games_path in
	let str_f = match fmt with
	| `Csv -> csv_strings_of_history | `Gnuplot -> gnuplot_strings_of_history
	in
	play_games players games |> str_f |> List.iter print_endline;
	()

let print_stats players_path games_path =
	let players = read_players players_path in
	let games = read_games games_path in
	let nicks = List.map (fun (nick, _) -> nick) players in
	print_endline (string_of_heading ~gh_pages:false "Statistics");
	print_endline (string_of_section (stats nicks games |> strings_of_stats players));
	()

let print_json players_path games_path =
	let players = read_players players_path in
	let games = read_games games_path in

	let players = play_games players games in
	let json = "players = " ^ (Json.to_string (json_of_players players)) in
	print_endline (json);

	let json = "games = " ^ (Json.to_string (json_of_games players games)) in
	print_endline (json);

	let nicks = List.map (fun (nick, _) -> nick) players in
	let active_nicks = active_nicks players in
	let stats' = stats nicks games in
	let json = "stats = " ^ (Json.to_string (json_of_stats players stats')) in
	print_endline (json);

	let suggestions = stats active_nicks games |> suggested_matches3 players active_nicks in
	let suggestions = List.map (fun game -> game, get_stakes players game) suggestions in
	let json = "suggestions = " ^ (Json.to_string (json_of_matches players suggestions)) in
	print_endline (json);
	()

(* Command line interface *)

open Cmdliner

let help common_opts man_format cmds topic = match topic with
  | None -> `Help (`Pager, None) (* help about the program. *)
  | Some topic ->
    let topics = "topics" :: "patterns" :: "environment" :: cmds in
    let conv, _ = Arg.enum (List.rev_map (fun s -> (s, s)) topics) in
    match conv topic with
    | `Error e -> `Error (false, e)
    | `Ok t when t = "topics" -> List.iter print_endline topics; `Ok ()
    | `Ok t when List.mem t cmds -> `Help (man_format, Some t)
    | `Ok t ->
      let page = (topic, 7, "", "", ""), [`S topic; `P "Say something";] in
      `Ok (Manpage.print man_format Format.std_formatter page)

let help_secs = [
	`P "Use `$(mname) $(i,COMMAND) --help' for help on a specific command.";`Noblank;
	`S "FILE-FORMATS";
		`P "The $(i,PLAYERS) file should be in CSV format:";
		`I ("Syntax:", "<$(i,ID)>,<Full name>,<$(i,Elo-rating)>");
		`P "Where $(i,ID) can be any unique string, $(i,Elo-rating) is the
		    starting rating for the player as an integer, and active indicates
		    whether the player is retired or not.";
		`I ("Example:", "magnus,Magnus Carlsen,2870,true");
		`P ""; `Noblank;
		`P "The $(i,GAMES) file should be in CSV format:";
		`I ("Syntax:", "<Date>,<White's $(i,ID)>,<Black's $(i,ID)>,<$(i,RES)>");
		`P "Where the date is in ISO 8601 format (yyyy-mm-dd); $(i,ID)s
		    match those listed in the $(i,PLAYERS) file; and $(i,RES) is
		    either $(i,1), $(i,.5) or $(i,0) in the case of a win, draw
		    or loss for white respectively.";
		`I ("Example:", "2013-11-21,magnus,anand,.5");
	`S "BUGS";
		`I ("Please report bugs by opening an issue on the Elo-ladder
		     project page on Github:",
		    "https://github.com/robhoes/elo-ladder"); ]

let players_path =
	let doc = "Path to players file. See $(i,FILE-FORMATS) for details." in
	Arg.(required & pos 0 (some file) None & info [] ~docv:"PLAYERS" ~doc)

let games_path =
	let doc = "Path to games file. See $(i,FILE-FORMATS) for details." in
	Arg.(required & pos 1 (some file) None & info [] ~docv:"GAMES" ~doc)


let print_cmd =
	let title =
		let doc = "Optionally print a title before printing the ladder." in
		Arg.(value & opt (some string) None & info ["t"; "title"] ~docv:"TITLE" ~doc)
	in

	let rev_chron =
		let doc = "Print games in reverse-chronological order (off by default)." in
		Arg.(value & flag & info ["R"; "reverse"] ~doc)
	in

	let gh_pages =
		let doc = "Output markdown for Github pages publication of ladder." in
		Arg.(value & flag & info ["gh-pages"] ~doc)
	in

	let doc = "Compute and print ELO ladder" in
	let man = [
		`S "DESCRIPTION";
			`P "$(tname) computes the resulting ELO ratings for the players
			    specified in $(i,PLAYERS) after playing the games specified in
			    $(i,GAMES)."; ] @ help_secs
	in
	Term.(pure print_summary $ title $ players_path $ games_path $ rev_chron $ gh_pages),
	Term.info "print" ~doc ~man

let history_cmd =
	let fmt =
		let doc =
			"Format in which to print the history; either `csv' or `gnuplot'."
		in
		let fmt = Arg.enum ["csv", `Csv; "gnuplot", `Gnuplot] in
		Arg.(required & opt (some fmt) None & info ["format"] ~doc)
	in
	let doc = "Compute and print historic ratings of players for plotting" in
	let man = [
		`S "DESCRIPTION";
			`P "$(tname) computes the historic Elo ratings for the players
			    specified in $(i,PLAYERS) after each of the games specified in
			    $(i,GAMES) and outputs these as datapoints in CSV format"
		] @ help_secs
	in
	Term.(pure print_history $ players_path $ games_path $ fmt),
	Term.info "history" ~doc ~man

let stats_cmd =
	let doc = "Compute and print stats based on the ELO ladder" in
	let man = [
		`S "DESCRIPTION";
			`P "$(tname) computes, for each pair of players, the number of games
				they have played against each other, and the balance of white and
				black games. The stats are for the players specified in
				$(i,PLAYERS) after playing the games specified in $(i,GAMES).";
			] @ help_secs
	in
	Term.(pure print_stats $ players_path $ games_path),
	Term.info "stats" ~doc ~man
	
let json_cmd =
	let doc = "Output all available data in JSON format" in
	let man = [
		`S "DESCRIPTION";
			`P "$(tname) prints all available data in JSON format, for the
			players specified in $(i,PLAYERS) after playing the games specified
			in $(i,GAMES).";
			] @ help_secs
	in
	Term.(pure print_json $ players_path $ games_path),
	Term.info "json" ~doc ~man

let default_cmd =
	let doc = "An Elo ladder system" in
	let man = help_secs in
	Term.(ret (pure (`Help (`Pager, None)))),
	Term.info "ladder" ~version:"0.2" ~doc ~man

let cmds = [ print_cmd; history_cmd; stats_cmd; json_cmd]

let _ =
	match Term.eval_choice default_cmd cmds with
	| `Error _ -> exit 1 | _ -> exit 0
