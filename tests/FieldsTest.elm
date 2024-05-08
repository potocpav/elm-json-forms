module FieldsTest exposing (suite)

import Dict
import Expect exposing (Expectation)
import Form as F
import Form.Validate
import Html.Attributes
import Json.Encode
import Json.Schema.Builder
    exposing
        ( SchemaBuilder
        , boolSchema
        , buildSchema
        , toSchema
        , withAnyOf
        , withConst
        , withDescription
        , withItem
        , withItems
        , withOneOf
        , withProperties
        , withTitle
        , withType
        , withUnionType
        )
import Json.Schema.Form.Fields exposing (schemaView)
import Json.Schema.Form.Options exposing (Options)
import Json.Schema.Form.Theme as Theme
import Json.Schema.Form.Value exposing (Value(..))
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector exposing (attribute, checked, class, classes, selected, tag, text)


options : Options
options =
    { errors = \_ _ -> ""
    , formats = Dict.empty
    , theme = Theme.default
    }


form : F.Form e Value
form =
    F.initial [] (Form.Validate.succeed EmptyValue)


view : (Query.Single F.Msg -> Expectation) -> SchemaBuilder -> Expectation
view func schema =
    case toSchema schema of
        Ok schema_ ->
            schemaView options [] schema_ form
                |> Query.fromHtml
                |> func

        Err error ->
            Expect.fail error


suite : Test
suite =
    describe "Json.Schema.Form.Fields"
        [ describe "schemaView"
            [ describe "with a blank schema"
                [ test "should be a checkbox" <|
                    \_ -> buildSchema |> isCheckbox
                ]
            , describe "with a boolean schema"
                [ describe "true"
                    [ test "should be div with text 'True'" <|
                        \_ ->
                            boolSchema True
                                |> view
                                    (Query.has
                                        [ tag "div"
                                        , text "True"
                                        ]
                                    )
                    ]
                , describe "false"
                    [ test "should be div with text 'False'" <|
                        \_ ->
                            boolSchema False
                                |> view
                                    (Query.has
                                        [ tag "div"
                                        , text "False"
                                        ]
                                    )
                    ]
                ]
            , describe "with an object schema"
                [ describe "any type"
                    [ test "should be a checkbox" <|
                        \_ -> buildSchema |> isCheckbox
                    , describe "oneOf"
                        [ test "should be a switch" <|
                            \_ ->
                                buildSchema
                                    |> withOneOf
                                        [ buildSchema
                                            |> withTitle "One"
                                            |> withConst (Json.Encode.string "one")
                                        , buildSchema
                                            |> withTitle "Two"
                                            |> withConst (Json.Encode.string "two")
                                        ]
                                    |> isSwitch
                        ]
                    , describe "anyOf"
                        [ test "should be a switch" <|
                            \_ ->
                                buildSchema
                                    |> withAnyOf
                                        [ buildSchema
                                            |> withTitle "One"
                                            |> withConst (Json.Encode.string "one")
                                        , buildSchema
                                            |> withTitle "Two"
                                            |> withConst (Json.Encode.string "two")
                                        ]
                                    |> isSwitch
                        ]
                    ]
                , describe "nullable type" singleTypes
                , describe "union type"
                    [ describe "with all types"
                        [ test "should be a text field" <|
                            \_ ->
                                (buildSchema
                                    |> withUnionType
                                        [ "integer"
                                        , "number"
                                        , "string"
                                        , "boolean"
                                        , "array"
                                        , "object"
                                        ]
                                )
                                    |> isTextField
                        ]
                    ]
                , describe "single type" singleTypes
                ]
            ]
        ]


singleTypes : List Test
singleTypes =
    [ describe "integer"
        [ test "should be a text field" <|
            \_ ->
                buildSchema
                    |> withType "integer"
                    |> isInputTypeNumber
        , describe "oneOf"
            [ test "should be a select" <|
                \_ ->
                    buildSchema
                        |> withType "integer"
                        |> isNumberSelect
            ]
        , describe "anyOf"
            [ test "should be a select" <|
                \_ ->
                    buildSchema
                        |> withType "integer"
                        |> isNumberSelect
            ]
        ]
    , describe "number"
        [ test "should be a text field" <|
            \_ ->
                buildSchema
                    |> withType "number"
                    |> isInputTypeNumber
        , describe "oneOf"
            [ test "should be a select" <|
                \_ ->
                    buildSchema
                        |> withType "number"
                        |> isNumberSelect
            ]
        , describe "anyOf"
            [ test "should be a select" <|
                \_ ->
                    buildSchema
                        |> withType "number"
                        |> isNumberSelect
            ]
        ]
    , describe "string"
        [ test "should be a text field" <|
            \_ ->
                buildSchema
                    |> withType "string"
                    |> isTextField
        , describe "oneOf"
            [ test "should be a select" <|
                \_ ->
                    buildSchema
                        |> withType "string"
                        |> isSelect
            ]
        , describe "anyOf"
            [ test "should be a select" <|
                \_ ->
                    buildSchema
                        |> withType "string"
                        |> isSelect
            ]
        ]
    , describe "boolean"
        [ test "should be a checkbox" <|
            \_ ->
                buildSchema
                    |> withType "boolean"
                    |> isCheckbox
        ]
    , describe "array"
        [ describe "without item schema"
            [ test "should be a list" <|
                \_ ->
                    buildSchema
                        |> withType "array"
                        |> isList
            ]
        , describe "with item schema"
            [ test "should be a list" <|
                \_ ->
                    buildSchema
                        |> withType "array"
                        |> withItem buildSchema
                        |> isList
            ]
        , describe "with multiple item schemas"
            [ test "should be a tuple" <|
                \_ ->
                    buildSchema
                        |> withType "array"
                        |> withItems [ buildSchema, buildSchema ]
                        |> isTuple
            ]
        ]
    , describe "object"
        [ test "should be a fieldset" <|
            \_ ->
                buildSchema
                    |> withType "object"
                    |> withProperties [ ( "test", buildSchema ) ]
                    |> isFieldset
        , describe "oneOf"
            [ test "should be a switch" <|
                \_ ->
                    buildSchema
                        |> withType "object"
                        |> withOneOf
                            [ buildSchema
                                |> withTitle "One"
                                |> withConst (Json.Encode.string "one")
                            , buildSchema
                                |> withTitle "Two"
                                |> withConst (Json.Encode.string "two")
                            ]
                        |> isSwitch
            ]
        , describe "anyOf"
            [ test "should be a switch" <|
                \_ ->
                    buildSchema
                        |> withType "object"
                        |> withAnyOf
                            [ buildSchema
                                |> withTitle "One"
                                |> withConst (Json.Encode.string "one")
                            , buildSchema
                                |> withTitle "Two"
                                |> withConst (Json.Encode.string "two")
                            ]
                        |> isSwitch
            ]
        ]
    , describe "null"
        [ test "should be an empty div" <|
            \_ ->
                buildSchema
                    |> withType "null"
                    |> Expect.all
                        [ view (Query.has [ tag "div" ])
                        , view
                            (Query.children []
                                >> Query.count (Expect.equal 0)
                            )
                        ]
        ]
    ]


isField : SchemaBuilder -> Expectation
isField schema =
    schema
        |> view
            (Query.has
                [ tag "div"
                , classes [ "form-group" ]
                ]
            )


hasFieldTitle : SchemaBuilder -> Expectation
hasFieldTitle schema =
    schema
        |> withTitle "Test"
        |> view
            (Query.find [ tag "label" ]
                >> Query.find [ tag "span", class "label-text" ]
                >> Query.has [ text "Test" ]
            )


hasFieldDescription : SchemaBuilder -> Expectation
hasFieldDescription schema =
    schema
        |> withDescription "Lorem ipsum."
        |> view
            (Query.find [ class "field-meta" ]
                >> (Query.find [ class "form-text" ]
                        >> Query.has [ text "Lorem ipsum." ]
                   )
            )


isCheckbox : SchemaBuilder -> Expectation
isCheckbox schema =
    schema
        |> withTitle "Test"
        |> Expect.all
            [ isField
            , hasFieldTitle
            , hasFieldDescription
            , view
                (Expect.all
                    [ Query.has [ tag "div", class "form-check" ]
                    , Query.find [ tag "label" ]
                        >> Query.has [ class "label-text", text "Test" ]
                    , Query.find [ tag "input" ]
                        >> Query.has
                            [ class "form-check-input"
                            , attribute
                                (Html.Attributes.attribute
                                    "type"
                                    "checkbox"
                                )
                            , checked False
                            ]
                    ]
                )
            ]


isTextField : SchemaBuilder -> Expectation
isTextField =
    Expect.all
        [ isField
        , hasFieldTitle
        , hasFieldDescription
        , view
            (Expect.all
                [ Query.find [ tag "input" ]
                    >> Query.has
                        [ attribute
                            (Html.Attributes.attribute
                                "type"
                                "text"
                            )
                        ]
                ]
            )
        ]


isInputTypeNumber : SchemaBuilder -> Expectation
isInputTypeNumber =
    Expect.all
        [ isField
        , hasFieldTitle
        , hasFieldDescription
        , view
            (Expect.all
                [ Query.find [ tag "input" ]
                    >> Query.has
                        [ attribute
                            (Html.Attributes.attribute
                                "type"
                                "number"
                            )
                        ]
                ]
            )
        ]


isFieldset : SchemaBuilder -> Expectation
isFieldset schema =
    schema
        |> withTitle "Test"
        |> withDescription "Lorem ipsum."
        |> view
            (Expect.all
                [ Query.has [ tag "fieldset" ]
                , Query.find [ tag "legend" ]
                    >> Query.has [ text "Test" ]
                , Query.children [ tag "div", class "form-group" ]
                    >> Query.first
                    >> Query.find [ tag "p" ]
                    >> Query.has [ text "Lorem ipsum." ]
                ]
            )


isList : SchemaBuilder -> Expectation
isList schema =
    schema
        |> withTitle "Test"
        |> withDescription "Lorem ipsum."
        |> view
            (Expect.all
                [ Query.has [ tag "div", class "form-group" ]
                , Query.find
                    [ tag "button"
                    , classes [ "btn", "btn-secondary", "btn-add" ]
                    ]
                    >> Query.has [ text "Test" ]
                , Query.find [ tag "button", class "btn-add" ]
                    >> Event.simulate Event.click
                    >> Event.expect (F.Append "")
                , Query.find [ class "form-text" ]
                    >> Query.has [ text "Lorem ipsum." ]
                , Query.findAll [ class "list-group" ]
                    >> Query.count (Expect.equal 1)
                ]
            )


isTuple : SchemaBuilder -> Expectation
isTuple schema =
    schema
        |> Expect.all
            [ isField
            , hasFieldDescription
            , view
                (Expect.all
                    [ Query.has [ class "form-group" ]
                    , Query.findAll [ class "form-group" ]
                        >> Query.count (Expect.atLeast 1)
                    ]
                )
            ]


isSwitch : SchemaBuilder -> Expectation
isSwitch schema =
    schema
        |> Expect.all
            [ view
                (Expect.all
                    [ Query.has [ tag "div", class "form-group" ]
                    , Query.find [ class "switch" ]
                        >> Query.children [ tag "div", class "form-check" ]
                        >> Query.each
                            (Expect.all
                                [ Query.find [ tag "input" ]
                                    >> Query.has
                                        [ class "form-check-input"
                                        , checked False
                                        , attribute
                                            (Html.Attributes.attribute
                                                "name"
                                                "switch"
                                            )
                                        , attribute
                                            (Html.Attributes.attribute
                                                "type"
                                                "radio"
                                            )
                                        ]
                                ]
                            )
                    , Query.findAll [ class "label-text" ]
                        >> Query.index 0
                        >> Query.has [ text "One" ]
                    , Query.findAll [ class "label-text" ]
                        >> Query.index 1
                        >> Query.has [ text "Two" ]
                    , Query.findAll [ class "form-check-input" ]
                        >> Query.index 0
                        >> Query.has
                            [ attribute
                                (Html.Attributes.attribute
                                    "value"
                                    "option0"
                                )
                            ]
                    , Query.findAll [ class "form-check-input" ]
                        >> Query.index 1
                        >> Query.has
                            [ attribute
                                (Html.Attributes.attribute
                                    "value"
                                    "option1"
                                )
                            ]
                    ]
                )
            ]


isSelect : SchemaBuilder -> Expectation
isSelect schema =
    schema
        |> withAnyOf
            [ buildSchema
                |> withTitle "One"
                |> withConst (Json.Encode.string "one")
            , buildSchema
                |> withTitle "Two"
                |> withConst (Json.Encode.string "two")
            ]
        |> Expect.all
            [ isField
            , view
                (Expect.all
                    [ Query.find
                        [ tag "select"
                        , classes [ "form-control", "custom-select" ]
                        ]
                        >> Query.children [ tag "option" ]
                        >> Query.count (Expect.equal 2)
                    , Query.findAll [ tag "option" ]
                        >> Query.index 0
                        >> Query.has
                            [ text "One"
                            , selected False
                            , attribute
                                (Html.Attributes.attribute "value" "one")
                            ]
                    , Query.findAll [ tag "option" ]
                        >> Query.index 1
                        >> Query.has
                            [ text "Two"
                            , selected False
                            , attribute
                                (Html.Attributes.attribute "value" "two")
                            ]
                    ]
                )
            ]


isNumberSelect : SchemaBuilder -> Expectation
isNumberSelect schema =
    schema
        |> withAnyOf
            [ buildSchema
                |> withTitle "One"
                |> withConst (Json.Encode.int 1)
            , buildSchema
                |> withTitle "Two"
                |> withConst (Json.Encode.int 2)
            ]
        |> Expect.all
            [ isField
            , view
                (Expect.all
                    [ Query.find
                        [ tag "select"
                        , classes [ "form-control", "custom-select" ]
                        ]
                        >> Query.children [ tag "option" ]
                        >> Query.count (Expect.equal 2)
                    , Query.findAll [ tag "option" ]
                        >> Query.index 0
                        >> Query.has
                            [ text "One"
                            , selected False
                            , attribute (Html.Attributes.attribute "value" "1")
                            ]
                    , Query.findAll [ tag "option" ]
                        >> Query.index 1
                        >> Query.has
                            [ text "Two"
                            , selected False
                            , attribute (Html.Attributes.attribute "value" "2")
                            ]
                    ]
                )
            ]
