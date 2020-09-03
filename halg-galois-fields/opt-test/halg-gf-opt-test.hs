{-# OPTIONS_GHC -fno-hpc -O2 #-}
{-# OPTIONS_GHC -dsuppress-idinfo -dsuppress-coercions
      -dsuppress-type-applications
      -dsuppress-module-prefixes -dsuppress-type-signatures
      -dsuppress-uniques
  #-}
{-# LANGUAGE TemplateHaskell #-}
module Main where
import           Algebra.Field.Galois
import           Algebra.Field.Prime
import           Algebra.Prelude.Core
import qualified Data.Vector           as V
import qualified Data.Vector.Primitive as P
import           Numeric.Algebra       as NA
import           Test.Hspec
import           Test.Inspection

add_gf_2_8 :: GF 2 8 -> GF 2 8 -> GF 2 8
add_gf_2_8 = (NA.+)

add_gf_2_8_Manual
  :: P.Vector (F 2)
  -> P.Vector (F 2)
  -> P.Vector (F 2)
add_gf_2_8_Manual = P.zipWith (NA.+)

checkInspection
  :: Result -> Expectation
checkInspection Success{} = pure ()
checkInspection (Failure msg) =
  fail msg

main :: IO ()
main = hspec $ do
  describe "GF 2 8" $ do
    describe "(NA.+)" $ do
      it "doesn't contain boxed Vector" $
        checkInspection
          $(inspectTest $ 'add_gf_2_8 `hasNoType` ''V.Vector)
      it "doesn't contain type class dictionary" $
        checkInspection
          $(inspectTest $
              hasNoTypeClasses 'add_gf_2_8
            )
      it "is almost equivalent to zipWith (+)" $
        checkInspection
          $(inspectTest $ 'add_gf_2_8 ==- 'add_gf_2_8_Manual)