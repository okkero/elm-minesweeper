module Main exposing (main)

import Board
import Browser exposing (Document)
import Html as H exposing (Html)
import Html.Events as E
import Ports exposing (Score)


type alias Flags =
    ()


type alias Model =
    { board : Board.Model
    , scoreboard : List Score
    }


type Msg
    = BoardMsg Board.Msg
    | ClickRestart
    | ReceiveScoreboard (List Score)


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : Flags -> ( Model, Cmd Msg )
init _ =
    let
        ( board, boardCmd ) =
            Board.init 12 12 20
    in
        ( { board = board
          , scoreboard = []
          }
        , Cmd.map BoardMsg boardCmd
        )


view : Model -> Document Msg
view model =
    { title = "Minesweeper"
    , body =
        [ H.div []
            [ Board.view model.board |> H.map BoardMsg
            , H.button [ E.onClick ClickRestart ] [ H.text "Restart" ]
            , case model.board.finished of
                Just Board.Victory ->
                    H.h2 [] [ H.text "You win!" ]

                Just Board.Loss ->
                    H.h2 [] [ H.text "You lose!" ]

                Nothing ->
                    H.text ""
            ]
        , H.div [] [ viewScoreboard model.scoreboard ]
        ]
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BoardMsg boardMsg ->
            let
                ( newBoard, boardCmd ) =
                    Board.update boardMsg model.board
            in
                ( { model | board = newBoard }, Cmd.map BoardMsg boardCmd )

        ClickRestart ->
            let
                ( board, boardCmd ) =
                    Board.init 12 12 20
            in
                ( { model | board = board }, Cmd.map BoardMsg boardCmd )

        ReceiveScoreboard scoreboard ->
            ( { model | scoreboard = scoreboard }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.scoreboardUpdated ReceiveScoreboard
        , Board.subscriptions model.board
            |> Sub.map BoardMsg
        ]


viewScoreboard : List Score -> Html Msg
viewScoreboard scoreboard =
    H.table []
        [ H.thead []
            [ H.tr []
                [ H.th [] [ H.text "Name" ]
                , H.th [] [ H.text "Time" ]
                ]
            ]
        , scoreboard
            |> List.map
                (\score ->
                    H.tr []
                        [ H.td [] [ H.text score.name ]
                        , H.td [] [ H.text <| String.fromInt score.time ]
                        ]
                )
            |> H.tbody []
        ]
