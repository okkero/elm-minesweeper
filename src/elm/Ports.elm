port module Ports exposing (Score, saveScore, scoreboardUpdated)


type alias Score =
    { name : String
    , time : Int
    }


port saveScore : Int -> Cmd msg


port scoreboardUpdated : (List Score -> msg) -> Sub msg
