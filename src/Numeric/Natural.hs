{-# LANGUAGE CPP #-}

#ifdef __GLASGOW_HASKELL__
#define LANGUAGE_DeriveDataTypeable
{-# LANGUAGE DeriveDataTypeable #-}
#endif

#ifndef MIN_VERSION_base
#define MIN_VERSION_base(x,y,z) 1
#endif

#if __GLASGOW_HASKELL__ >= 702
#if defined(MIN_VERSION_hashable) || defined(MIN_VERSION_template_haskell)
{-# LANGUAGE Trustworthy #-}
#else
{-# LANGUAGE Safe #-}
#endif
#endif

-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.Natural
-- Copyright   :  (C) 2011-2014 Edward Kmett,
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  portable
--
-- Natural numbers.
--
-- The "Numeric.Natural" module has become part of `base` starting
-- with `base-4.8.0.0`.
----------------------------------------------------------------------------
module Numeric.Natural ( Natural ) where

import Control.Exception ( throw, ArithException(Underflow) )

#ifdef MIN_VERSION_binary
import Control.Monad (liftM)
import Data.Binary (Binary(..), Get, Word8, Word64, putWord8)
import Data.List (unfoldr)
#endif

import Data.Bits
import Data.Ix

#ifdef LANGUAGE_DeriveDataTypeable
import Data.Data
#endif

#ifdef MIN_VERSION_hashable
import Data.Hashable
#endif

#ifdef MIN_VERSION_template_haskell
import Language.Haskell.TH.Syntax (Lift(..), Exp(LitE), Lit(IntegerL))
#endif

#if MIN_VERSION_base(4,7,0) && !(MIN_VERSION_base(4,8,0))
import Text.Printf (PrintfArg(..), formatInteger)
#endif

-- | Type representing arbitrary-precision non-negative integers.
--
-- Operations whose result would be negative
-- @'throw' ('Underflow' :: 'ArithException')@.
--
-- The 'Natural' type has become part of `base` starting with
-- `base-4.8.0.0`.
newtype Natural = Natural { runNatural :: Integer } deriving
  ( Eq
  , Ord
  , Ix
#ifdef LANGUAGE_DeriveDataTypeable
  , Typeable
#endif
  )

#ifdef MIN_VERSION_hashable
instance Hashable Natural where
#if MIN_VERSION_hashable(1,2,0)
  hashWithSalt p (Natural a) = hashWithSalt p a
#else
  hash (Natural a) = hash a
#endif
#endif

#ifdef LANGUAGE_DeriveDataTypeable
-- This follows the same style as the other integral 'Data' instances
-- defined in "Data.Data"
naturalType :: DataType
naturalType = mkIntType "Numeric.Natural.Natural"

instance Data Natural where
  toConstr x = mkIntegralConstr naturalType x
  gunfold _ z c = case constrRep c of
                    IntConstr x -> z (fromIntegral x)
                    _ -> error $ "Data.Data.gunfold: Constructor " ++ show c
                                 ++ " is not of type Natural"
  dataTypeOf _ = naturalType
#endif

instance Show Natural where
  showsPrec d (Natural n) = showsPrec d n

instance Read Natural where
  readsPrec d = map (\(n, s) -> (Natural n, s)) . filter ((>= 0) . fst) . readsPrec d

instance Num Natural where
  Natural n + Natural m = Natural (n + m)
  {-# INLINE (+) #-}
  Natural n * Natural m = Natural (n * m)
  {-# INLINE (*) #-}
  Natural n - Natural m | result < 0 = throw Underflow
                        | otherwise  = Natural result
    where result = n - m
  {-# INLINE (-) #-}
  abs (Natural n) = Natural n
  {-# INLINE abs #-}
  signum (Natural n) = Natural (signum n)
  {-# INLINE signum #-}
  fromInteger n
    | n >= 0 = Natural n
    | otherwise = throw Underflow
  {-# INLINE fromInteger #-}

instance Bits Natural where
  Natural n .&. Natural m = Natural (n .&. m)
  {-# INLINE (.&.) #-}
  Natural n .|. Natural m = Natural (n .|. m)
  {-# INLINE (.|.) #-}
  xor (Natural n) (Natural m) = Natural (xor n m)
  {-# INLINE xor #-}
  complement _ = error "Bits.complement: Natural complement undefined"
  {-# INLINE complement #-}
  shift (Natural n) = Natural . shift n
  {-# INLINE shift #-}
  rotate (Natural n) = Natural . rotate n
  {-# INLINE rotate #-}
  bit = Natural . bit
  {-# INLINE bit #-}
  setBit (Natural n) = Natural . setBit n
  {-# INLINE setBit #-}
  clearBit (Natural n) = Natural . clearBit n
  {-# INLINE clearBit #-}
  complementBit (Natural n) = Natural . complementBit n
  {-# INLINE complementBit #-}
  testBit = testBit . runNatural
  {-# INLINE testBit #-}
#if __GLASGOW_HASKELL__ >= 707
  bitSizeMaybe _ = Nothing
  {-# INLINE bitSizeMaybe #-}
#endif
  bitSize = error "Natural: bitSize"
  {-# INLINE bitSize #-}
  isSigned _ = False
  {-# INLINE isSigned #-}
  shiftL (Natural n) = Natural . shiftL n
  {-# INLINE shiftL #-}
  shiftR (Natural n) = Natural . shiftR n
  {-# INLINE shiftR #-}
  rotateL (Natural n) = Natural . rotateL n
  {-# INLINE rotateL #-}
  rotateR (Natural n) = Natural . rotateR n
  {-# INLINE rotateR #-}
#if MIN_VERSION_base(4,6,0)
  popCount = popCountDefault
  {-# INLINE popCount #-}
#endif

instance Real Natural where
  toRational (Natural a) = toRational a
  {-# INLINE toRational #-}

instance Enum Natural where
  pred (Natural 0) = throw Underflow
  pred (Natural n) = Natural (pred n)
  {-# INLINE pred #-}
  succ (Natural n) = Natural (succ n)
  {-# INLINE succ #-}
  fromEnum (Natural n) = fromEnum n
  {-# INLINE fromEnum #-}
  toEnum n | n < 0     = error "Natural.toEnum: negative"
           | otherwise = Natural (toEnum n)
  {-# INLINE toEnum #-}

  enumFrom = map Natural . enumFrom . runNatural

  enumFromThen x y
    | x <= y    = map Natural (enumFromThen   (runNatural x) (runNatural y))
    | otherwise = map Natural (enumFromThenTo (runNatural x) (runNatural y) 0)

  enumFromTo x y = map Natural (enumFromTo (runNatural x) (runNatural y))

  enumFromThenTo x x1 y
    = map Natural (enumFromThenTo (runNatural x) (runNatural x1) (runNatural y))

{- NOTE: Using "Data.Coerce", we could instead say:

  enumFrom      = coerce (enumFrom     :: Integer -> [Integer])
  enumFromThen x y
    | x <= y    = coerce (enumFromThen :: Integer -> Integer -> [Integer]) x y
    | otherwise = enumFromThenTo x y 0

  enumFromTo    = coerce (enumFromTo   :: Integer -> Integer -> [Integer])
  enumFromThenTo
    = coerce (enumFromThenTo :: Integer -> Integer -> Integer -> [Integer])
-}

instance Integral Natural where
  quot (Natural a) (Natural b) = Natural (quot a b)
  {-# INLINE quot #-}
  rem (Natural a) (Natural b) = Natural (rem a b)
  {-# INLINE rem #-}
  div (Natural a) (Natural b) = Natural (div a b)
  {-# INLINE div #-}
  mod (Natural a) (Natural b) = Natural (mod a b)
  {-# INLINE mod #-}
  divMod (Natural a) (Natural b) = (Natural q, Natural r) where (q,r) = divMod a b
  {-# INLINE divMod #-}
  quotRem (Natural a) (Natural b) = (Natural q, Natural r) where (q,r) = quotRem a b
  {-# INLINE quotRem #-}
  toInteger = runNatural
  {-# INLINE toInteger #-}

#if MIN_VERSION_base(4,7,0) && !(MIN_VERSION_base(4,8,0))
instance PrintfArg Natural where
  formatArg     = formatInteger . toInteger
  parseFormat _ = parseFormat (undefined :: Integer)
#endif

#ifdef MIN_VERSION_binary
--
-- Fold and unfold an Integer to and from a list of its bytes
--
unroll :: (Integral a, Num a, Bits a) => a -> [Word8]
unroll = unfoldr step
  where
    step 0 = Nothing
    step i = Just (fromIntegral i, i `shiftR` 8)

roll :: (Integral a, Num a, Bits a) => [Word8] -> a
roll   = foldr unstep 0
  where
    unstep b a = a `shiftL` 8 .|. fromIntegral b

-- Fixed-size type for a subset of Natural
type NaturalWord = Word64

instance Binary Natural where
    {-# INLINE put #-}
    put n | n <= hi = do
        putWord8 0
        put (fromIntegral n :: NaturalWord)  -- fast path
     where
        hi = fromIntegral (maxBound :: NaturalWord) :: Natural

    put n = do
        putWord8 1
        put (unroll (abs n))         -- unroll the bytes

    {-# INLINE get #-}
    get = do
        tag <- get :: Get Word8
        case tag of
            0 -> liftM fromIntegral (get :: Get NaturalWord)
            _ -> do bytes <- get
                    return $! roll bytes
#endif

#ifdef MIN_VERSION_template_haskell
instance Lift Natural where
    lift x = return (LitE (IntegerL (fromIntegral x)))
#endif
