type biguint = Bytes.t
type t = biguint

let first (a:t) = Bytes.get a 0 |> int_of_char

let last (a:t) =
  if Bytes.length a = 0
    then 0
    else
      let i = Bytes.length a - 1 in
      Bytes.get a i |> int_of_char

let zero : t = Bytes.make 1 (char_of_int 0)
let is_zero (a:t) = Bytes.length a = 1 && Bytes.get a 0 = (char_of_int 0)

let one : t = Bytes.make 1 (char_of_int 1)
let is_one (a:t) = Bytes.length a = 1 && Bytes.get a 0 = (char_of_int 1)

let digits i = 
  let rec bytes_to_lstream b =
    if Bytes.length b > 0
      then Lstream.Cons ((Bytes.get b 0), (lazy (bytes_to_lstream (Bytes.sub b 1 (Bytes.length b - 1)))))
      else Lstream.Nil
  in bytes_to_lstream i |> Lstream.map int_of_char

let cmp a b =
  let open Ord.Cmp in
  let module OrdInt = Ord.StructOrd(Int) in
  match OrdInt.cmp (Bytes.length a) (Bytes.length b) with
  | Higher -> Higher
  | Lesser -> Lesser
  | Equal ->  (Lstream.zip (digits a) (digits b))
    |> Lstream.map (fun (a,b) -> OrdInt.cmp a b)
    |> Lstream.fold_left cmp_fold Equal
    |> Lazy.force

let is_even a = last a = 0
let is_odd = Fun.negate is_even

let to_string i = Bytes.map (fun i -> int_of_char i + int_of_char '0' |> char_of_int) i |> Bytes.to_string
let of_string s = Bytes.of_string s |> Bytes.map (fun c -> int_of_char c - int_of_char '0' |> char_of_int)
let to_int i = Lstream.fold_left (fun a b -> a * 10 + b) 0 (digits i) |> Lazy.force
let of_int i = string_of_int i |> of_string

let of_digits ls = Lstream.fold_left (fun s c -> s ^ string_of_int c) "" ls |> Lazy.force |> of_string

let pad l i = if l < Bytes.length i
  then i
  else let dl = l - Bytes.length i in Bytes.concat Bytes.empty [Bytes.make dl (char_of_int 0); i]

let is_normalized i = first i <> 0
let normalize i = if is_normalized i then i else digits i |> Lstream.skip_while ((=) 0) |> of_digits

let add a b = 
  let maxlen = max (Bytes.length a) (Bytes.length b) in
  let pa = pad maxlen a in
  let pb = pad maxlen b in
  Lstream.fold_left (fun (vals, overflow) (xa, xb) -> let s = xa + xb + overflow in (vals @ [s], overflow/10)) ([], 0) (Lstream.zip (digits pa) (digits pb))
  |> Lazy.force
  |> (fun (vals, _) -> of_digits (Lstream.of_list vals))
  (* |> (fun i -> Printf.printf "[Biguint] add (pa=%s, pb=%s) -> %s\n" (to_string pa) (to_string pb) (to_string i); i) *)

let sub a b =
  let lt a b = cmp a b |> Ord.Cmp.is_lt in
  if lt a b then failwith (Printf.sprintf "biguint sub underflow (lhs=%s, rhs=%s)" (to_string a) (to_string b))
  else
    let maxlen = max (Bytes.length a) (Bytes.length b) in
    let pa = pad maxlen a in
    let pb = pad maxlen b in
    let f (a, b) (vals, carry) = let r = (-10) * carry + a - b in if r < 0 then (10 + r :: vals, 1) else (r :: vals, 0)
    in
    Lstream.FoldableLS.fold_right f ([], 0) (Lstream.zip (digits pa) (digits pb))
    |> (fun (vals, carry) -> of_digits (Lstream.of_list (carry :: vals)))
    |> normalize
    (* |> (fun i -> Printf.printf "[Biguint] sub (pa=%s, pb=%s) -> %s\n" (to_string pa) (to_string pb) (to_string i); i) *)

(* Biggest hack to make the calculations work - obviously not safe as it goes back to ints *)
let (%) a i = Lstream.fold_left (fun res n -> (((to_int res) * 10 + n) mod (to_int i)) |> of_int) zero (digits a) |> Lazy.force

module EqBU = Eq.Make(struct
  type t = biguint

  let equal = Bytes.equal
end)

module OrdBU = Ord.Make(struct
  include EqBU
  type t = biguint

  let cmp = cmp
end)

module NumBU = Num.Make(struct
  type t = biguint

  let zero = zero
  let one = one
  let add = add
  let sub = sub
  let mul (_:t) = failwith "Multiplication not implemented"
  let div (_:t) = failwith "Division not implemented"
end)