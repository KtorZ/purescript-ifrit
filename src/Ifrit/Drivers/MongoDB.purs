module Ifrit.Drivers.MongoDB
  ( class Ingest
  , Expression(..)
  , ingest
  ) where

import Prelude
import Data.Argonaut.Core(Json, stringify)
import Data.Argonaut.Encode(class EncodeJson, encodeJson)
import Data.StrMap(StrMap)
import Data.StrMap(fromFoldable) as M
import Data.List(List)
import Data.List(fromFoldable) as L
import Data.Tuple(Tuple(..))
import Ifrit.Core(Stage(..), Reduce(..), Map(..), Terminal(..))


-- CLASSES

class Ingest stage where
  ingest :: stage -> Expression


-- TYPES

data Expression
  = ValueString String
  | ValueBoolean Boolean
  | ValueNumber Number
  | Object (StrMap Expression)
  | List (List Expression)


str :: String -> Expression
str s = ValueString s


bool :: Boolean -> Expression
bool b = ValueBoolean b


number :: Number -> Expression
number n = ValueNumber n


object :: Array (Tuple String Expression) -> Expression
object xs = Object $ M.fromFoldable xs


singleton :: String -> Expression -> Expression
singleton k x = Object $ M.fromFoldable [Tuple k x]


list :: Array Expression -> Expression
list xs = List $ L.fromFoldable xs

infix 7 Tuple as :-


-- UTILITIES

selector :: Terminal -> Expression
selector (Field f) = str ("$$this." <> f)
selector (ConstantString c) = str c
selector (ConstantBoolean c) = bool c
selector (ConstantNumber c) = number c


-- INSTANCES :: ingest

instance ingestStage :: Ingest Stage where
  ingest (Map m) =
    singleton "$project" $ Object (map ingest m)


instance ingestMapOperator :: Ingest Map where
  ingest (Project t) =
    ingest t
  ingest (Inject src (Avg target)) =
    let
      src' = ingest src
      sum = list
        [ str "$$value"
        , selector target
        ]
      reduce = object
        [ "input" :- src'
        , "initialValue" :- (number 0.0)
        , "in" :- (singleton "$add" sum)
        ]
      divide = list
        [ singleton "$reduce" reduce
        , singleton "$size" src'
        ]
    in
      singleton "$divide" divide


instance ingestReduce :: Ingest Reduce where
  ingest (Avg t) =
    singleton "$avg" $ ingest t


instance ingestTerminal :: Ingest Terminal where
  ingest (Field f) =
    ValueString $ "$" <> f
  ingest (ConstantString c) =
    ValueString c
  ingest (ConstantBoolean c) =
    ValueBoolean c
  ingest (ConstantNumber c) =
    ValueNumber c


instance ingestArray :: Ingest a => Ingest (Array a) where
  ingest =
    L.fromFoldable >>> map ingest >>> List

-- INSTANCE :: ENCODEJSON

instance encodeJsonExpression :: (EncodeJson String, EncodeJson Int, EncodeJson (StrMap Json), EncodeJson (List Json))
  => EncodeJson Expression where
  encodeJson (ValueString s) =
    encodeJson s
  encodeJson (ValueBoolean b) =
    encodeJson b
  encodeJson (ValueNumber n) =
    encodeJson n
  encodeJson (Object m) =
    encodeJson $ encodeJson <$> m
  encodeJson (List xs) =
    encodeJson $ encodeJson <$> xs


-- INSTANCE :: SHOW

instance showExpression :: EncodeJson Expression => Show Expression where
  show = encodeJson >>> stringify