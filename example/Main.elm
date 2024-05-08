module Main exposing (main)

import Browser
import Dict
import Form exposing (InputType(..), Msg(..))
import Form.Error exposing (ErrorValue(..))
import Form.Field exposing (FieldValue(..))
import Form.Input exposing (Input)
import Form.Validate
import Html exposing (..)
import Html.Attributes as Attrs exposing (class, style)
import Html.Events exposing (onClick, onSubmit)
import Json.Encode exposing (bool, float, int, list, string)
import Json.Schema.Builder exposing (..)
import Json.Schema.Definitions
import Json.Schema.Form exposing (Msg, State)
import Json.Schema.Form.Encode
import Json.Schema.Form.Error exposing (ErrorValue(..), Errors)
import Json.Schema.Form.Format exposing (Format)
import Json.Schema.Form.Theme as Theme exposing (Theme)
import Regex


main : Program () State Msg
main =
    Browser.sandbox { init = init, update = update, view = view }


tailwind : Theme
tailwind =
    let
        theme =
            Theme.default

        isInvalid =
            "border-2 border-red-500"
    in
    { theme
        | -- inputs
          txt =
            \{ withError, format } ->
                Attrs.classList
                    [ ( "block w-full rounded-md py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6", True )
                    , ( "border-0", not withError )
                    , ( isInvalid, withError )
                    , case format of
                        Just str ->
                            ( "format-" ++ str, True )

                        Nothing ->
                            ( "", False )
                    ]

        -- checkbox
        , checkboxWrapper = Attrs.class "flex h-6 items-center"
        , checkboxInput =
            \{ withError } ->
                Attrs.classList
                    [ ( "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600", True )
                    , ( isInvalid, withError )
                    ]
        , checkboxTitle = Attrs.class "ml-3 text-sm leading-6"

        -- select
        , select =
            \{ withError } ->
                Attrs.classList
                    [ ( "block w-full mt-2 rounded-md py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:max-w-xs sm:text-sm sm:leading-6", True )
                    , ( "border-0", not withError )
                    , ( isInvalid, withError )
                    ]

        -- list group
        , listGroup = Attrs.class "mb-2"
        , listGroupItem = Attrs.class "border border-gray-300 rounded-md px-4 py-2 mb-2 shadow-sm"
        , listGroupAddItemButton = Attrs.class "rounded-md bg-gray-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-gray-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-600"
        , listGroupRemoveItemButton = Attrs.class "rounded-md bg-white px-2.5 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"

        -- tuple
        , formRow = Attrs.class "flex space-x-4"
        , formRowItem = Attrs.class "max-w-full flex-grow"

        -- radio
        , radioWrapper = Attrs.class "flex items-center gap-x-3"
        , radioInput = Attrs.class "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-600"
        , radioInputLabel = Attrs.class "block text-sm font-medium leading-6 text-gray-900"
        , field =
            \{ withError, withValue } ->
                Attrs.classList
                    [ ( "mb-6", True )
                    , ( "text-red-500", withError )
                    , ( "has-value", withValue )
                    ]
        , fieldLabel = Attrs.class "block"
        , fieldInput = Attrs.class "field-input"
        , fieldInputMeta = Attrs.class "field-meta"
        , fieldTitle = Attrs.class "block text-sm font-medium leading-6 text-gray-900"
        , fieldDescription = Attrs.class "mt-2 text-sm leading-6 text-gray-600"
        , group =
            \{ withError, withValue } ->
                Attrs.classList
                    [ ( "mb-4", True )
                    , ( "text-red-500", withError )
                    , ( "has-value", withValue )
                    ]
        , liveError = Attrs.class "text-red-500 text-xs my-2"
        , inputGroupPrepend = Attrs.class "inline-flex items-center rounded-l-md border border-r-0 border-gray-300 px-3 text-gray-500 sm:text-sm"
        , inputGroupPrependContent = Attrs.class "text-gray-500 sm:text-sm"
        , inputGroupAppend = Attrs.class "inline-flex items-center rounded-r-md border border-l-0 border-gray-300 px-3 text-gray-500 sm:text-sm"
        , inputGroupAppendContent = Attrs.class "text-gray-500 sm:text-sm"
        , inputGroup = Attrs.class "mt-2 flex shadow-sm"
    }


init : State
init =
    case schema of
        Ok schema_ ->
            Json.Schema.Form.init
                { errors = errorString
                , formats = Dict.fromList formats
                , theme = tailwind
                }
                schema_

        Err error ->
            Debug.todo error


update : Msg -> State -> State
update msg state =
    Json.Schema.Form.update msg state


view : State -> Html Msg
view state =
    form [ onSubmit Json.Schema.Form.submit ]
        [ Json.Schema.Form.view state
        , button [ class "btn btn-primary rounded-md bg-blue-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600" ] [ text "Submit" ]
        , case Form.getOutput state.form of
            Just output ->
                let
                    json =
                        Json.Encode.encode 4 (Json.Schema.Form.Encode.encode output)
                in
                pre [] [ text json ]

            Nothing ->
                text ""
        ]


errorString : Errors
errorString path error =
    case error of
        Empty ->
            "The field can not be empty."

        InvalidString ->
            "This field is required."

        InvalidEmail ->
            "That is not a valid email address."

        InvalidFormat ->
            "That is not the correct format."

        InvalidInt ->
            "That is not a valid number."

        InvalidFloat ->
            "That is not a valid decimal number."

        InvalidBool ->
            "That is not a valid option."

        SmallerIntThan n ->
            "Can not be smaller than " ++ String.fromInt n ++ "."

        GreaterIntThan n ->
            "Can not be greater than " ++ String.fromInt n ++ "."

        SmallerFloatThan n ->
            "Can not be smaller than " ++ String.fromFloat n ++ "."

        GreaterFloatThan n ->
            "Can not be greater than " ++ String.fromFloat n ++ "."

        ShorterStringThan n ->
            "Must be at least " ++ String.fromInt n ++ " characters long."

        LongerStringThan n ->
            "Can not be more than " ++ String.fromInt n ++ " characters long."

        NotIncludedIn ->
            "Is not a valid selection from the list."

        CustomError Invalid ->
            "Is not valid."

        CustomError InvalidSet ->
            "All items added need to be unique."

        CustomError (ShorterListThan n) ->
            if path == "airports" then
                "You need to add at least " ++ String.fromInt n ++ " airports."

            else
                "You need to add at least " ++ String.fromInt n ++ " items."

        CustomError (LongerListThan n) ->
            "You can not add more than " ++ String.fromInt n ++ " items."

        CustomError (InvalidCustomFormat format) ->
            case format of
                "personal-number" ->
                    "That is not a valid personal number."

                _ ->
                    "That is not the correct format."


personalNumber : Regex.Regex
personalNumber =
    Maybe.withDefault Regex.never <|
        Regex.fromString "^(19|20)[0-9]{6}-?[0-9]{4}$"


customInput : Input ErrorValue String
customInput f attrs =
    button
        ([ onClick
            (Form.Input f.path
                Form.Text
                (String "Hello world")
            )
         , class "btn btn-lg btn-light"
         , style "height" "auto"
         ]
            ++ attrs
        )
        [ case f.value of
            Just str ->
                text str

            Nothing ->
                text "Click me!"
        ]


formats : List ( String, Format )
formats =
    [ ( "personal-number"
      , Json.Schema.Form.Format.init
            |> Json.Schema.Form.Format.withPlaceholder "ÅÅÅÅMMDD-NNNN"
            |> Json.Schema.Form.Format.withValidation
                (Form.Validate.format personalNumber)
      )
    , ( "currency-sek"
      , Json.Schema.Form.Format.init
            |> Json.Schema.Form.Format.withPrefix "SEK"
            |> Json.Schema.Form.Format.withSuffix ".00"
            |> Json.Schema.Form.Format.withInputType "number"
      )
    , ( "phone"
      , Json.Schema.Form.Format.init
            |> Json.Schema.Form.Format.withInputType "tel"
            |> Json.Schema.Form.Format.withPrefix "+46"
            |> Json.Schema.Form.Format.withAutocomplete "tel-national"
      )
    , ( "description"
      , Json.Schema.Form.Format.init
            |> Json.Schema.Form.Format.withLines 5
      )
    , ( "custom"
      , Json.Schema.Form.Format.init
            |> Json.Schema.Form.Format.withInput customInput
      )
    ]


schema : Result String Json.Schema.Definitions.Schema
schema =
    buildSchema
        |> withId "http://example.com/schema#"
        |> withTitle "My object"
        |> withDescription "This is an example form."
        |> withType "object"
        |> withRequired
            [ "name"
            , "numbers"
            , "color"
            , "address"
            , "airports"
            , "social"
            , "contact"
            , "terms"
            ]
        |> withProperties
            [ ( "name"
              , buildSchema
                    |> withType "string"
                    |> withTitle "Name"
                    |> withDescription "Please enter your name."
                    |> withMaxLength 10
                    |> withMinLength 2
              )
            , ( "numbers"
              , buildSchema
                    |> withType "array"
                    |> withDefault (list float [ 6, 7 ])
                    |> withItems
                        [ buildSchema
                            |> withType "integer"
                            |> withTitle "Integer"
                            |> withDescription "Enter an integer between 5-10."
                            |> withExclusiveMinimum 5
                            |> withExclusiveMaximum 10
                            |> withMultipleOf 2
                        , buildSchema
                            |> withType "number"
                            |> withTitle "Number"
                            |> withDescription "Enter a natural number between 5.5-10.1 (inclusive)."
                            |> withMinimum 5.5
                            |> withMaximum 10.1
                        , buildSchema
                            |> withType "integer"
                            |> withTitle "Month"
                            |> withOneOf
                                [ boolSchema False
                                , buildSchema
                                    |> withConst (int 1)
                                    |> withTitle "Jan"
                                , buildSchema
                                    |> withConst (int 2)
                                    |> withTitle "Feb"
                                , buildSchema
                                    |> withConst (int 3)
                                    |> withTitle "Mar"
                                , buildSchema
                                    |> withConst (int 4)
                                    |> withTitle "Apr"
                                , buildSchema
                                    |> withConst (int 5)
                                    |> withTitle "May"
                                , buildSchema
                                    |> withConst (int 6)
                                    |> withTitle "Jun"
                                , buildSchema
                                    |> withConst (int 7)
                                    |> withTitle "Jul"
                                , buildSchema
                                    |> withConst (int 8)
                                    |> withTitle "Aug"
                                , buildSchema
                                    |> withConst (int 9)
                                    |> withTitle "Sep"
                                , buildSchema
                                    |> withConst (int 10)
                                    |> withTitle "Oct"
                                , buildSchema
                                    |> withConst (int 11)
                                    |> withTitle "Nov"
                                , buildSchema
                                    |> withConst (int 12)
                                    |> withTitle "Dec"
                                ]
                        ]
              )
            , ( "amount"
              , buildSchema
                    |> withTitle "Amount (SEK)"
                    |> withType "integer"
                    |> withFormat "currency-sek"
              )
            , ( "calendar"
              , buildSchema
                    |> withType "array"
                    |> withDefault
                        (Json.Encode.list Json.Encode.string
                            [ "2019-02-27", "18:00:00" ]
                        )
                    |> withItems
                        [ buildSchema
                            |> withTitle "Date"
                            |> withType "string"
                            |> withFormat "date"
                        , buildSchema
                            |> withTitle "Time"
                            |> withType "string"
                            |> withFormat "time"
                        ]
              )
            , ( "color"
              , buildSchema
                    |> withTitle "Color"
                    |> withDescription
                        "Please enter either red, gren or blue."
                    |> withNullableType "string"
                    |> withEnum
                        [ string "red"
                        , string "green"
                        , string "blue"
                        ]
              )
            , ( "address"
              , buildSchema
                    |> withType "array"
                    |> withDefault
                        (list string
                            [ "1600"
                            , "Pennsylvania"
                            , "Avenue"
                            , "NW"
                            ]
                        )
                    |> withItems
                        [ buildSchema
                            |> withType "integer"
                            |> withTitle "Street number"
                        , buildSchema
                            |> withType "string"
                            |> withTitle "Street name"
                        , buildSchema
                            |> withType "string"
                            |> withTitle "Street type"
                            |> withOneOf
                                [ boolSchema False
                                , buildSchema |> withConst (string "Street")
                                , buildSchema |> withConst (string "Avenue")
                                , buildSchema |> withConst (string "Boulevard")
                                ]
                        , buildSchema
                            |> withType "string"
                            |> withTitle "Direction"
                            |> withEnum
                                [ string "NW"
                                , string "NE"
                                , string "SW"
                                , string "SE"
                                ]
                        ]
              )
            , ( "travel"
              , buildSchema
                    |> withTitle "What modes of transportation do you use when you travel?"
                    |> withOneOf
                        [ buildSchema
                            |> withTitle "Walking"
                            |> withType "string"
                            |> withConst (Json.Encode.string "walking")
                        , buildSchema
                            |> withTitle "Driving car"
                            |> withType "string"
                            |> withConst (Json.Encode.string "driving")
                        , buildSchema
                            |> withTitle "Boat"
                            |> withType "string"
                            |> withConst (Json.Encode.string "boat")
                        , buildSchema
                            |> withTitle "Bus"
                            |> withType "string"
                            |> withConst (Json.Encode.string "bus")
                        , buildSchema
                            |> withTitle "Other"
                            |> withType "object"
                            |> withRequired [ "details" ]
                            |> withProperties
                                [ ( "details"
                                  , buildSchema
                                        |> withType "string"
                                        |> withTitle "Please specify"
                                  )
                                ]
                        ]
              )
            , ( "airports"
              , buildSchema
                    |> withTitle "Add airport"
                    |> withType "array"
                    |> withDefault (list string [ "LHR", "CDG" ])
                    |> withUniqueItems True
                    |> withMinItems 2
                    |> withItem
                        (buildSchema
                            |> withType "string"
                            |> withAnyOf
                                [ boolSchema False
                                , buildSchema
                                    |> withTitle "Stockholm Arlanda"
                                    |> withConst (string "ARN")
                                , buildSchema
                                    |> withTitle "London Heathrow"
                                    |> withConst (string "LHR")
                                    |> withDescription "Heathrow Airport is a major international airport in London, United Kingdom."
                                , buildSchema
                                    |> withTitle "Dubai International Airport"
                                    |> withConst (string "DXB")
                                , buildSchema
                                    |> withTitle "Paris Charles de Gaulle"
                                    |> withDescription "Paris Charles de Gaulle Airport is the largest international airport in France and the second largest in Europe."
                                    |> withConst (string "CDG")
                                ]
                        )
              )
            , ( "social"
              , buildSchema
                    |> withType "object"
                    |> withTitle "Social network"
                    |> withProperties
                        [ ( "friends"
                          , buildSchema
                                |> withTitle "Add a friend"
                                |> withDescription "You can add at most five friends."
                                |> withType "array"
                                |> withUniqueItems True
                                |> withMaxItems 5
                                |> withItem
                                    (buildSchema
                                        |> withType "object"
                                        |> withRequired [ "name", "email" ]
                                        |> withProperties
                                            [ ( "name"
                                              , buildSchema
                                                    |> withType "string"
                                                    |> withTitle "Name"
                                              )
                                            , ( "email"
                                              , buildSchema
                                                    |> withType "string"
                                                    |> withTitle "Email"
                                                    |> withFormat "email"
                                              )
                                            ]
                                    )
                          )
                        ]
              )
            , ( "contact"
              , buildSchema
                    |> withType "object"
                    |> withTitle "Contact details"
                    |> withDescription "Please enter your contact details."
                    |> withRequired [ "email" ]
                    |> withProperties
                        [ ( "email"
                          , buildSchema
                                |> withType "string"
                                |> withTitle "Email"
                                |> withDescription "Your email address."
                                |> withFormat "email"
                                |> withDefault (string "a@example.com")
                          )
                        , ( "phone"
                          , buildSchema
                                |> withType "string"
                                |> withTitle "Phone"
                                |> withDescription "Your phone number."
                                |> withFormat "phone"
                          )
                        , ( "personal_number"
                          , buildSchema
                                |> withType "string"
                                |> withTitle "Personal number"
                                |> withDescription "Your personal number."
                                |> withFormat "personal-number"
                          )
                        ]
              )
            , ( "description"
              , buildSchema
                    |> withType "string"
                    |> withTitle "Description"
                    |> withFormat "description"
              )
            , ( "custom"
              , buildSchema
                    |> withType "string"
                    |> withTitle "Custom input"
                    |> withFormat "custom"
              )
            , ( "terms"
              , buildSchema
                    |> withType "boolean"
                    |> withTitle "I accept the terms"
                    |> withDescription "Testing field meta."
                    |> withConst (bool True)
              )
            ]
        |> toSchema
