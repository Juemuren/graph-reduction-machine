-- | Expand arithmetic syntax into pure lambda calculus.
module Desugar (desugar) where

import qualified ArithmeticLambda.Abs as Arithmetic
import qualified PureLambda.Abs as Pure

desugar :: Arithmetic.Exp -> Pure.Exp
desugar expression = case expression of
  Arithmetic.EVar name -> Pure.EVar (pureName name)
  Arithmetic.EApp function argument ->
    Pure.EApp (desugar function) (desugar argument)
  Arithmetic.EAbs name body -> Pure.EAbs (pureName name) (desugar body)
  Arithmetic.ENat number -> churchNumeral number
  Arithmetic.EAdd left right ->
    Pure.EApp (Pure.EApp churchAdd (desugar left)) (desugar right)
  Arithmetic.EMul left right ->
    Pure.EApp (Pure.EApp churchMul (desugar left)) (desugar right)
  Arithmetic.EPow base exponent ->
    Pure.EApp (Pure.EApp churchPow (desugar base)) (desugar exponent)

pureName :: Arithmetic.Name -> Pure.Name
pureName (Arithmetic.Name name) = Pure.Name name

{-
0: λf.λx.x
1: λf.λx.f x
2: λf.λx.f (f x)
3: λf.λx.f (f (f x))
-}
churchNumeral :: Integer -> Pure.Exp
churchNumeral number =
  Pure.EAbs f (Pure.EAbs x (go number (Pure.EVar x)))
 where
  f = Pure.Name "f"
  x = Pure.Name "x"
  go 0 result = result
  go remaining result = go (remaining - 1) (Pure.EApp (Pure.EVar f) result)

-- λm.λn.λf.λx.m f (n f x)
churchAdd :: Pure.Exp
churchAdd =
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
churchMul :: Pure.Exp
churchMul =
  Pure.EAbs m (Pure.EAbs n (Pure.EAbs f body))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
  f = Pure.Name "f"
  body = Pure.EApp (Pure.EVar m) (Pure.EApp (Pure.EVar n) (Pure.EVar f))

-- λm.λn.n m
churchPow :: Pure.Exp
churchPow =
  Pure.EAbs m (Pure.EAbs n (Pure.EApp (Pure.EVar n) (Pure.EVar m)))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
