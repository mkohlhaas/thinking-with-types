{-# LANGUAGE AllowAmbiguousTypes, DataKinds, GADTs, TypeFamilies, UndecidableInstances, UnicodeSyntax #-}

module OpenSum where

import Data.Kind     (Type)
import Data.Proxy    (Proxy (Proxy))
import Fcf           (Eval, Exp, FindIndex, FromMaybe, Stuck, TyEq, type (=<<))
import GHC.TypeLits  (ErrorMessage (ShowType, Text, (:$$:), (:<>:)), KnownNat, Nat, TypeError, natVal)
import Unsafe.Coerce (unsafeCoerce)

type OpenSum :: (k → Type) → [k] → Type
data OpenSum f ts where
  UnsafeOpenSum :: Int -> f t -> OpenSum f ts

type FindElem :: k → [k] → Exp Nat
type FindElem key ts = FromMaybe Stuck =<< FindIndex (TyEq key) ts

type Member t ts = KnownNat (Eval (FindElem t ts))

findElem ∷ ∀ t ts. Member t ts ⇒ Int
findElem = fromIntegral . natVal $ Proxy @(Eval (FindElem t ts))

inj ∷ ∀ f t ts. Member t ts ⇒ f t → OpenSum f ts
inj = UnsafeOpenSum (findElem @t @ts)

type FriendlyFindElem :: (k → Type) → k → [k] → Exp Nat
type family FriendlyFindElem f t ts where
  FriendlyFindElem f t ts =
    FromMaybe
      ( TypeError
          ( 'Text "Attempted to call `friendlyPrj' to produce a `"
              ':<>: 'ShowType (f t)
              ':<>: 'Text "'."
              ':$$: 'Text "But the OpenSum can only contain one of:"
              ':$$: 'Text "  "
                ':<>: 'ShowType ts
          )
      )
      =<< FindIndex (TyEq t) ts

prj ∷ ∀ f t ts. Member t ts ⇒ OpenSum f ts → Maybe (f t)
prj (UnsafeOpenSum i f) =
  if i == findElem @t @ts -- ! 1
    then Just $ unsafeCoerce f -- ! 2
    else Nothing

friendlyPrj ∷ ∀ f t ts. (KnownNat (Eval (FriendlyFindElem f t ts)), Member t ts) ⇒ OpenSum f ts → Maybe (f t)
friendlyPrj = prj

weaken ∷ OpenSum f ts → OpenSum f (t ': ts)
weaken (UnsafeOpenSum n t) = UnsafeOpenSum (n + 1) t

decompose ∷ OpenSum f (t ': ts) → Either (f t) (OpenSum f ts)
decompose (UnsafeOpenSum 0 t) = Left $ unsafeCoerce t
decompose (UnsafeOpenSum n t) = Right $ UnsafeOpenSum (n - 1) t

match ∷ ∀ f ts b. (∀ t. f t → b {- -- ! 1 -}) → OpenSum f ts → b
match fn (UnsafeOpenSum _ t) = fn t

instance Eq (OpenSum f '[]) where
  _ == _ = True

instance (Eq (f t), Eq (OpenSum f ts)) ⇒ Eq (OpenSum f (t ': ts)) where
  a == b = decompose a == decompose b
