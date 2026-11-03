-- | Expand arithmetic and Boolean syntax into pure lambda calculus.
module Desugar (desugar) where

import qualified ArithmeticLambda.Abs as Arithmetic
import qualified PureLambda.Abs as Pure

desugar :: Arithmetic.Exp -> Pure.Exp
desugar expression = case expression of
  Arithmetic.EVar name -> Pure.EVar (pureName name)
  Arithmetic.EApp function argument ->
    Pure.EApp (desugar function) (desugar argument)
  Arithmetic.EAbs name body -> Pure.EAbs (pureName name) (desugar body)
  Arithmetic.ENat nat -> encodeNatural nat
  Arithmetic.EIntPos nat -> encodeInteger nat
  Arithmetic.EIntNeg nat -> encodeInteger (negate nat)
  Arithmetic.ENegOp -> integerNegate
  Arithmetic.EAddOp -> naturalAdd
  Arithmetic.EMulOp -> naturalMul
  Arithmetic.EPowOp -> naturalPow
  Arithmetic.EFalse -> encodeFalse
  Arithmetic.ETrue -> encodeTrue
  Arithmetic.EPair -> encodePair
  Arithmetic.EFst -> encodeFst
  Arithmetic.ESnd -> encodeSnd
  Arithmetic.EAdd left right ->
    Pure.EApp (Pure.EApp naturalAdd (desugar left)) (desugar right)
  Arithmetic.EMul left right ->
    Pure.EApp (Pure.EApp naturalMul (desugar left)) (desugar right)
  Arithmetic.EPow base exponent ->
    Pure.EApp (Pure.EApp naturalPow (desugar base)) (desugar exponent)
  Arithmetic.ENeg value -> Pure.EApp integerNegate (desugar value)

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
