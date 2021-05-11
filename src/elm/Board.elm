module Board exposing (Finished(..), Model, Msg, init, subscriptions, update, view)

import Dict exposing (Dict)
import Html as H exposing (Html)
import Html.Attributes as A
import Html.Events as E
import Json.Decode as D
import Ports
import Random exposing (Generator)
import Random.List
import Time


type alias Model =
    { width : Int
    , height : Int
    , tiles : Maybe (Dict ( Int, Int ) Tile)
    , finished : Maybe Finished
    , started : Bool
    , timer : Int
    }


type Msg
    = ReceiveGeneratedTiles (Dict ( Int, Int ) Tile)
    | ClickTile ( Int, Int )
    | FlagTile ( Int, Int )
    | Tick


type Finished
    = Victory
    | Loss


type alias Tile =
    { state : TileState
    , kind : TileKind
    }


type TileState
    = Closed
    | Open
    | Flagged


type TileKind
    = Mine
    | Safe { adjacentMines : Maybe Int }


type OpenResult
    = Exploded
    | OpenedSafe (Dict ( Int, Int ) Tile)


init : Int -> Int -> Int -> ( Model, Cmd Msg )
init width height mines =
    ( { width = width
      , height = height
      , tiles = Nothing
      , finished = Nothing
      , started = False
      , timer = 0
      }
    , initTiles width height mines
        |> Random.generate ReceiveGeneratedTiles
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceiveGeneratedTiles tiles ->
            ( { model | tiles = Just tiles }, Cmd.none )

        ClickTile coords ->
            if model.finished == Nothing then
                case model.tiles of
                    Just tiles ->
                        let
                            openResult =
                                openTile coords tiles
                        in
                            case openResult of
                                Exploded ->
                                    ( { model
                                        | tiles =
                                            model.tiles
                                                |> Maybe.map
                                                    (Dict.map
                                                        (\_ tile ->
                                                            if tile.kind == Mine then
                                                                { tile | state = Open }

                                                            else
                                                                tile
                                                        )
                                                    )
                                        , finished = Just Loss
                                        , started = True
                                      }
                                    , Cmd.none
                                    )

                                OpenedSafe newTiles ->
                                    let
                                        ( finished, cmd ) =
                                            if checkVictory newTiles then
                                                ( Just Victory, Ports.saveScore model.timer )

                                            else
                                                ( Nothing, Cmd.none )
                                    in
                                        ( { model
                                            | tiles = Just newTiles
                                            , finished = finished
                                            , started = True
                                          }
                                        , cmd
                                        )

                    Nothing ->
                        ( model, Cmd.none )

            else
                ( model, Cmd.none )

        FlagTile coords ->
            if model.finished == Nothing then
                ( { model | tiles = model.tiles |> Maybe.map (flagTile coords) }, Cmd.none )

            else
                ( model, Cmd.none )

        Tick ->
            ( { model | timer = model.timer + 1 }, Cmd.none )


view : Model -> Html Msg
view model =
    case model.tiles of
        Just tiles ->
            H.div [ A.class "board-container" ]
                [ H.div [ A.class "top-info" ]
                    [ H.div [] [ H.text <| "Mines left: " ++ (tiles |> minesLeft |> String.fromInt) ]
                    , H.div [] [ H.text <| "Time: " ++ (model.timer |> String.fromInt |> String.padLeft 3 '0') ]
                    ]
                , H.div []
                    (List.range 0 (model.height - 1)
                        |> List.map
                            (\y ->
                                List.range 0 (model.width - 1)
                                    |> List.map
                                        (\x ->
                                            case Dict.get ( x, y ) tiles of
                                                Just tile ->
                                                    viewTile ( x, y ) tile

                                                Nothing ->
                                                    H.text "???"
                                        )
                                    |> H.div []
                            )
                    )
                ]

        Nothing ->
            H.text "Loading board..."


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.started && model.finished == Nothing then
        Time.every 1000 <| always Tick

    else
        Sub.none


checkVictory : Dict ( Int, Int ) Tile -> Bool
checkVictory tiles =
    tiles
        |> Dict.values
        |> List.all (\tile -> tile.state == Open || tile.kind == Mine)


minesLeft : Dict ( Int, Int ) Tile -> Int
minesLeft tiles =
    let
        mines =
            tiles
                |> Dict.values
                |> List.filter (.kind >> (==) Mine)
                |> List.length

        flagged =
            tiles
                |> Dict.values
                |> List.filter (.state >> (==) Flagged)
                |> List.length
    in
        mines - flagged


initTiles : Int -> Int -> Int -> Generator (Dict ( Int, Int ) Tile)
initTiles width height mines =
    let
        total =
            width * height

        tiles =
            List.repeat mines Mine
                ++ List.repeat (total - mines) (Safe { adjacentMines = Nothing })
                |> List.map (Tile Closed)
    in
        Random.List.shuffle tiles
            |> Random.map
                (List.indexedMap
                    (tileCoords width >> Tuple.pair)
                    >> Dict.fromList
                )


viewTile : ( Int, Int ) -> Tile -> Html Msg
viewTile coords tile =
    let
        ( text, class ) =
            case tile.state of
                Closed ->
                    ( ".", "" )

                Open ->
                    case tile.kind of
                        Mine ->
                            ( "X", "opened tile-color-mine" )

                        Safe safe ->
                            case safe.adjacentMines of
                                Just adjacentMines ->
                                    if adjacentMines == 0 then
                                        ( ".", "opened" )

                                    else
                                        let
                                            adjacentMinesString =
                                                String.fromInt adjacentMines
                                        in
                                            ( adjacentMinesString, "opened tile-color-" ++ adjacentMinesString )

                                Nothing ->
                                    ( "!", "opened" )

                Flagged ->
                    ( "F", "" )
    in
        H.button
            [ A.classList
                [ ( "tile", True )
                , ( class, True )
                ]
            , E.onClick <| ClickTile coords
            , E.preventDefaultOn "contextmenu" (D.succeed ( FlagTile coords, True ))
            ]
            [ H.span [] [ H.text text ]
            ]


tileCoords : Int -> Int -> ( Int, Int )
tileCoords width index =
    ( modBy width index, index // width )


openTile : ( Int, Int ) -> Dict ( Int, Int ) Tile -> OpenResult
openTile coords tiles =
    case Dict.get coords tiles of
        Just tile ->
            if tile.state == Closed && tile.kind == Mine then
                Exploded

            else
                let
                    inner (( innerX, innerY ) as innerCoords) innerTiles =
                        case Dict.get innerCoords innerTiles of
                            Just innerTile ->
                                case innerTile.state of
                                    Closed ->
                                        case innerTile.kind of
                                            Mine ->
                                                innerTiles

                                            Safe safe ->
                                                let
                                                    adjacentCoordsList =
                                                        List.range (innerY - 1) (innerY + 1)
                                                            |> List.concatMap
                                                                (\adjacentY ->
                                                                    List.range (innerX - 1) (innerX + 1)
                                                                        |> List.map (\adjacentX -> ( adjacentX, adjacentY ))
                                                                        |> List.filter ((/=) innerCoords)
                                                                )

                                                    newSafe =
                                                        { safe
                                                            | adjacentMines =
                                                                adjacentCoordsList
                                                                    |> List.filterMap (\adjacentCoords -> Dict.get adjacentCoords innerTiles)
                                                                    |> List.filter (.kind >> (==) Mine)
                                                                    |> List.length
                                                                    |> Just
                                                        }

                                                    newTiles =
                                                        Dict.insert
                                                            innerCoords
                                                            { innerTile | state = Open, kind = Safe newSafe }
                                                            innerTiles
                                                in
                                                    if newSafe.adjacentMines == Just 0 then
                                                        adjacentCoordsList
                                                            |> List.foldl inner newTiles

                                                    else
                                                        newTiles

                                    Open ->
                                        innerTiles

                                    Flagged ->
                                        innerTiles

                            Nothing ->
                                innerTiles
                in
                    OpenedSafe <| inner coords tiles

        Nothing ->
            OpenedSafe tiles


flagTile : ( Int, Int ) -> Dict ( Int, Int ) Tile -> Dict ( Int, Int ) Tile
flagTile coords =
    Dict.update
        coords
        (Maybe.map
            (\tile ->
                case tile.state of
                    Closed ->
                        { tile | state = Flagged }

                    Open ->
                        tile

                    Flagged ->
                        { tile | state = Closed }
            )
        )
