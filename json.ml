let escape s =
	let len = String.length s in
	if len > 0 then begin
		let buf = Buffer.create len in
		for i = 0 to len - 1 do
		match s.[i] with
		| '\"' -> Buffer.add_string buf "\\\""
		| '\\' -> Buffer.add_string buf "\\\\"
		| '\b' -> Buffer.add_string buf "\\b"
		| '\n' -> Buffer.add_string buf "\\n"
		| '\r' -> Buffer.add_string buf "\\r"
		| '\t' -> Buffer.add_string buf "\\t"
		| c -> Buffer.add_char buf c
		done;
		Buffer.contents buf
	end
	else ""
	
type t =
	| Object of (string * t) list
	| Array of t list
	| String of string
	| Number of float
	| Integer of int
	| Boolean of bool
	| Empty

let endl n =
	if n = 0 then ""
	else "\n" ^ String.make (2*n - 2) ' '

let to_string x =
	let rec to_string' n = function
		| Object l -> (endl n) ^ "{ " ^ (String.concat ("," ^ (endl (n+1))) (List.map (fun (s, j) -> "\"" ^ s ^ "\": " ^ (to_string' (n+2) j)) l)) ^ " }"
		| Array l -> "[ " ^ (String.concat ", " (List.map (fun j -> (to_string' n j)) l)) ^ " ]"
		| String s -> "\"" ^ (escape s) ^ "\""
		| Number n -> Printf.sprintf "%.4f" n
		| Integer x -> string_of_int x
		| Boolean b -> if b then "true" else "false"
		| Empty -> "\"\""
	in
	to_string' 0 x
