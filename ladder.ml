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
}

let print_ladder players =
	let sorted = 
		List.sort (fun (_, {rating=rating1}) (_, {rating=rating2}) ->
			compare rating2 rating1)
		players
	in
	let print_player rank (_, p) =
		Printf.printf "%2d.  %-30s  %4d\n" (rank + 1) p.name (int_of_float p.rating)
	in
	List.iteri print_player sorted

let play' player1 player2 result =
	let update1, update2 = get_updates player1.rating player2.rating result in
	{player1 with rating = update1},
	{player2 with rating = update2}

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
		nick, {name; rating}
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
	let doc = "Path to players file." in
	Arg.(required & pos 0 (some file) None & info [] ~docv:"PLAYERS" ~doc)

let games_path =
	let doc = "Path to games file." in
	Arg.(required & pos 1 (some file) None & info [] ~docv:"GAMES" ~doc)

let cmd =
	let doc = "Compute and print ELO ladder" in
	let man = [
		`S "DESCRIPTION";
			`P "$(tname) computes the resulting ELO ratings for the players specified
			    in $(i,PLAYERS) after playing the games specified in $(i,GAMES).";
		`S "BUGS";
			`I ("Please report bugs by opening an issue on the Elo-ladder project page
			     on Github:", "https://github.com/robhoes/elo-ladder");
		]
	in
	Term.(pure print_summary $ players_path $ games_path),
	Term.info "ladder" ~version:"0.1a" ~doc ~man

let _ =
	match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
