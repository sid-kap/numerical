{-# LANGUAGE PolyKinds   #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Numerical.Types.Shape where

import GHC.Magic 
import Data.Data 
import Data.Typeable

import qualified Data.Monoid  as M 
import qualified Data.Functor as Fun 
import qualified  Data.Foldable as F
import qualified Control.Applicative as A 

import Numerical.Types.Nat 

import Prelude hiding  (foldl,foldr,init,scanl,scanr,scanl1,scanr1)



{-
Need to sort out packed+unboxed vs generic approaches
see ShapeAlternatives/ for 

-}

infixr 3 :*
    
 {-
the concern basically boils down to "will it specialize / inline well"

 -}

newtype Only a = Only {
      fromOnly :: a
    } deriving (Eq, Ord, Read, Show, Typeable, Functor)


data Shape (rank :: Nat) a where 
    Nil  :: Shape Z a
    (:*) ::  !(a) -> !(Shape r a ) -> Shape  (S r) a
        --deriving (Typeable)

-- at some point also try data model that
-- has layout be dynamicly reified, but for now
-- keep it phantom typed for sanity / forcing static dispatch.
-- NB: may need to make it more general at some future point
newtype Shaped r a lay = MkShaped (Shape r a)

#if defined(__GLASGOW_HASKELL_) && (__GLASGOW_HASKELL__ >= 707)
deriving instance Typeable Shape 
#endif


{-# INLINE reverseShape #-}
reverseShape :: Shape n a -> Shape n a 
reverseShape Nil = Nil 
reverseShape s@(a :* Nil ) = s 
reverseShape (a:* b :* Nil) = (b:* a :* Nil )
reverseShape (a:* b:* c :* Nil ) = (c :* b :* a :* Nil)



--deriving instance Eq a => Eq (Shape Z a)

--instance   (Eq a,F.Foldable (Shape n), A.Applicative (Shape n)) => Eq (Shape n a) where
--    (==) = \ a  b -> F.foldr (&&) True $ map2 (==) a b 
--    (/=) = \ a  b -> F.foldr (||) False $ map2 (/=) a b 


--instance (Show a, F.Foldable (Shape n ) ) => 

--instance   Eq a => Eq (Shape n a) where
--    (==) = \ a  b -> F.foldr (&&) True $  A.pure ((==) :: a ->a -> Bool) A.<*> a A.<*> b
--    (/=) = \ a  b -> F.foldr (||) False $ A.pure (/= :: a ->a -> Bool) A.<*> a A.<*> b

    -- #if defined( __GLASGOW_HASKELL__ ) &&  ( __GLASGOW_HASKELL__  >= 707)
    --deriving instance Typeable (Shape rank a)
    -- #endif    

type family (TupleRank tup ) :: Nat 


type instance TupleRank () = Z
type instance TupleRank  Int = N1 
 -- TupleRank a = N1  would be incoherent and overlapping
 -- if tuples were polymorphic, or would have to do Only a, which seems ugly
 --
type instance TupleRank (Int,Int) = N2 
type instance TupleRank (Int,Int,Int) = N3
type instance TupleRank (Int,Int,Int,Int) =  N4
type instance TupleRank (Int,Int,Int,Int,Int) = N5 
type instance TupleRank (Int,Int,Int,Int,Int,Int) = N6 
type instance TupleRank (Int,Int,Int,Int,Int,Int,Int) = N7
type instance TupleRank (Int,Int,Int,Int,Int,Int,Int,Int) = N8





class Shapeable (n :: Nat) where
    type  Tuple n  
    --type Tuple n = tup 
-- this should map an int tuple to their rank n 
 
    toShape :: (tup~Tuple n, n ~ TupleRank tup ) => tup -> Shape n Int
    fromShape :: (tup~Tuple n, n ~ TupleRank tup ) => Shape n Int-> tup 


--- should evaluate using TH to generate these instances later
instance Shapeable N0 where
    type Tuple N0 = ()
    toShape _ = Nil 
    fromShape _ = ()

instance Shapeable N1 where
    type Tuple N1 = Int 
    toShape i = i :* Nil 
    fromShape (i :* Nil) = i 

instance Shapeable N2 where
    type Tuple N2 = (Int,Int)
    toShape (x , y)=  x :*  y :* Nil 
    fromShape (x :*  y :* Nil ) = (x,y)

instance Shapeable N3 where
    type Tuple N3 = (Int,Int,Int)
    toShape (x,y,z)=  x :*  y :* z :* Nil 
    fromShape (x :*  y :* z:* Nil ) = (x,y,z)


instance Shapeable N3 where
    type Tuple N3 = (Int,Int,Int)
    toShape (x,y,z,a)=  x :*  y :* z :* a :* Nil 
    fromShape (x :*  y :* z:* a :*  Nil ) = (x,y,z,a)

instance Shapeable N3 where
    type Tuple N3 = (Int,Int,Int)
    toShape (x,y,z,a,b)=  x :*  y :* z :* a :* Nil 
    fromShape (x :*  y :* z:* a :*  Nil ) = (x,y,z,a)

instance Fun.Functor (Shape Z) where
    fmap  = \ _ Nil -> Nil 

instance  (Fun.Functor (Shape r)) => Fun.Functor (Shape (S r)) where
    fmap  = \ f (a :* rest) -> f a :* Fun.fmap f rest 

instance  A.Applicative (Shape Z) where 
    pure = \ _ -> Nil
    (<*>) = \ _  _ -> Nil 

instance  A.Applicative (Shape r)=> A.Applicative (Shape (S r)) where     
    pure = \ a -> a :* (A.pure a)
    (<*>) = \ (f:* fs) (a :* as) ->  f a :* (inline (A.<*>)) fs as 

instance F.Foldable (Shape Z) where
    foldMap = \ _ _ -> M.mempty
    foldl = \ _ init  _ -> init 
    foldr = \ _ init _ -> init 
    foldr' = \_ !init _ -> init 
    foldl' = \_ !init _ -> init   


instance (F.Foldable (Shape r))  => F.Foldable (Shape (S r)) where
    foldMap = \f  (a:* as) -> f a M.<> F.foldMap f as 
    foldl' = \f !init (a :* as) -> let   next = f  init a   in     next `seq`  F.foldl f next as 
    foldr' = \f !init (a :* as ) -> f a $!  F.foldr f init as               
    foldl = \f init (a :* as) -> let   next = f  init a  in    F.foldl f next as 
    foldr = \f init (a :* as ) -> f a $  F.foldr f init as     



--
map2 :: (A.Applicative (Shape r))=> (a->b ->c) -> (Shape r a) -> (Shape r b) -> (Shape r c )
map2 = \f l r -> A.pure f A.<*>  l  A.<*> r 
-- {-# INLINABLE map2 #-}


{-
the scannable ops may be better as a type class, because
i'll be able to get things to specialize better
-}
scanl :: (b->a -> b) -> b -> Shape r a -> Shape r b
scanl f init Nil = Nil 
scanl f init (a:* as) =  res :* scanl f res as 
    where res = f init a 
--  {-# INLINE foldLeftMap #-}    


scanr :: (a -> b -> b ) -> b -> Shape r a -> Shape r b 
scanr f init shs = finalShape
    where
        (accum,!finalShape)= go f init shs
        go   :: (a -> b -> b ) -> b -> Shape r a -> (b  ,Shape r b )
        go f init Nil = (init,Nil)
        go f init (a:* as) = (res, res :*  suffix)
            where 
                (accum,suffix)= go f init as 
                !res =  f a accum
-- may also want to try cpsing it


scanrCPSd :: (a->b ->b) -> b -> Shape r a -> Shape r b 
scanrCPSd  f init shs = go f  init shs (\accum final -> final)
    where
        go :: (a->b->b) -> b -> Shape h a -> (b-> Shape h  b -> c)->c
        go f init Nil cont = cont init Nil 
        go f init (a:* as) cont = 
            go f init as 
                (\ accum suffShape -> 
                    let moreAccum = f a accum in 
                        cont moreAccum (moreAccum:*suffShape) )


