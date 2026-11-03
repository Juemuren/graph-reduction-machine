-- | Expand arithmetic and Boolean syntax into pure lambda calculus.
module Desugar (desugar, desugarSyntax) where

import qualified ArithmeticLambda.Abs as Arithmetic
import qualified PureLambda.Abs as Pure

{-
Replace arithmetic operators with applications of built-in functions.
Built-ins and literals remain available for the later expansion step.
-}
desugarSyntax :: Arithmetic.Exp -> Arithmetic.Exp
desugarSyntax expression = case expression of
  Arithmetic.EApp function argument ->
    Arithmetic.EApp (desugarSyntax function) (desugarSyntax argument)
  Arithmetic.EAbs name body -> Arithmetic.EAbs name (desugarSyntax body)
  Arithmetic.EFalseLit -> Arithmetic.EFalse
  Arithmetic.ETrueLit -> Arithmetic.ETrue
  Arithmetic.ENat 0 -> Arithmetic.EZero
  Arithmetic.EAnd left right -> binary Arithmetic.EAndOp left right
  Arithmetic.EOr left right -> binary Arithmetic.EOrOp left right
  Arithmetic.ENot value -> Arithmetic.EApp Arithmetic.ENotOp (desugarSyntax value)
  Arithmetic.EAdd left right -> binary Arithmetic.EAddOp left right
  Arithmetic.ESub left right -> binary Arithmetic.ESubOp left right
  Arithmetic.EZAdd left right -> binary Arithmetic.EZAddOp left right
  Arithmetic.EZSub left right -> binary Arithmetic.EZSubOp left right
  Arithmetic.EMul left right -> binary Arithmetic.EMulOp left right
  Arithmetic.EPow base exponent -> binary Arithmetic.EPowOp base exponent
  Arithmetic.ESucc value -> Arithmetic.EApp Arithmetic.ESuccOp (desugarSyntax value)
  Arithmetic.EPred value -> Arithmetic.EApp Arithmetic.EPredOp (desugarSyntax value)
  Arithmetic.ENeg value -> Arithmetic.EApp Arithmetic.ENegOp (desugarSyntax value)
  other -> other
 where
  binary operator left right =
    Arithmetic.EApp
      (Arithmetic.EApp operator (desugarSyntax left))
      (desugarSyntax right)

desugar :: Arithmetic.Exp -> Pure.Exp
desugar expression = case expression of
  Arithmetic.EVar name -> Pure.EVar (pureName name)
  Arithmetic.EApp function argument ->
    Pure.EApp (desugar function) (desugar argument)
  Arithmetic.EAbs name body -> Pure.EAbs (pureName name) (desugar body)
  Arithmetic.ENat nat -> encodeNatural nat
  Arithmetic.EZero -> encodeNatural 0
  Arithmetic.EFalseLit -> encodeFalse
  Arithmetic.ETrueLit -> encodeTrue
  Arithmetic.EIntPos nat -> encodeInteger nat
  Arithmetic.EIntNeg nat -> encodeInteger (negate nat)
  Arithmetic.ENegOp -> integerNegate
  Arithmetic.EZAddOp -> integerAdd
  Arithmetic.EZSubOp -> integerSubtract
  Arithmetic.EAddOp -> naturalAdd
  Arithmetic.ESubOp -> naturalSubtract
  Arithmetic.ESuccOp -> naturalSuccessor
  Arithmetic.EPredOp -> naturalPredecessor
  Arithmetic.EMulOp -> naturalMul
  Arithmetic.EPowOp -> naturalPow
  Arithmetic.EFalse -> encodeFalse
  Arithmetic.ETrue -> encodeTrue
  Arithmetic.EAndOp -> booleanAnd
  Arithmetic.EOrOp -> booleanOr
  Arithmetic.ENotOp -> booleanNot
  Arithmetic.EPair -> encodePair
  Arithmetic.EFst -> encodeFst
  Arithmetic.ESnd -> encodeSnd
  Arithmetic.EAdd left right ->
    Pure.EApp (Pure.EApp naturalAdd (desugar left)) (desugar right)
  Arithmetic.ESub left right ->
    Pure.EApp (Pure.EApp naturalSubtract (desugar left)) (desugar right)
  Arithmetic.EZAdd left right ->
    Pure.EApp (Pure.EApp integerAdd (desugar left)) (desugar right)
  Arithmetic.EZSub left right ->
    Pure.EApp (Pure.EApp integerSubtract (desugar left)) (desugar right)
  Arithmetic.EMul left right ->
    Pure.EApp (Pure.EApp naturalMul (desugar left)) (desugar right)
  Arithmetic.EPow base exponent ->
    Pure.EApp (Pure.EApp naturalPow (desugar base)) (desugar exponent)
  Arithmetic.ESucc value -> Pure.EApp naturalSuccessor (desugar value)
  Arithmetic.EPred value -> Pure.EApp naturalPredecessor (desugar value)
  Arithmetic.ENeg value -> Pure.EApp integerNegate (desugar value)
  Arithmetic.EAnd left right -> Pure.EApp (Pure.EApp booleanAnd (desugar left)) (desugar right)
  Arithmetic.EOr left right -> Pure.EApp (Pure.EApp booleanOr (desugar left)) (desugar right)
  Arithmetic.ENot value -> Pure.EApp booleanNot (desugar value)

pureName :: Arithmetic.Name -> Pure.Name
pureName (Arithmetic.Name name) = Pure.Name name

-- λt.λf.f
encodeFalse :: Pure.Exp
encodeFalse = Pure.EAbs t (Pure.EAbs f (Pure.EVar f))
 where
  t = Pure.Name "t"
  f = Pure.Name "f"

-- λt.λf.t
encodeTrue :: Pure.Exp
encodeTrue = Pure.EAbs t (Pure.EAbs f (Pure.EVar t))
 where
  t = Pure.Name "t"
  f = Pure.Name "f"

-- λp.λq.p q p
booleanAnd :: Pure.Exp
booleanAnd =
  Pure.EAbs
    p
    (Pure.EAbs q (Pure.EApp (Pure.EApp (Pure.EVar p) (Pure.EVar q)) (Pure.EVar p)))
 where
  p = Pure.Name "p"
  q = Pure.Name "q"

-- λp.λq.p p q
booleanOr :: Pure.Exp
booleanOr =
  Pure.EAbs
    p
    (Pure.EAbs q (Pure.EApp (Pure.EApp (Pure.EVar p) (Pure.EVar p)) (Pure.EVar q)))
 where
  p = Pure.Name "p"
  q = Pure.Name "q"

-- λp.p FALSE TRUE
booleanNot :: Pure.Exp
booleanNot = Pure.EAbs p (Pure.EApp (Pure.EApp (Pure.EVar p) encodeFalse) encodeTrue)
 where
  p = Pure.Name "p"

-- λa.λb.λs.s a b
encodePair :: Pure.Exp
encodePair = Pure.EAbs a (Pure.EAbs b (Pure.EAbs s body))
 where
  a = Pure.Name "a"
  b = Pure.Name "b"
  s = Pure.Name "s"
  body = Pure.EApp (Pure.EApp (Pure.EVar s) (Pure.EVar a)) (Pure.EVar b)

-- Encode an integer as a pair of Church naturals whose difference is the value.
encodeInteger :: Integer -> Pure.Exp
encodeInteger value =
  Pure.EApp
    (Pure.EApp encodePair (encodeNatural (max value 0)))
    (encodeNatural (max (negate value) 0))

-- λp.p (λa.λb.a)
encodeFst :: Pure.Exp
encodeFst = Pure.EAbs p (Pure.EApp (Pure.EVar p) selector)
 where
  p = Pure.Name "p"
  a = Pure.Name "a"
  b = Pure.Name "b"
  selector = Pure.EAbs a (Pure.EAbs b (Pure.EVar a))

-- λp.p (λa.λb.b)
encodeSnd :: Pure.Exp
encodeSnd = Pure.EAbs p (Pure.EApp (Pure.EVar p) selector)
 where
  p = Pure.Name "p"
  a = Pure.Name "a"
  b = Pure.Name "b"
  selector = Pure.EAbs a (Pure.EAbs b (Pure.EVar b))

-- λp.PAIR (SND p) (FST p)
integerNegate :: Pure.Exp
integerNegate = Pure.EAbs p body
 where
  p = Pure.Name "p"
  first = Pure.EApp encodeSnd (Pure.EVar p)
  second = Pure.EApp encodeFst (Pure.EVar p)
  body = Pure.EApp (Pure.EApp encodePair first) second

-- λp.λq.PAIR (ADD (FST p) (FST q)) (ADD (SND p) (SND q))
integerAdd :: Pure.Exp
integerAdd = integerCombine encodeFst encodeSnd

-- λp.λq.PAIR (ADD (FST p) (SND q)) (ADD (SND p) (FST q))
integerSubtract :: Pure.Exp
integerSubtract = integerCombine encodeSnd encodeFst

integerCombine :: Pure.Exp -> Pure.Exp -> Pure.Exp
integerCombine rightFirst rightSecond =
  Pure.EAbs p (Pure.EAbs q (apply (apply encodePair first) second))
 where
  p = Pure.Name "p"
  q = Pure.Name "q"
  apply = Pure.EApp
  first =
    apply
      (apply naturalAdd (apply encodeFst (Pure.EVar p)))
      (apply rightFirst (Pure.EVar q))
  second =
    apply
      (apply naturalAdd (apply encodeSnd (Pure.EVar p)))
      (apply rightSecond (Pure.EVar q))

{-
0: λf.λx.x
1: λf.λx.f x
2: λf.λx.f (f x)
3: λf.λx.f (f (f x))
-}
encodeNatural :: Integer -> Pure.Exp
encodeNatural nat =
  Pure.EAbs f (Pure.EAbs x (go nat (Pure.EVar x)))
 where
  f = Pure.Name "f"
  x = Pure.Name "x"
  go 0 result = result
  go remaining result = go (remaining - 1) (Pure.EApp (Pure.EVar f) result)

-- λn.λf.λx.f (n f x)
naturalSuccessor :: Pure.Exp
naturalSuccessor =
  Pure.EAbs n (Pure.EAbs f (Pure.EAbs x body))
 where
  n = Pure.Name "n"
  f = Pure.Name "f"
  x = Pure.Name "x"
  body =
    Pure.EApp
      (Pure.EVar f)
      (Pure.EApp (Pure.EApp (Pure.EVar n) (Pure.EVar f)) (Pure.EVar x))

-- λn.λf.λx.n (λg.λh.h (g f)) (λu.x) (λu.u)
naturalPredecessor :: Pure.Exp
naturalPredecessor =
  Pure.EAbs n (Pure.EAbs f (Pure.EAbs x body))
 where
  n = Pure.Name "n"
  f = Pure.Name "f"
  x = Pure.Name "x"
  g = Pure.Name "g"
  h = Pure.Name "h"
  u = Pure.Name "u"
  step =
    Pure.EAbs
      g
      (Pure.EAbs h (Pure.EApp (Pure.EVar h) (Pure.EApp (Pure.EVar g) (Pure.EVar f))))
  initial = Pure.EAbs u (Pure.EVar x)
  identity = Pure.EAbs u (Pure.EVar u)
  body = Pure.EApp (Pure.EApp (Pure.EApp (Pure.EVar n) step) initial) identity

-- λm.λn.λf.λx.m f (n f x)
naturalAdd :: Pure.Exp
naturalAdd =
  Pure.EAbs m (Pure.EAbs n (Pure.EAbs f (Pure.EAbs x body)))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
  f = Pure.Name "f"
  x = Pure.Name "x"
  apply = Pure.EApp
  body =
    apply
      (apply (Pure.EVar m) (Pure.EVar f))
      (apply (apply (Pure.EVar n) (Pure.EVar f)) (Pure.EVar x))

-- λm.λn.n PRED m
naturalSubtract :: Pure.Exp
naturalSubtract =
  Pure.EAbs
    m
    ( Pure.EAbs
        n
        (Pure.EApp (Pure.EApp (Pure.EVar n) naturalPredecessor) (Pure.EVar m))
    )
 where
  m = Pure.Name "m"
  n = Pure.Name "n"

-- λm.λn.λf.m (n f)
naturalMul :: Pure.Exp
naturalMul =
  Pure.EAbs m (Pure.EAbs n (Pure.EAbs f body))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
  f = Pure.Name "f"
  body = Pure.EApp (Pure.EVar m) (Pure.EApp (Pure.EVar n) (Pure.EVar f))

-- λm.λn.n m
naturalPow :: Pure.Exp
naturalPow =
  Pure.EAbs m (Pure.EAbs n (Pure.EApp (Pure.EVar n) (Pure.EVar m)))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
