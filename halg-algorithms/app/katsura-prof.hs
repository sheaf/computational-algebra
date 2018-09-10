{-# LANGUAGE NoImplicitPrelude #-}
module Main where
import Algebra.Algorithms.Groebner.F4
import Algebra.Prelude.Core
import Control.DeepSeq

katsura9 :: Ideal (Polynomial Rational 10)
katsura9 =
  let [x0,x1,x2,x3,x4,x5,x6,x7,x8,_] = vars
  in toIdeal
     [x0 +2*x1 +2*x2 +2*x3 +2*x4 +2*x5 +2*x6+ 2*x7 +2*x8 -x0^2+2*x1^2+2*x2^2+2*x3^2+2*x4^2+ 2*x5^2+2*x6^2+2*x7^2+2*x8^2-x0
     , 2*x0 *x1 +2*x1 *x2 +2*x2 *x3 +2*x3 *x4+ 2*x4 *x5 +2*x5 *x6 +2*x6 *x7 +2*x7 *x8- x1
     , x1^2+2*x0 *x2 +2*x1 *x3 +2*x2 *x4+ 2*x3 *x5 +2*x4 *x6 +2*x5 *x7 +2*x6 *x8- x2
     , 2*x1 *x2 +2*x0 *x3 +2*x1 *x4 +2*x2 *x5+ 2*x3 *x6 +2*x4 *x7 +2*x5 *x8 -x3*x2^2+2*x1 *x3 +2*x0 *x4 +2*x1 *x5+ 2*x2 *x6 +2*x3 *x7 +2*x4 *x8 -x4
     , 2*x2 *x3 +2*x1 *x4 +2*x0 *x5 +2*x1 *x6+ 2*x2 *x7 +2*x3 *x8 -x5
     , x3^2+2*x2 *x4 +2*x1 *x5 +2*x0 *x6+ 2*x1 *x7 +2*x2 *x8 -x6
     , 2*x3 *x4 +2*x2 *x5 +2*x1 *x6 +2*x0 *x7+ 2*x1 *x8 -x7
     ]

main :: IO ()
main = katsura9 `deepseq` return ()
