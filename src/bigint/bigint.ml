type bigint = Positive of Biguint.t | Negative of Biguint.t
type t = bigint

let to_string = function
| Positive u -> Biguint.to_string u
| Negative u -> "-" ^ Biguint.to_string u

let of_string s = if s.[0] = '-'
  then
    let lidx = String.length s - 1 in
    Negative (Biguint.of_string (String.sub s 1 lidx))
  else Positive (Biguint.of_string s)

let to_int = function
| Positive u -> Biguint.to_int u
| Negative u -> -(Biguint.to_int u)

let of_int i = if i < 0
  then Negative (Biguint.of_int (-i))
  else Positive (Biguint.of_int i)

let zero = Positive Biguint.zero
let one = Positive Biguint.one

let is_zero = function
| Positive i | Negative i -> Biguint.is_zero i

let is_one = function
| Negative _ -> false
| Positive i -> Biguint.is_one i

let equal a b = match a,b with
| (Positive a, Positive b) | (Negative a, Negative b) -> Biguint.EqBU.equal a b
| _ -> false

let rec add a b = match a,b with
| (Positive a, Positive b) -> Positive (Biguint.add a b)
| (Positive _, Negative _) -> sub a b
| (Negative _, Positive _) -> sub b a
| (Negative a, Negative b) -> Negative (Biguint.add a b)

and sub a b = match a,b with
| (Positive a, Positive b) when Biguint.OrdBU.lt a b -> Positive (Biguint.sub a b)
| (Positive a, Positive b) -> Negative (Biguint.sub b a)
| (Positive a, Negative b) -> Positive (Biguint.add a b)
| (Negative a, Positive b) -> Negative (Biguint.add a b)
| (Negative _, Negative _) -> sub b a

let mul a b = match a,b with
| (Positive a, Positive b) | (Negative a, Negative b) -> Positive (Biguint.NumBU.mul a b)
| (Negative a, Positive b) | (Positive a, Negative b) -> Negative (Biguint.NumBU.mul a b)

let div a b = match a,b with
| (Positive a, Positive b) | (Negative a, Negative b) -> Positive (Biguint.NumBU.div a b)
| (Negative a, Positive b) | (Positive a, Negative b) -> Positive (Biguint.NumBU.div a b)

let neg = function
| Positive a -> Negative a
| Negative a -> Positive a

module EqBI = Eq.Make(struct
  type t = bigint
  let equal = equal
end)

module OrdBI = Ord.Make(struct
  include EqBI

  let cmp a b = match a,b with
  | (Positive a, Positive b) -> Biguint.cmp a b
  | (Negative a, Negative b) -> Biguint.cmp b a
  | (Positive _, Negative _) -> Higher
  | (Negative _, Positive _) -> Lesser
end)