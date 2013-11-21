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

type player = {
	name: string;
	rating: float;
	game_count: int;
}

let print_ladder players =
	let sorted = 
		List.sort (fun (_, {rating=rating1}) (_, {rating=rating2}) ->
			compare rating2 rating1)
		players
	in
	let rec print_player rank = function
		| [] -> ()
		| (_, p) :: tl ->
			Printf.printf "%2d.  %-30s  %4d  (%d)\n" rank p.name (int_of_float p.rating) p.game_count;
			print_player (rank + 1) tl
	in
	print_player 1 sorted

let play' player1 player2 result =
	let update1, update2 = get_updates player1.rating player2.rating result in
	{player1 with rating = update1; game_count = player1.game_count + 1},
	{player2 with rating = update2; game_count = player2.game_count + 1}

let replace n p l =
	let l = List.remove_assoc n l in
	(n, p) :: l

let (|>) x f = f x

let print_result = function
	| 1. -> "  1 - 0"
	| 0.5 -> "0.5 - 0.5"
	| _ -> "  0 - 1"

let print_games players games =
	List.iter (fun (nick1, nick2, result) ->
		let player1 = List.assoc nick1 players in
		let player2 = List.assoc nick2 players in
		Printf.printf "%20s - %-20s    %s\n" player1.name player2.name (print_result result)
	) games

let play players nick1 nick2 result =
	let player1 = List.assoc nick1 players in
	let player2 = List.assoc nick2 players in
	let player1, player2 = play' player1 player2 result in
	players |> replace nick1 player1 |> replace nick2 player2

let play_games players games =
	List.fold_left (fun players (nick1, nick2, result) ->
		play players nick1 nick2 result
	) players games

(* filing *)

let read_players fname =
	let f = open_in fname in
	let parse s =
		let a = String.index s ',' in
		let b = String.rindex s ',' in
		let n = String.length s in
		let nick = String.sub s 0 a in
		let name = String.sub s (a + 1) (b - a - 1) in
		let rating = String.sub s (b + 1) (n - b - 1) |> int_of_string |> float_of_int in
		nick, {name; rating; game_count = 0}
	in
	let players = ref [] in
	begin
		try
			while true do
				let s = input_line f in
				players := parse s :: !players
			done
		with End_of_file -> ()
	end;
	close_in f;
	!players

let read_games fname =
	let f = open_in fname in
	let parse s =
		let a = String.index s ',' in
		let b = String.rindex s ',' in
		let n = String.length s in
		let nick1 = String.sub s 0 a in
		let nick2 = String.sub s (a + 1) (b - a - 1) in
		let result = String.sub s (b + 1) (n - b - 1) |> float_of_string in
		nick1, nick2, result
	in
	let games = ref [] in
	begin
		try
			while true do
				let s = input_line f in
				games := parse s :: !games
			done
		with End_of_file -> ()
	end;
	close_in f;
	List.rev !games

let print_summary players_path games_path =
	let players = read_players players_path in
	let games = read_games games_path in

	print_string "Games\n\n";
	print_games players games;

	print_string "\nLadder\n\n";
	print_ladder (play_games players games);
	()

(* Command line interface *)

open Cmdliner

let players_path =
	let doc = "Path to players file. See $(i,FILE-FORMATS) for details." in
	Arg.(required & pos 0 (some file) None & info [] ~docv:"PLAYERS" ~doc)

let games_path =
	let doc = "Path to games file. See $(i,FILE-FORMATS) for details." in
	Arg.(required & pos 1 (some file) None & info [] ~docv:"GAMES" ~doc)

let cmd =
	let doc = "Compute and print ELO ladder" in
	let man = [
		`S "DESCRIPTION";
			`P "$(tname) computes the resulting ELO ratings for the players
			    specified in $(i,PLAYERS) after playing the games specified in
			    $(i,GAMES).";
		`S "FILE-FORMATS";
			`P "The $(i,PLAYERS) file should be in CSV format:";
			`I ("Syntax:", "<$(i,ID)>,<Full name>,<$(i,Elo-rating)>");
			`P "Where $(i,ID) can be any unique string and $(i,Elo-rating) is
			    the starting rating for the player as an integer.";
			`I ("Example:", "magnus,Magnus Carlsen,2870");
			`P ""; `Noblank;
			`P "The $(i,GAMES) file should be in CSV format:";
			`I ("Syntax:", "<White's $(i,ID)>,<Black's $(i,ID)>,<$(i,RES)>");
			`P "Where the $(i,ID)s match those listed in the $(i,PLAYERS)
			    file and $(i,RES) is either $(i,1.), $(i,.5) or $(i,0.) in the
			    case of a win, draw or loss for white respectively.";
			`I ("Example:", "magnus,anand,.5");
		`S "BUGS";
			`I ("Please report bugs by opening an issue on the Elo-ladder
			     project page on Github:",
			    "https://github.com/robhoes/elo-ladder");
		]
	in
	Term.(pure print_summary $ players_path $ games_path),
	Term.info "ladder" ~version:"0.1a" ~doc ~man

let _ =
	match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
