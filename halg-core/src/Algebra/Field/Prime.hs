{-# LANGUAGE DataKinds, FlexibleContexts, FlexibleInstances, GADTs         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving, LambdaCase, MultiParamTypeClasses #-}
{-# LANGUAGE MultiWayIf, PolyKinds, QuantifiedConstraints, RankNTypes      #-}
{-# LANGUAGE ScopedTypeVariables, TemplateHaskell, TypeApplications        #-}
{-# LANGUAGE TypeFamilies, TypeOperators, UndecidableInstances             #-}
{-# LANGUAGE UndecidableSuperClasses                                       #-}
{-# OPTIONS_GHC -fplugin Data.Singletons.TypeNats.Presburger #-}
-- | Prime fields
module Algebra.Field.Prime
  ( F(), IsPrimeChar,
    naturalRepr, reifyPrimeField, withPrimeField,
    modNat, modNat', modRat, modRat',
    FiniteField(..), order,
    -- * Auxiliary interfaces
    HasPrimeField(..),
    -- ** Internals
    wrapF, liftFUnary, liftBinF
  ) where
import Algebra.Arithmetic            (modPow)
import Algebra.Field.Finite
import Algebra.Normed
import Algebra.Ring.Polynomial.Class (PrettyCoeff (..), ShowSCoeff (..))

import           AlgebraicPrelude
import           Control.DeepSeq              (NFData (..))
import           Control.Monad.Random         (uniform)
import           Control.Monad.Random         (runRand)
import           Control.Monad.Random         (Random (..))
import qualified Data.Coerce                  as C
import           Data.Kind                    (Constraint, Type)
import           Data.Maybe                   (fromMaybe)
import           Data.Proxy                   (Proxy (..), asProxyTypeOf)
import qualified Data.Ratio                   as R
import           Data.Reflection              (Reifies (reflect), reifyNat)
import           Data.Singletons.Prelude
import           GHC.Read
import           GHC.TypeLits                 (KnownNat)
import           GHC.TypeNats                 (Nat, natVal)
import           Language.Haskell.TH          (litT, numTyLit)
import           Numeric.Algebra              (char)
import           Numeric.Algebra              (Natural)
import qualified Numeric.Algebra              as NA
import           Numeric.Semiring.ZeroProduct (ZeroProductSemiring)
import qualified Prelude                      as P

-- | Prime field of characteristic @p@.
--   @p@ should be prime, and not statically checked.
newtype F (p :: k) = F { runF :: F' p }
  -- deriving (NFData)

type WORD_MAX_BOUND =
  $(litT $ numTyLit $ floor @Double
    $ sqrt $ fromIntegral $ maxBound @Int)
type F' (p :: k) = F_Aux k p
type family F_Aux (k :: Type) (p :: k) where
  F_Aux Nat p =
    F_Nat_Aux (WORD_MAX_BOUND <= p)
  F_Aux k p = Integer

type family F_Nat_Aux (oob :: Bool) where
  F_Nat_Aux 'True  = Integer
  F_Nat_Aux 'False = Int

instance {-# OVERLAPPING #-} KnownNat p => NFData (F p) where
  {-# INLINE rnf #-}
  rnf = case sing @WORD_MAX_BOUND %<= sing @p of
    STrue -> rnf . runF
    SFalse -> rnf .runF

instance {-# OVERLAPPABLE #-} NFData (F (p :: Type)) where
  rnf = rnf . runF

instance IsPrimeChar p => Read (F p) where
  readPrec = fromInteger <$> readPrec

class HasPrimeField kind where
  type CharInfo (p :: kind) :: Constraint
  charInfo_ :: CharInfo (p :: kind) => pxy p -> Integer
  liftFUnary_
    :: CharInfo p
    => (forall x. (Show x, Integral x) => x -> x)
    -> F (p :: kind) -> F p
  wrapF_ :: CharInfo p
    => (forall x. (Show x, Integral x) => x)
    -> F (p :: kind)
  unwrapF
    :: CharInfo p
    => (forall x. (Show x, Integral x) => x -> a)
    -> F (p :: kind) -> a

charInfo :: IsPrimeChar p => pxy p -> Integer
{-# INLINE charInfo #-}
charInfo = charInfo_

{-# INLINE liftFUnary #-}
liftFUnary
  :: forall p. IsPrimeChar p
  => (forall x. Integral x => x -> x)
  -> F p -> F p
liftFUnary f = liftFUnary_ $
  (`mod` fromInteger (charInfo @p Proxy)) . f

wrapF
  :: forall p. (IsPrimeChar p)
  => (forall x. Integral x => x)
  -> F (p :: kind)
{-# INLINE wrapF #-}
wrapF = \s -> wrapF_ (unwrapIntegral $ s `rem` fromInteger (charInfo @p Proxy))

unwrapBinF
  :: IsPrimeChar p
  => (forall x. Integral x => x -> x -> a)
  -> F p -> F p -> a
{-# INLINE unwrapBinF #-}
unwrapBinF f = unwrapF $ \i -> unwrapF $ \j -> f i (fromIntegral j)

liftBinF
  :: IsPrimeChar p
  => (forall x. Integral x => x -> x -> x)
  -> F p -> F p -> F p
{-# INLINE liftBinF #-}
liftBinF f = unwrapBinF $ \x y -> wrapF $ fromIntegral $ f x y

instance {-# OVERLAPPING #-}  HasPrimeField Nat where
  type CharInfo n = KnownNat n
  {-# INLINE charInfo_ #-}
  charInfo_ = fromIntegral . natVal
  {-# INLINE liftFUnary_ #-}
  liftFUnary_ f = \(F i :: F p) ->
    case sing @WORD_MAX_BOUND %<= sing @p of
      STrue -> F $ f i
      SFalse -> F $ f i
  {-# INLINE unwrapF #-}
  unwrapF f = \(F i :: F p) ->
    case sing @WORD_MAX_BOUND %<= sing @p of
      STrue -> f i
      SFalse -> f i
  {-# INLINE wrapF_ #-}
  wrapF_ s =
    (case sing @WORD_MAX_BOUND %<= sing @p of
      STrue -> F s
      SFalse -> F s)
      :: forall p. KnownNat p => F (p :: Nat)

instance HasPrimeField Type where
  type CharInfo n = Reifies n Integer
  charInfo_ = reflect
  liftFUnary_ f = \(F p) -> F $ f p
  wrapF_ = F
  unwrapF f = \(F p) -> f p

class (HasPrimeField k, Reifies p Integer, CharInfo p)
  => IsPrimeChar (p :: k)
instance (HasPrimeField k, Reifies p Integer, CharInfo p)
  => IsPrimeChar (p :: k)

modNat :: IsPrimeChar (p :: k) => Integer -> F p
modNat = modNat' Proxy
{-# INLINE modNat #-}

modNat' :: forall proxy (p :: k). IsPrimeChar p => proxy (F p) -> Integer -> F p
modNat' _ i = wrapF $
  let p = reflect (Proxy :: Proxy p)
  in unwrapIntegral $ fromInteger i `rem` fromInteger p
{-# INLINE modNat' #-}

reifyPrimeField
  :: Integer
  -> (forall p. IsPrimeChar (p :: Nat) => Proxy (F p) -> a) -> a
reifyPrimeField p f = reifyNat p (f . proxyF)

withPrimeField :: Integer -> (forall p. IsPrimeChar (p :: Nat) => F p) -> Integer
withPrimeField p f = reifyPrimeField p $ unwrapF toInteger . asProxyTypeOf f

naturalRepr :: IsPrimeChar p => F p -> Integer
naturalRepr = unwrapF toInteger

proxyF :: Proxy (a :: k) -> Proxy (F a)
proxyF Proxy = Proxy

instance IsPrimeChar p => Eq (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Eq (F p) #-}
  (==) = unwrapBinF (==)

instance IsPrimeChar p => Normed (F p) where
  type Norm (F p) = Integer
  norm = unwrapF toInteger
  liftNorm = modNat

instance IsPrimeChar p => P.Num (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => P.Num (F p) #-}
  fromInteger = fromInteger'
  {-# INLINE fromInteger #-}

  (+) = C.coerce ((P.+) :: WrapAlgebra (F p) -> WrapAlgebra (F p) -> WrapAlgebra (F p))
  {-# INLINE (+) #-}

  (-) = C.coerce ((P.-) :: WrapAlgebra (F p) -> WrapAlgebra (F p) -> WrapAlgebra (F p))
  {-# INLINE (-) #-}

  negate = C.coerce (P.negate :: WrapAlgebra (F p) -> WrapAlgebra (F p))
  {-# INLINE negate #-}

  (*) = C.coerce ((P.*) :: WrapAlgebra (F p) -> WrapAlgebra (F p) -> WrapAlgebra (F p))
  {-# INLINE (*) #-}

  abs = id
  signum = liftFUnary $ \case
    0 -> 0
    _ -> 1

pows :: forall p a1. (P.Integral a1, IsPrimeChar p) => F p -> a1 -> F p
{-# INLINE pows #-}
pows = flip $ \n -> liftFUnary $ \a ->
  unwrapIntegral $
  modPow
    (WrapIntegral a)
    (WrapIntegral $ fromInteger $ reflect $ Proxy @p) (toInteger n)

instance IsPrimeChar p => NA.Additive (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Additive (F p) #-}
  (+) = liftBinF (P.+)
  {-# INLINE (+) #-}
  sinnum1p n = liftFUnary $ \k -> (1 P.+ P.fromIntegral n) P.* k
  {-# INLINE sinnum1p #-}

instance IsPrimeChar p => NA.Multiplicative (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Multiplicative (F p) #-}
  (*) = liftBinF (P.*)
  {-# INLINE (*) #-}

  pow1p n p = pows n (p P.+ 1)
  {-# INLINE pow1p #-}

instance IsPrimeChar p => NA.Monoidal (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Monoidal (F p) #-}
  zero = wrapF 0
  {-# INLINE zero #-}
  sinnum n = liftFUnary $ \k -> P.fromIntegral n P.* k
  {-# INLINE sinnum #-}

instance IsPrimeChar p => NA.LeftModule Natural (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => LeftModule Natural (F p) #-}
  (.*) n = liftFUnary $ \p -> fromIntegral n P.* p
  {-# INLINE (.*) #-}

instance IsPrimeChar p => NA.RightModule Natural (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => RightModule Natural (F p) #-}
  (*.) = flip (.*)
  {-# INLINE (*.) #-}

instance IsPrimeChar p => NA.LeftModule Integer (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => LeftModule Integer (F p) #-}
  (.*) n = liftFUnary $ \p -> fromIntegral n P.* p
  {-# INLINE (.*) #-}

instance IsPrimeChar p => NA.RightModule Integer (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => RightModule Integer (F p) #-}
  (*.) = flip (.*)
  {-# INLINE (*.) #-}

instance IsPrimeChar p => NA.Group (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Group (F p) #-}
  (-) = liftBinF (P.-)
  {-# INLINE (-) #-}

  negate = liftFUnary P.negate
  {-# INLINE negate #-}

instance IsPrimeChar p => NA.Abelian (F p)

instance IsPrimeChar p => NA.Semiring (F p)

instance IsPrimeChar p => NA.Rig (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Rig (F p) #-}
  fromNatural = modNat . P.fromIntegral
  {-# INLINE fromNatural #-}

instance IsPrimeChar p => NA.Ring (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Ring (F p) #-}
  fromInteger = modNat
  {-# INLINE fromInteger #-}

instance IsPrimeChar p => NA.DecidableZero (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => DecidableZero (F p) #-}
  isZero = unwrapF (== 0)

instance IsPrimeChar p => NA.Unital (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Unital (F p) #-}
  one = wrapF 1
  {-# INLINE one #-}
  pow = pows
  {-# INLINE pow #-}

instance IsPrimeChar p => DecidableUnits (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => DecidableUnits (F p) #-}
  isUnit = unwrapF (/= 0)
  {-# INLINE isUnit #-}

  recipUnit = unwrapF $ \k ->
    let p = WrapIntegral $ fromInteger $ charInfo @p Proxy
        (u,_,r) = head $ euclid p (WrapIntegral k)
    in if u == 1
      then Just $ wrapF $ fromIntegral $ unwrapIntegral $ r `rem` p else Nothing
  {-# INLINE recipUnit #-}

instance (IsPrimeChar p) => DecidableAssociates (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => DecidableAssociates (F p) #-}
  isAssociate p n =
    (isZero p && isZero n) || (not (isZero p) && not (isZero n))
  {-# INLINE isAssociate #-}

instance (IsPrimeChar p) => UnitNormalForm (F p)
instance (IsPrimeChar p) => IntegralDomain (F p)
instance (IsPrimeChar p) => GCDDomain (F p)
instance (IsPrimeChar p) => UFD (F p)
instance (IsPrimeChar p) => PID (F p)
instance (IsPrimeChar p) => ZeroProductSemiring (F p)
instance (IsPrimeChar p) => Euclidean (F p)

instance IsPrimeChar p => Division (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'False)
          => Division (F p) #-}
  recip = fromMaybe (error "recip: not unit") . recipUnit
  {-# INLINE recip #-}
  a / b =  a * recip b
  {-# INLINE (/) #-}
  (^)   = pows
  {-# INLINE (^) #-}

instance IsPrimeChar p => P.Fractional (F p) where
  {-# SPECIALISE instance (IsPrimeChar p, (WORD_MAX_BOUND <= p) ~ 'True)
          => P.Fractional (F p) #-}
  (/) = C.coerce ((P./) :: WrapAlgebra (F p) -> WrapAlgebra (F p) -> WrapAlgebra (F p))
  {-# INLINE (/) #-}

  fromRational r =
    modNat (R.numerator r) * recip (modNat $ R.denominator r)
  {-# INLINE fromRational #-}

  recip = C.coerce (P.recip :: WrapAlgebra (F p) -> WrapAlgebra (F p))
  {-# INLINE recip #-}

instance IsPrimeChar p => NA.Commutative (F p)

instance IsPrimeChar p => NA.Characteristic (F p) where
  char _ = fromIntegral $ reflect (Proxy :: Proxy p)
  {-# INLINE char #-}


instance IsPrimeChar p => Show (F p) where
  showsPrec d = unwrapF $ showsPrec d

instance IsPrimeChar p => PrettyCoeff (F p) where
  showsCoeff d = unwrapF $ \p ->
    if | p == 0 -> Vanished
       | p == 1 -> OneCoeff
       | otherwise -> Positive $ showsPrec d p

instance IsPrimeChar p => FiniteField (F p) where
  power _ = 1
  {-# INLINE power #-}

  elements p = map modNat [0.. fromIntegral (char p) - 1]
  {-# INLINE elements #-}

instance IsPrimeChar p => Random (F p) where
  random = runRand $ uniform (elements Proxy)
  {-# INLINE random #-}
  randomR (a, b) = runRand $ uniform $ map modNat [naturalRepr a..naturalRepr b]
  {-# INLINE randomR #-}

modRat :: FiniteField k => Proxy k -> Fraction Integer -> k
modRat _ q = NA.fromInteger (numerator q) NA./ NA.fromInteger (denominator q)
{-# INLINE modRat #-}

modRat' :: FiniteField k => Fraction Integer -> k
modRat' = modRat Proxy
{-# INLINE modRat' #-}
