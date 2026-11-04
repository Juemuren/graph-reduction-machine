-- | Expand Church-encoded built-ins into pure lambda calculus.
module Expand (expand) where

import qualified CoreLambda.Abs as Core
import qualified PureLambda.Abs as Pure

expand :: Core.Exp -> Pure.Exp
expand expression = case expression of
  Core.EVar name -> Pure.EVar (pureName name)
  Core.EApp function argument -> Pure.EApp (expand function) (expand argument)
  Core.EAbs name body -> Pure.EAbs (pureName name) (expand body)
  Core.EZero -> encodeNatural 0
  Core.ESucc -> naturalSuccessor
  Core.EPred -> naturalPredecessor
  Core.EAdd -> naturalAdd
  Core.ESub -> naturalSubtract
  Core.EMul -> naturalMul
  Core.EPow -> naturalPow
  Core.EIsZero -> naturalIsZero
  Core.ELeq -> naturalLeq
  Core.EEq -> naturalEqual
  Core.EStep -> naturalStep
  Core.EDiv -> naturalDivide
  Core.EMod -> naturalModulo
  Core.EFalse -> encodeFalse
  Core.ETrue -> encodeTrue
  Core.EAnd -> booleanAnd
  Core.EOr -> booleanOr
  Core.ENot -> booleanNot
  Core.EPair -> encodePair
  Core.EFst -> encodeFst
  Core.ESnd -> encodeSnd
  Core.ENeg -> integerNegate
  Core.EZAbs -> integerAbsolute
  Core.EZAdd -> integerAdd
  Core.EZSub -> integerSubtract
  Core.EZMul -> integerMultiply
  Core.EQAdd -> rationalAdd
  Core.EQSub -> rationalSubtract
  Core.EQMul -> rationalMultiply
  Core.EQDiv -> rationalDivide
  Core.EIf -> churchIf

pureName :: Core.Name -> Pure.Name
pureName (Core.Name name) = Pure.Name name

-- λb.λt.λf.b t f
churchIf :: Pure.Exp
churchIf = Pure.EAbs b (Pure.EAbs t (Pure.EAbs f body))
 where
  b = Pure.Name "b"
  t = Pure.Name "t"
  f = Pure.Name "f"
  body = Pure.EApp (Pure.EApp (Pure.EVar b) (Pure.EVar t)) (Pure.EVar f)

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

-- λp.PAIR (ADD (SUB (FST p) (SND p)) (SUB (SND p) (FST p))) ZERO
integerAbsolute :: Pure.Exp
integerAbsolute = Pure.EAbs p (pair magnitude (encodeNatural 0))
 where
  p = Pure.Name "p"
  first = Pure.EApp encodeFst (Pure.EVar p)
  second = Pure.EApp encodeSnd (Pure.EVar p)
  magnitude =
    apply2
      naturalAdd
      (apply2 naturalSubtract first second)
      (apply2 naturalSubtract second first)

-- λp.λq.PAIR (ADD (FST p) (FST q)) (ADD (SND p) (SND q))
integerAdd :: Pure.Exp
integerAdd = integerCombine encodeFst encodeSnd

-- λp.λq.PAIR (ADD (FST p) (SND q)) (ADD (SND p) (FST q))
integerSubtract :: Pure.Exp
integerSubtract = integerCombine encodeSnd encodeFst

-- (a-b)(c-d) = (ac+bd)-(ad+bc)
integerMultiply :: Pure.Exp
integerMultiply = Pure.EAbs p (Pure.EAbs q (pair first second))
 where
  p = Pure.Name "p"
  q = Pure.Name "q"
  component selector name = Pure.EApp selector (Pure.EVar name)
  product left right = apply2 naturalMul (component left p) (component right q)
  first = apply2 naturalAdd (product encodeFst encodeFst) (product encodeSnd encodeSnd)
  second = apply2 naturalAdd (product encodeFst encodeSnd) (product encodeSnd encodeFst)

-- (a/b) + (c/d) = (ad+cb)/(bd)
rationalAdd :: Pure.Exp
rationalAdd = rationalCombine integerAdd

-- (a/b) - (c/d) = (ad-cb)/(bd)
rationalSubtract :: Pure.Exp
rationalSubtract = rationalCombine integerSubtract

rationalCombine :: Pure.Exp -> Pure.Exp
rationalCombine combine = Pure.EAbs p (Pure.EAbs q (pair numerator denominator))
 where
  p = Pure.Name "p"
  q = Pure.Name "q"
  first name = Pure.EApp encodeFst (Pure.EVar name)
  second name = Pure.EApp encodeSnd (Pure.EVar name)
  numerator =
    apply2
      combine
      (apply2 integerMultiply (first p) (second q))
      (apply2 integerMultiply (first q) (second p))
  denominator = apply2 integerMultiply (second p) (second q)

-- (a/b)(c/d) = ac/bd
rationalMultiply :: Pure.Exp
rationalMultiply = Pure.EAbs p (Pure.EAbs q (pair numerator denominator))
 where
  p = Pure.Name "p"
  q = Pure.Name "q"
  numerator =
    apply2
      integerMultiply
      (Pure.EApp encodeFst (Pure.EVar p))
      (Pure.EApp encodeFst (Pure.EVar q))
  denominator =
    apply2
      integerMultiply
      (Pure.EApp encodeSnd (Pure.EVar p))
      (Pure.EApp encodeSnd (Pure.EVar q))

-- (a/b)/(c/d) = ad/bc; the caller must supply c /= 0.
rationalDivide :: Pure.Exp
rationalDivide = Pure.EAbs p (Pure.EAbs q (pair numerator denominator))
 where
  p = Pure.Name "p"
  q = Pure.Name "q"
  numerator =
    apply2
      integerMultiply
      (Pure.EApp encodeFst (Pure.EVar p))
      (Pure.EApp encodeSnd (Pure.EVar q))
  denominator =
    apply2
      integerMultiply
      (Pure.EApp encodeSnd (Pure.EVar p))
      (Pure.EApp encodeFst (Pure.EVar q))

apply2 :: Pure.Exp -> Pure.Exp -> Pure.Exp -> Pure.Exp
apply2 function first = Pure.EApp (Pure.EApp function first)

pair :: Pure.Exp -> Pure.Exp -> Pure.Exp
pair = apply2 encodePair

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

-- λn.n (λx.FALSE) TRUE
naturalIsZero :: Pure.Exp
naturalIsZero = Pure.EAbs n (apply2 (Pure.EVar n) (Pure.EAbs x encodeFalse) encodeTrue)
 where
  n = Pure.Name "n"
  x = Pure.Name "x"

-- λm.λn.ISZERO (SUB m n)
naturalLeq :: Pure.Exp
naturalLeq = Pure.EAbs m (Pure.EAbs n (Pure.EApp naturalIsZero difference))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
  difference = apply2 naturalSubtract (Pure.EVar m) (Pure.EVar n)

-- λm.λn.AND (LEQ m n) (LEQ n m)
naturalEqual :: Pure.Exp
naturalEqual = Pure.EAbs m (Pure.EAbs n (apply2 booleanAnd left right))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
  left = apply2 naturalLeq (Pure.EVar m) (Pure.EVar n)
  right = apply2 naturalLeq (Pure.EVar n) (Pure.EVar m)

-- Advance (quotient, remainder) by one unit of the dividend.
naturalStep :: Pure.Exp
naturalStep =
  Pure.EAbs
    n
    ( Pure.EAbs
        state
        (Pure.EApp (apply2 churchIf canSubtract subtractBranch) keepBranch)
    )
 where
  n = Pure.Name "n"
  state = Pure.Name "state"
  current = Pure.EVar state
  quotient = Pure.EApp encodeFst current
  remainder = Pure.EApp encodeSnd current
  nextRemainder = Pure.EApp naturalSuccessor remainder
  canSubtract = apply2 naturalLeq (Pure.EVar n) nextRemainder
  subtractBranch =
    pair
      (Pure.EApp naturalSuccessor quotient)
      (apply2 naturalSubtract nextRemainder (Pure.EVar n))
  keepBranch = pair quotient nextRemainder
naturalDivide :: Pure.Exp
naturalDivide = divisionResult encodeFst

naturalModulo :: Pure.Exp
naturalModulo = divisionResult encodeSnd

-- Iterate STEP m times, then select the quotient or remainder.
-- A zero divisor gives (0, dividend).
divisionResult :: Pure.Exp -> Pure.Exp
divisionResult selector = Pure.EAbs m (Pure.EAbs n (Pure.EApp selector selected))
 where
  m = Pure.Name "m"
  n = Pure.Name "n"
  step = Pure.EApp naturalStep (Pure.EVar n)
  result = apply2 (Pure.EVar m) step (pair (encodeNatural 0) (encodeNatural 0))
  zeroDivisor = Pure.EApp naturalIsZero (Pure.EVar n)
  onZero = pair (encodeNatural 0) (Pure.EVar m)
  selected = Pure.EApp (apply2 churchIf zeroDivisor onZero) result
