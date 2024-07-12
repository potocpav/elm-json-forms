module Json.Schema.Form exposing
    ( Form
    , Msg
    , init
    , submit
    , update
    , view
    )

import Form exposing (FormState, Msg)
import Html exposing (Html, div)
import Json.Encode as Encode exposing (Value)
import Json.Schema.Definitions exposing (Schema)
import Json.Schema.Form.Fields
import Json.Schema.Form.Options exposing (Options)
import Json.Schema.Form.UiSchema exposing (UiSchema, defaultValue, generateUiSchema)
import Json.Schema.Form.Validation exposing (validation)
import Maybe.Extra as Maybe


type alias Form =
    -- TODO: rename to Form
    { options : Options
    , schema : Schema
    , uiSchema : UiSchema
    , state : FormState
    }


type alias Msg =
    Form.Msg


init : String -> Options -> Schema -> Maybe UiSchema -> Form
init id options schema mUiSchema =
    let
        uiSchema =
            Maybe.withDefaultLazy (\_ -> generateUiSchema schema) mUiSchema
    in
    Form options schema uiSchema <|
        Form.initial id (defaultValue schema) (validation schema)


update : Msg -> Form -> Form
update msg form =
    let
        formState : FormState
        formState =
            Form.update
                (validation form.schema)
                (Debug.log "message" msg)
                form.state
    in
    { form | state = (\( _, a ) -> a) <| Debug.log "form" ( Encode.encode 0 <| formState.value, formState ) }


view : Form -> Html Msg
view form =
    div [] <| Json.Schema.Form.Fields.uiSchemaView form.options { uiPath = [], disabled = False } form.uiSchema form.schema form.state


submit : Msg
submit =
    Form.Submit
