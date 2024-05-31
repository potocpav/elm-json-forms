module Form exposing
    ( Msg(..), InputType(..), Form, FieldState
    , initial, update
    , getField
    -- , getFieldAsString, getFieldAsBool, getListIndexes
    , getFocus, isSubmitted, getErrors, getOutput, getChangedFields
    )

{-| Simple forms made easy: A Dict implementation of the core `Json.Decode` API,
with state lifecycle and input helpers for the views.


# Types

@docs Msg, InputType, Form, FieldState


# Init/update lifecyle

@docs initial, update


# Field state accessors

@docs getFieldAsString, getFieldAsBool, getListIndexes


# Global state accessors

@docs getFocus, isSubmitted, getErrors, getOutput, getChangedFields

-}

import Dict exposing (Dict)
import Form.Error as Error exposing (Error, ErrorValue)
import Form.Field as Field exposing (Field, FieldValue(..))
import Form.Tree as Tree exposing (Tree)
import Form.Validate exposing (Validation)
import Set exposing (Set)


{-| Form to embed in your model. Type parameters are:

  - `customError` - a custom error type to extend built-in errors (set to `()` if you don't need it)
  - `output` - the type of the validation output.

-}
type Form customError output
    = Form (Model customError output)


{-| Private
-}
type alias Model customError output =
    { values : Dict String FieldValue
    , focus : Maybe String
    , dirtyFields : Set String
    , changedFields : Set String
    , originalValues : Dict String (Maybe FieldValue)
    , isSubmitted : Bool
    , output : Maybe output
    , errors : Error customError
    }


{-| Initial form state. See `Form.Field` for initial fields, and `Form.Validate` for validation.
-}
initial : Dict String FieldValue -> Validation e output -> Form e output
initial initialValues validation =
    let
        model =
            { values = initialValues
            , focus = Nothing
            , dirtyFields = Set.empty
            , changedFields = Set.empty
            , originalValues = Dict.empty
            , isSubmitted = False
            , output = Nothing
            , errors = Tree.group []
            }
    in
    Form (updateValidate validation model)


{-| Field state containing all necessary data for view and update,
can be retrived with `Form.getFieldAsString` or `Form.getFieldAsBool`.

  - `path` - qualified path of the field in the form, with dots for nested fields (`field.subfield`)
  - `value` - a `Maybe` of the requested type
  - `error` - a `Maybe` of the field error
  - `liveError` - same but with added logic for live validation
    (see [`getLiveErrorAt`](https://github.com/etaque/elm-form/blob/master/src/Form.elm) impl)
  - `isDirty` - if the field content has been changed since last validation
  - `isChanged` - if the field value has changed since last init/reset
  - `hasFocus` - if the field is currently focused

-}
type alias FieldState e =
    { path : String
    , value : Maybe FieldValue
    , error : Maybe (ErrorValue e)
    , liveError : Maybe (ErrorValue e)
    , isDirty : Bool
    , isChanged : Bool
    , hasFocus : Bool
    }

-- filterMapFieldState : (a -> Maybe b) -> FieldState e a -> Maybe (FieldState e b)
-- filterMapFieldState f fs =
--     case f fs.value of
--         Nothing -> Nothing
--         Just value ->
--             { path = fs.path
--             , value = value
--             , error = fs.error
--             , liveError = fs.liveError
--             , isDirty = fs.isDirty
--             , isChanged = fs.isChanged
--             , hasFocus = fs.hasFocus
--             }


-- {-| Get field state at path, with value as a `String`.
-- -}
-- getFieldAsString : String -> Form e o -> Maybe (FieldState e String)
-- getFieldAsString path form =
--     getField path form |> filterMapFieldState (\v -> case v of
--         Bool _ -> Nothing
--         String s -> Just s)


-- {-| Get field state at path, with value as a `Bool`.
-- -}
-- getFieldAsBool : String -> Form e o -> FieldState e Bool
-- getFieldAsBool =
--     getField getBoolAt


getValue : String -> Form e o -> Maybe FieldValue
getValue path (Form form) = Dict.get path form.values


getField : String -> Form e o -> FieldState e
getField path form =
    { path = path
    , value = getValue path form
    , error = getErrorAt path form
    , liveError = getLiveErrorAt path form
    , isDirty = isDirtyAt path form
    , isChanged = isChangedAt path form
    , hasFocus = getFocus form == Just path
    }


-- {-| return a list of indexes so one can build qualified names of fields in list.
-- -}
-- getListIndexes : String -> Form e o -> List Int
-- getListIndexes path (F model) =
--     let
--         length =
--             getFieldAt path model
--                 |> Maybe.map (Tree.asList >> List.length)
--                 |> Maybe.withDefault 0
--     in
--     List.range 0 (length - 1)


{-| Form messages for `update`.
-}
type Msg
    = NoOp
    | Focus String
    | Blur String
    | Input String InputType FieldValue
    -- | Append String
    -- | RemoveItem String Int
    | Submit
    | Validate
    | Reset (Dict String FieldValue)


{-| Input types to determine live validation behaviour.
-}
type InputType
    = Text
    | Textarea
    | Select
    | Radio
    | Checkbox


{-| Update form state with the given message
-}
update : Validation e output -> Msg -> Form e output -> Form e output
update validation msg (Form model) =
    case msg of
        NoOp ->
            Form model

        Focus name ->
            let
                newModel =
                    { model | focus = Just name }
            in
            Form newModel

        Blur name ->
            let
                newDirtyFields =
                    Set.remove name model.dirtyFields

                newModel =
                    { model | focus = Nothing, dirtyFields = newDirtyFields }
            in
            Form (updateValidate validation newModel)

        Input name inputType fieldValue ->
            let
                newValues =
                    Dict.insert name fieldValue model.values

                isDirty =
                    case inputType of
                        Text ->
                            True

                        Textarea ->
                            True

                        _ ->
                            False

                newDirtyFields =
                    if isDirty then
                        Set.insert name model.dirtyFields

                    else
                        model.dirtyFields

                ( newChangedFields, newOriginalValues ) =
                    if Set.member name model.changedFields then
                        let
                            storedValue =
                                Dict.get name model.originalValues
                                    |> Maybe.withDefault Nothing

                            shouldBeNothing v =
                                case v of
                                    Field.String "" ->
                                        True

                                    Field.Bool False ->
                                        True

                                    _ ->
                                        False

                            sameAsOriginal =
                                case storedValue of
                                    Just v ->
                                        v == fieldValue

                                    Nothing ->
                                        shouldBeNothing fieldValue

                            changedFields =
                                if sameAsOriginal then
                                    Set.remove name model.changedFields

                                else
                                    model.changedFields
                        in
                        ( changedFields, model.originalValues )

                    else
                        let
                            originalValue =
                                Dict.get name model.values
                        in
                        ( Set.insert name model.changedFields, Dict.insert name originalValue model.originalValues )

                newModel =
                    { model
                        | values = newValues
                        , dirtyFields = newDirtyFields
                        , changedFields = newChangedFields
                        , originalValues = newOriginalValues
                    }
            in
            Form (updateValidate validation newModel)

        -- Append listName ->
        --     let
        --         listFields =
        --             getFieldAt listName model
        --                 |> Maybe.map Tree.asList
        --                 |> Maybe.withDefault []

        --         newListFields =
        --             listFields ++ [ Tree.Value Field.EmptyField ]

        --         newModel =
        --             { model
        --                 | fields = setFieldAt listName (Tree.List newListFields) model
        --             }
        --     in
        --     F newModel

        -- RemoveItem listName index ->
        --     let
        --         listFields =
        --             getFieldAt listName model
        --                 |> Maybe.map Tree.asList
        --                 |> Maybe.withDefault []

        --         fieldNamePattern =
        --             listName ++ String.fromInt index

        --         filterChangedFields =
        --             Set.filter (not << String.startsWith fieldNamePattern)

        --         filterOriginalValue =
        --             Dict.filter (\c _ -> not <| String.startsWith fieldNamePattern c)

        --         newListFields =
        --             List.take index listFields ++ List.drop (index + 1) listFields

        --         newModel =
        --             { model
        --                 | fields = setFieldAt listName (Tree.List newListFields) model
        --                 , changedFields = filterChangedFields model.changedFields
        --                 , originalValues = filterOriginalValue model.originalValues
        --             }
        --     in
        --     F (updateValidate validation newModel)

        Submit ->
            let
                validatedModel =
                    updateValidate validation model
            in
            Form { validatedModel | isSubmitted = True }

        Validate ->
            Form (updateValidate validation model)

        Reset values ->
            let
                newModel =
                    { model
                        | values = values
                        , dirtyFields = Set.empty
                        , changedFields = Set.empty
                        , originalValues = Dict.empty
                        , isSubmitted = False
                    }
            in
            Form (updateValidate validation newModel)


updateValidate : Validation e o -> Model e o -> Model e o
updateValidate validation model =
    case validation model.values of
        Ok output ->
            { model
                | errors =
                    Tree.group []
                , output = Just output
            }

        Err error ->
            { model
                | errors =
                    error
                , output = Nothing
            }


-- getFieldAt : String -> Model e o -> Maybe Field
-- getFieldAt qualifiedName model =
--     Tree.getAtPath qualifiedName model.values


-- getStringAt : String -> Form e o -> Maybe String
-- getStringAt name (F model) =
--     getFieldAt name model |> Maybe.andThen Field.asString


-- getBoolAt : String -> Form e o -> Maybe Bool
-- getBoolAt name (F model) =
--     getFieldAt name model |> Maybe.andThen Field.asBool


-- setFieldAt : String -> Field -> Model e o -> Field
-- setFieldAt path field model =
--     Tree.setAtPath path field model.fields


{-| Get form output, in case of validation success.
-}
getOutput : Form e o -> Maybe o
getOutput (Form model) =
    model.output


{-| Get form submission state. Useful to show errors on unchanged fields.
-}
isSubmitted : Form e o -> Bool
isSubmitted (Form model) =
    model.isSubmitted


{-| Get list of errors on qualified paths.
-}
getErrors : Form e o -> List ( String, Error.ErrorValue e )
getErrors (Form model) =
    Tree.valuesWithPath model.errors


getErrorAt : String -> Form e o -> Maybe (ErrorValue e)
getErrorAt path (Form model) =
    Tree.getAtPath path model.errors |> Maybe.andThen Tree.asValue


getLiveErrorAt : String -> Form e o -> Maybe (ErrorValue e)
getLiveErrorAt name form =
    if isSubmitted form || (isChangedAt name form && not (isDirtyAt name form)) then
        getErrorAt name form

    else
        Nothing


isChangedAt : String -> Form e o -> Bool
isChangedAt qualifiedName (Form model) =
    Set.member qualifiedName model.changedFields


isDirtyAt : String -> Form e o -> Bool
isDirtyAt qualifiedName (Form model) =
    Set.member qualifiedName model.dirtyFields


{-| Return currently focused field, if any.
-}
getFocus : Form e o -> Maybe String
getFocus (Form model) =
    model.focus


{-| Get set of changed fields.
-}
getChangedFields : Form e o -> Set String
getChangedFields (Form model) =
    model.changedFields
