module Schema.Error exposing (Errors, ValidationError(..))

import Form exposing (Form)
import Form.Error exposing (ErrorValue(..))


type ValidationError
    = Invalid
    | InvalidSet
    | ShorterListThan Int
    | LongerListThan Int


type alias Errors e =
    String -> ErrorValue e -> String
