module Json.Schema.Form.Validation exposing (validation)

import Dict exposing (Dict)
import Form.Error as Error exposing (ErrorValue(..))
import Form.Field
import Form.Validate as Validate exposing (Validation)
import Json.Decode  as Decode exposing (Decoder, Value)
import Json.Encode as Encode
import Json.Schema.Form.UiSchema exposing (unSchemata)
import Json.Schema.Definitions
    exposing
        ( ExclusiveBoundary(..)
        , Items(..)
        , Schema(..)
        , SingleType(..)
        , SubSchema
        , Type(..)
        , blankSchema
        )
import Json.Schema.Form.Encode as Encode
import Json.Schema.Form.Error exposing (CustomErrorValue(..))
import Json.Schema.Form.Format exposing (Format)
import Json.Schema.Form.Regex
import Maybe.Extra as Maybe
import Regex
import Set


type alias Formats =
    Dict String Format


validation : Schema -> Value -> Validation CustomErrorValue Value
validation schema value =
    case schema of
        BooleanSchema bool ->
            if bool then
                Validate.succeed value

            else
                Validate.fail (Validate.customError Invalid)

        ObjectSchema objectSchema ->
            subSchema objectSchema value


subSchema : SubSchema -> Value -> Validation CustomErrorValue Value
subSchema schema value =
    case schema.type_ of
        SingleType type_ ->
            singleType schema type_ value

        _ ->
            Validate.fail (Error.error <| Unimplemented "Only SingleType is implemented.")



-- subSchema : Formats -> SubSchema -> Validation CustomErrorValue Value
-- subSchema formats schema =
--     case schema.type_ of
--         AnyType ->
--             case schema.oneOf of
--                 Just schemata ->
--                     switch formats schemata
--                 Nothing ->
--                     oneOf
--                         [ singleType formats schema IntegerType
--                         , singleType formats schema NumberType
--                         , singleType formats schema StringType
--                         , singleType formats schema ObjectType
--                             |> andThen
--                                 (\a ->
--                                     case a of
--                                         ObjectValue fields ->
--                                             if List.isEmpty fields then
--                                                 fail (customError Invalid)
--                                             else
--                                                 succeed a
--                                         _ ->
--                                             fail (customError Invalid)
--                                 )
--                         , singleType formats schema ArrayType
--                             |> andThen
--                                 (\a ->
--                                     case a of
--                                         ListValue items ->
--                                             if List.isEmpty items then
--                                                 fail (customError Invalid)
--                                             else
--                                                 succeed a
--                                         _ ->
--                                             fail (customError Invalid)
--                                 )
--                         , singleType formats schema BooleanType
--                         ]
--         NullableType type_ ->
--             oneOf
--                 [ singleType formats schema type_
--                 , emptyString |> andThen (\_ -> succeed NullValue)
--                 ]
--         UnionType types ->
--             oneOf (List.map (singleType formats schema) types)
--         SingleType type_ ->
--             singleType formats schema type_


singleType : SubSchema -> SingleType -> Value -> Validation CustomErrorValue Value
singleType schema type_ value =
    case type_ of
        ObjectType ->
            let
                propList = Maybe.withDefault [] <| Maybe.map unSchemata schema.properties
                propKeys = List.map (\(k, v) -> k) propList

                requiredKeys = Maybe.withDefault [] schema.required

                missingKeys = List.filter (\k -> not <| List.member k propKeys) requiredKeys
                -- TODO: emit error on missingKeys
                -- TODO: handle missing keys
            in Validate.validateAll (List.map (\(key, propSchema) _ ->
                Validate.mapErrorPointers (\p -> List.append ["properties", key] p) <| validation propSchema <| Result.withDefault Encode.null <| Decode.decodeValue (Decode.field key Decode.value) value
             ) propList) value  -- List.map (\(k, v) -> v) propList

        IntegerType ->
            Result.map Encode.int <| Validate.int value

        NumberType ->
            Result.map Encode.float <| Validate.float value

        x ->
            Validate.succeed value



-- TODO: implement
-- singleType : Formats -> SubSchema -> SingleType -> Validation CustomErrorValue Value
-- singleType formats schema type_ =
--     case type_ of
--         IntegerType ->
--             int
--                 |> andMaybe constInt schema.const
--                 |> andMaybe multipleOf (Maybe.map round schema.multipleOf)
--                 |> andMaybe minInt (Maybe.map round (minimum schema))
--                 |> andMaybe maxInt (Maybe.map round (maximum schema))
--                 |> andMaybe enumInt schema.enum
--                 |> map IntValue
--         NumberType ->
--             float
--                 |> andMaybe constFloat schema.const
--                 |> andMaybe minFloat (minimum schema)
--                 |> andMaybe maxFloat (maximum schema)
--                 |> andMaybe enumFloat schema.enum
--                 |> map FloatValue
--         StringType ->
--             string
--                 |> andMaybe constString schema.const
--                 |> andMaybe minLength schema.minLength
--                 |> andMaybe maxLength schema.maxLength
--                 |> andMaybe pattern schema.pattern
--                 |> andMaybe enumString schema.enum
--                 |> andMaybe (customFormat formats) schema.format
--                 |> map StringValue
--         BooleanType ->
--             bool
--                 |> andMaybe constBool schema.const
--                 |> map BoolValue
--         ArrayType ->
--             case schema.items of
--                 NoItems ->
--                     list (lazy (\_ -> validation formats blankSchema))
--                         |> map ListValue
--                 ItemDefinition schema_ ->
--                     list (validation formats schema_)
--                         |> andMaybe uniqueItems schema.uniqueItems
--                         |> andMaybe minItems schema.minItems
--                         |> andMaybe maxItems schema.maxItems
--                         |> map ListValue
--                 ArrayOfItems schemaList ->
--                     tuple (List.map (validation formats) schemaList)
--                         |> andMaybe uniqueItems schema.uniqueItems
--                         |> andMaybe minItems schema.minItems
--                         |> andMaybe maxItems schema.maxItems
--                         |> map ListValue
--         ObjectType ->
--             let
--                 required : List String
--                 required =
--                     schema.required |> Maybe.withDefault []
--                 isSpecialType : Schema -> Bool
--                 isSpecialType =
--                     isType [ BooleanType, ArrayType, ObjectType ]
--                 schemataItem :
--                     ( String, Schema )
--                     -> Form.Field.Field
--                     -> Result (Form.Error.Error ErrorValue) ( String, Value )
--                 schemataItem ( name, schema_ ) =
--                     if List.member name required || isSpecialType schema_ then
--                         field name (validation formats schema_)
--                             |> andThen (\v -> succeed ( name, v ))
--                     else
--                         oneOf
--                             [ field name emptyString
--                                 |> andThen (\_ -> succeed ( name, EmptyValue ))
--                             , field name (validation formats schema_)
--                                 |> andThen (\v -> succeed ( name, v ))
--                             ]
--                 fields : List (Form.Field.Field -> Result (Form.Error.Error ErrorValue) ( String, Value ))
--                 fields =
--                     case schema.properties of
--                         Nothing ->
--                             required
--                                 |> List.map (\name -> ( name, blankSchema ))
--                                 |> List.map schemataItem
--                         Just (Json.Schema.Definitions.Schemata schemata) ->
--                             List.map schemataItem schemata
--             in
--             sequence fields |> map ObjectValue
--         NullType ->
--             emptyString |> andThen (\_ -> succeed NullValue)
-- constInt : Json.Encode.Value -> Int -> Validation ErrorValue Int
-- constInt constValue value =
--     if Json.Encode.int value == constValue then
--         succeed value
--     else
--         fail (Form.Error.error InvalidInt)
-- constFloat : Json.Encode.Value -> Float -> Validation ErrorValue Float
-- constFloat constValue value =
--     if Json.Encode.float value == constValue then
--         succeed value
--     else
--         fail (Form.Error.error InvalidFloat)
-- constString : Json.Encode.Value -> String -> Validation ErrorValue String
-- constString constValue value field =
--     if Json.Encode.string value == constValue then
--         succeed value field
--     else if field == Form.Field.value Form.Field.EmptyField then
--         case Json.Decode.decodeValue Json.Decode.string constValue of
--             Ok str ->
--                 succeed str field
--             Err _ ->
--                 fail (Form.Error.error InvalidString) field
--     else
--         fail (Form.Error.error InvalidString) field
-- constBool : Json.Encode.Value -> Bool -> Validation ErrorValue Bool
-- constBool constValue value =
--     if Json.Encode.bool value == constValue then
--         succeed value
--     else
--         fail (Form.Error.error InvalidBool)
-- pattern : String -> (String -> Validation e String)
-- pattern str =
--     case Regex.fromString str of
--         Just regex ->
--             format regex
--         Nothing ->
--             \_ -> fail (Form.Error.error InvalidFormat)
-- multipleOf : Int -> Int -> Validation e Int
-- multipleOf multiplier value =
--     if remainderBy multiplier value == 0 then
--         succeed value
--     else
--         fail (Form.Error.error NotIncludedIn)


minimum : SubSchema -> Maybe Float
minimum schema =
    case schema.exclusiveMinimum of
        Just (BoolBoundary True) ->
            Maybe.map (\value -> value + 1) schema.minimum

        Just (BoolBoundary False) ->
            schema.minimum

        Just (NumberBoundary value) ->
            Just (value + 1)

        Nothing ->
            schema.minimum


maximum : SubSchema -> Maybe Float
maximum schema =
    case schema.exclusiveMaximum of
        Just (BoolBoundary True) ->
            Maybe.map (\value -> value - 1) schema.maximum

        Just (BoolBoundary False) ->
            schema.maximum

        Just (NumberBoundary value) ->
            Just (value - 1)

        Nothing ->
            schema.maximum



-- enumInt : List Json.Encode.Value -> Int -> Validation ErrorValue Int
-- enumInt =
--     enum Json.Encode.int
-- enumFloat : List Json.Encode.Value -> Float -> Validation ErrorValue Float
-- enumFloat =
--     enum Json.Encode.float
-- enumString : List Json.Encode.Value -> String -> Validation ErrorValue String
-- enumString =
--     enum Json.Encode.string
-- enum :
--     (a -> Json.Encode.Value)
--     -> List Json.Encode.Value
--     -> a
--     -> Validation ErrorValue a
-- enum encode constValues value =
--     if List.member (encode value) constValues then
--         succeed value
--     else
--         fail (Form.Error.error NotIncludedIn)
-- customFormat : Formats -> String -> String -> Validation ErrorValue String
-- customFormat formats formatId value =
--     case formatId of
--         "date-time" ->
--             format Json.Schema.Form.Regex.dateTime value
--         "date" ->
--             format Json.Schema.Form.Regex.date value
--         "time" ->
--             format Json.Schema.Form.Regex.time value
--         "email" ->
--             format Json.Schema.Form.Regex.email value
--         "hostname" ->
--             format Json.Schema.Form.Regex.hostname value
--         "ipv4" ->
--             format Json.Schema.Form.Regex.ipv4 value
--         "ipv6" ->
--             format Json.Schema.Form.Regex.ipv6 value
--         format ->
--             formats
--                 |> Dict.get format
--                 |> Maybe.map
--                     (.validation
--                         >> (\v ->
--                                 v value
--                                     |> withCustomError
--                                         (InvalidCustomFormat format)
--                            )
--                     )
--                 |> Maybe.withDefault (succeed value)
-- uniqueItems : Bool -> List Value -> Validation ErrorValue (List Value)
-- uniqueItems unique value =
--     if unique then
--         let
--             items : List String
--             items =
--                 List.map Encode.encode value
--                     |> List.map (Json.Encode.encode 0)
--         in
--         if Set.size (Set.fromList items) == List.length value then
--             succeed value
--         else
--             fail (customError InvalidSet)
--     else
--         succeed value
-- minItems : Int -> List a -> Validation ErrorValue (List a)
-- minItems count list =
--     if List.length list >= count then
--         succeed list
--     else
--         fail (customError (ShorterListThan count))
-- maxItems : Int -> List a -> Validation ErrorValue (List a)
-- maxItems count list =
--     if List.length list <= count then
--         succeed list
--     else
--         fail (customError (LongerListThan count))
-- tuple : List (Validation ErrorValue a) -> Validation ErrorValue (List a)
-- tuple validations =
--     let
--         item : Int -> Validation e a -> Form.Field.Field -> Result (Form.Error.Error e) a
--         item idx =
--             field ("tuple" ++ String.fromInt idx)
--     in
--     List.indexedMap item validations
--         |> sequence
-- switch : Formats -> List Schema -> Validation CustomErrorValue Value
-- switch formats schemata =
--     let
--         validateValue : Schema -> Form.Field.Field -> Result (Form.Error.Error ErrorValue) Value
--         validateValue schema =
--             case schema of
--                 BooleanSchema _ ->
--                     field "value" (validation formats schema)
--                 ObjectSchema objectSchema ->
--                     case objectSchema.const of
--                         Just const ->
--                             succeed (constAsValue const)
--                         Nothing ->
--                             field "value" (validation formats schema)
--     in
--     field "switch" string
--         |> andThen
--             (\str ->
--                 schemata
--                     |> List.indexedMap
--                         (\idx schema ->
--                             if str == ("option" ++ String.fromInt idx) then
--                                 Just (validateValue schema)
--                             else
--                                 Nothing
--                         )
--                     |> Maybe.values
--                     |> List.head
--                     |> Maybe.withDefault (fail (customError Invalid))
--             )
-- constAsValue : Value -> Value
-- constAsValue const =
--     let
--         decoder : Decoder Value
--         decoder =
--             Json.Decode.oneOf
--                 [ Json.Decode.string |> Json.Decode.map StringValue
--                 , Json.Decode.int |> Json.Decode.map IntValue
--                 , Json.Decode.float |> Json.Decode.map FloatValue
--                 , Json.Decode.bool |> Json.Decode.map BoolValue
--                 , Json.Decode.null NullValue
--                 ]
--     in
--     const
--         |> Json.Decode.decodeValue decoder
--         |> Result.withDefault (JsonValue const)
-- andMaybe :
--     (a -> b -> Validation ErrorValue b)
--     -> Maybe a
--     -> (Validation ErrorValue b -> Validation ErrorValue b)
-- andMaybe func constraint =
--     case constraint of
--         Just constraintValue ->
--             andThen (\value -> func constraintValue value)
--         Nothing ->
--             andThen (\value -> succeed value)


isType : List SingleType -> Schema -> Bool
isType types schema_ =
    List.any
        (\t ->
            case schema_ of
                ObjectSchema s ->
                    case s.type_ of
                        AnyType ->
                            BooleanType == t

                        NullableType type_ ->
                            type_ == t

                        UnionType _ ->
                            StringType == t

                        SingleType type_ ->
                            type_ == t

                _ ->
                    False
        )
        types



-- lazy : (() -> Validation e o) -> Validation e o
-- lazy thunk =
--     andThen thunk (succeed ())
