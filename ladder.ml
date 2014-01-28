(* Elo rating calculations *)

let k = 32.

let get_factor rating =
	10. ** (rating /. 400.)

let get_expectation rating1 rating2 =
	let factor1 = get_factor rating1 in
	let factor2 = get_factor rating2 in
	factor1 /. (factor1 +. factor2)

let get_updates rating1 rating2 result =
	let expectation = get_expectation rating1 rating2 in
	let update = k *. (result -. expectation) in
	rating1 +. update,
	rating2 -. update

(* ladder *)

module Date = struct
	type t = { y : int; m : int; d : int }
	let compare t t' = compare (t.y, t.m, t.d) (t'.y, t'.m, t'.d)
	let string_of t = Printf.sprintf "%04d-%02d-%02d" t.y t.m t.d
end
module DateMap = Map.Make(Date)

type player = {
	name: string;
	rating: float;
	history: float DateMap.t;
	game_count: int;
	points_won: float;
	active: bool;
}

let strings_of_ladder players =
	let sorted = 
		List.sort (fun (_, {rating=rating1}) (_, {rating=rating2}) ->
			compare rating2 rating1)
		players
	in
	List.mapi (fun rank (_, p) ->
		Printf.sprintf "%2d.  %-30s  %-1s  %4d  (%g / %d)" (succ rank) p.name
		(if not p.active then "☠" else "")
			(int_of_float p.rating) p.points_won p.game_count;
	) sorted

let play' p1 p2 result date =
	let update1, update2 = get_updates p1.rating p2.rating result in
	{p1 with rating = update1; history = DateMap.add date update1 p1.history;
		game_count = p1.game_count + 1; points_won = p1.points_won +. result},
	{p2 with rating = update2; history = DateMap.add date update2 p2.history;
		game_count = p2.game_count + 1; points_won = p2.points_won +. 1. -. result}

let replace n p l =
	let l = List.remove_assoc n l in
	(n, p) :: l

let (|>) x f = f x

let string_of_result = function
	| 1. -> "  1 - 0"
	| 0.5 -> "0.5 - 0.5"
	| _ -> "  0 - 1"

let strings_of_games ~rev_chron players games =
	let lines =
		List.map (fun (date, nick1, nick2, result) ->
			let player1 = List.assoc nick1 players in
			let player2 = List.assoc nick2 players in
			Printf.sprintf "%s: %20s - %-20s    %s"
				(Date.string_of date) player1.name player2.name
				(string_of_result result)
		) games
	in
	if rev_chron then List.rev lines else lines

let csv_strings_of_history players =
	let combined_history =
		List.fold_left (fun combined_h (_, p) ->
			DateMap.fold (fun d rating acc ->
				(* Printf.sprintf "%s: %s %.1f" p.name (Date.string_of d) rating :: acc') *)
				try DateMap.add d ((p.name, rating) :: (DateMap.find d acc)) acc
				with Not_found -> DateMap.add d [(p.name, rating)] acc
			) p.history combined_h
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
	let open Printf in
	let preamble = ["set xdata time"; "set timefmt '%Y-%m-%d'";
		"set format x '%d/%m'"; "set datafile separator '\\t'"]
	in
	let header =
		List.map (fun (_, p) ->
			sprintf "plot '-' using 1:2 with linespoints title '%s'" p.name
		) players
	in
	List.map (fun (_, p) ->
		DateMap.fold (fun d r acc ->
			(sprintf "%s\t%.1f" (Date.string_of d) r) :: acc
		) p.history []
	) players
	|> List.map (fun l -> l @ ["end"]) |> List.flatten
	|> List.append (preamble @ header)

let play players nick1 nick2 result date =
	let player1 = List.assoc nick1 players in
	let player2 = List.assoc nick2 players in
	let player1, player2 = play' player1 player2 result date in
	players |> replace nick1 player1 |> replace nick2 player2

let play_games players games =
	List.fold_left (fun players (date, nick1, nick2, result) ->
		play players nick1 nick2 result date
	) players games

(* filing *)

let line_stream_of_channel channel =
	Stream.from (fun _ ->
		try Some (input_line channel) with End_of_file -> None
	)

let read_players path =
	let parse_player_line line =
		Scanf.sscanf line "%s@,%s@,%f,%b"
			(fun nick name rating active ->
				nick, {name; rating; history = DateMap.empty; game_count = 0; points_won = 0.; active})
	in
	let in_channel = open_in path in
	let players = ref [] in
	begin
		try
			Stream.iter (fun line ->
				players := parse_player_line line :: !players)
				(line_stream_of_channel in_channel);
			close_in in_channel;
		with e ->
			close_in_noerr in_channel;
			raise e
	end;
	!players


let read_games path =
	let parse_game_line line =
		Scanf.sscanf line "%4d-%2d-%2d,%s@,%s@,%f"
			(fun yyyy mm dd nick_w nick_b res -> Date.({y=yyyy; m=mm; d=dd}), nick_w, nick_b, res
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

let print_summary title players_path games_path rev_chron gh_pages =
	let players = read_players players_path in
	let games = read_games games_path in

	if gh_pages then print_endline (string_of_yaml_header ());

	begin match title with
	| Some text -> print_endline (string_of_title ~gh_pages text)
	| None -> ()
	end;

	print_endline (string_of_heading ~gh_pages "Ladder");
	print_endline (string_of_section (strings_of_ladder (play_games players games)));

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
		`P "Where $(i,ID) can be any unique string and $(i,Elo-rating) is
		    the starting rating for the player as an integer.";
		`I ("Example:", "magnus,Magnus Carlsen,2870");
		`P ""; `Noblank;
		`P "The $(i,GAMES) file should be in CSV format:";
		`I ("Syntax:", "<Date>,<White's $(i,ID)>,<Black's $(i,ID)>,<$(i,RES)>");
		`P "Where the date is in ISO 6801 format (yyyy-mm-dd); $(i,ID)s
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

let default_cmd =
	let doc = "An Elo ladder system" in
	let man = help_secs in
	Term.(ret (pure (`Help (`Pager, None)))),
	Term.info "ladder" ~version:"0.2" ~doc ~man

let cmds = [ print_cmd; history_cmd ]

let _ =
	match Term.eval_choice default_cmd cmds with
	| `Error _ -> exit 1 | _ -> exit 0
