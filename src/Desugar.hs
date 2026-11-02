-- | Expand arithmetic syntax into pure lambda calculus.
module Desugar (desugar) where

import qualified Lambda.Abs as Lambda

desugar :: Lambda.Exp -> Lambda.Exp
desugar expression = case expression of
  Lambda.EVar name -> Lambda.EVar name
  Lambda.EApp function argument ->
    Lambda.EApp (desugar function) (desugar argument)
  Lambda.EAbs name body -> Lambda.EAbs name (desugar body)
  Lambda.ENat number -> churchNumeral number
  Lambda.EAdd left right ->
    Lambda.EApp (Lambda.EApp churchAdd (desugar left)) (desugar right)

-- λf.λx.f^n x
churchNumeral :: Integer -> Lambda.Exp
churchNumeral number =
  Lambda.EAbs f (Lambda.EAbs x (go number (Lambda.EVar x)))
  where
    f = Lambda.Name "f"
    x = Lambda.Name "x"
    go 0 result = result
    go remaining result = go (remaining - 1) (Lambda.EApp (Lambda.EVar f) result)

-- λm.λn.λf.λx.m f (n f x)
churchAdd :: Lambda.Exp
churchAdd =
  Lambda.EAbs m (Lambda.EAbs n (Lambda.EAbs f (Lambda.EAbs x body)))
  where
    m = Lambda.Name "m"
    n = Lambda.Name "n"
    f = Lambda.Name "f"
    x = Lambda.Name "x"
    apply = Lambda.EApp
    body = apply (apply (Lambda.EVar m) (Lambda.EVar f))
                 (apply (apply (Lambda.EVar n) (Lambda.EVar f)) (Lambda.EVar x))
