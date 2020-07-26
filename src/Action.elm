module Action exposing (..)

import Card exposing (..)
import Debug exposing (log, toString)
import Geometry exposing (..)
import Message exposing (..)
import Model exposing (..)
import Population exposing (..)
import Random exposing (float, generate)
import Tile exposing (..)
import Todo exposing (..)
import Virus exposing (..)


updateLog : Model -> Model
updateLog model =
    let
        card =
            List.map Tuple.second model.todo

        log =
            List.map CardPlayed card

        warning =
            List.filter isWarning model.actionDescribe
    in
    { model | actionDescribe = log ++ warning }


createGuide : Model -> List String
createGuide model =
    let
        str =
            List.take model.currentLevel tutorial
                |> List.foldl (\x -> \y -> x ++ y) []

        card =
            List.map Tuple.second model.todo
    in
    case model.currentLevel of
        1 ->
            if model.hands == [ megaClone ] && model.currentRound == 1 then
                str |> getElement 1

            else if card == [ megaClone ] && model.currentRound == 1 then
                str |> getElement 2

            else if List.length model.hands > 0 && model.currentRound == 2 then
                str |> getElement 3

            else if model.hands == [] && model.currentRound == 2 then
                str |> getElement 4

            else if model.hands == [] && model.currentRound == 3 then
                str |> getElement 5

            else
                str |> getElement 6

        2 ->
            if model.currentRound == 1 then
                str |> getElement 1

            else if model.currentRound == 2 then
                str |> getElement 2

            else if model.currentRound < 5 then
                str |> getElement 3

            else if model.currentRound /= 6 && not (List.isEmpty model.virus.pos) then
                str |> getElement 4

            else if model.currentRound == 6 then
                str |> getElement 5

            else
                getElement 6 str

        _ ->
            []


pickAction : Model -> ( Model, Cmd Msg )
pickAction model =
    let
        ( finished, unfinished_ ) =
            List.partition (\( ( x, y ), z ) -> not x) model.todo

        headQueue_ =
            unfinished_
                |> List.head
                |> Maybe.withDefault finishedEmptyQueue

        headAction =
            headQueue_
                |> Tuple.first
                |> Tuple.second
                |> List.head
                |> Maybe.withDefault NoAction

        headQueue =
            ( ( False, headQueue_ |> Tuple.first |> Tuple.second ), Tuple.second headQueue_ )

        todo =
            finished ++ [ headQueue ] ++ List.drop 1 unfinished_
    in
    { model | todo = todo } |> performAction headAction


performAction : Action -> Model -> ( Model, Cmd Msg )
performAction action model =
    case action of
        IncPowerI inc ->
            ( { model | power = model.power + inc } |> updateLog, Cmd.none )

        Freeze prob ->
            ( model |> updateLog, Random.generate (FreezeRet prob) (Random.float 0 1) )

        FreezeI ->
            let
                behavior_ =
                    model.behavior

                behavior =
                    { behavior_ | virusEvolve = False }
            in
            ( { model | behavior = behavior } |> updateLog, Cmd.none )

        EcoDoubleI_Freeze prob ->
            ( { model | ecoRatio = 2 * model.ecoRatio } |> updateLog, Random.generate (FreezeRet prob) (Random.float 0 1) )

        CutHexI ( i, j ) ->
            let
                virus_ =
                    model.virus

                pos_ =
                    virus_.pos

                pos =
                    List.filter (\( x, y ) -> ( x, y ) /= ( i, j )) pos_

                virus =
                    { virus_ | pos = pos }
            in
            ( { model | virus = virus } |> updateLog, Cmd.none )

        CutTileI ( i, j ) ->
            let
                ( t1, t2 ) =
                    converHextoTile ( i, j )

                ( c1, c2 ) =
                    ( 2 * t1 - t2, t1 + 3 * t2 )

                lc =
                    log "chosenTile" ( t1, t2 )

                virus_ =
                    model.virus

                pos_ =
                    virus_.pos

                pos =
                    List.filter
                        (\( x, y ) ->
                            not (List.member ( x, y ) (( c1, c2 ) :: generateZone ( c1, c2 )))
                        )
                        pos_

                virus =
                    { virus_ | pos = pos }
            in
            ( { model | virus = virus } |> updateLog, Cmd.none )

        Activate996I ->
            let
                virus_ =
                    model.virus

                dr =
                    1.024 * virus_.kill

                virus =
                    { virus_ | kill = dr }
            in
            ( { model | ecoRatio = 2 * model.ecoRatio, virus = virus } |> updateLog, Cmd.none )

        OrganCloneI ( i, j ) ->
            let
                city_ =
                    model.city

                tilelst_ =
                    model.city.tilesIndex

                pos =
                    converHextoTile ( i, j )

                tilelst =
                    List.map
                        (\x ->
                            if x.indice == pos then
                                if x.sick - x.dead > 0 then
                                    { x | sick = x.sick - x.dead }

                                else
                                    { x | sick = 0 }

                            else
                                x
                        )
                        tilelst_

                city =
                    { city_ | tilesIndex = tilelst }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        HumanCloneI ( i, j ) ->
            let
                city_ =
                    model.city

                tilelst_ =
                    model.city.tilesIndex

                pos =
                    converHextoTile ( i, j )

                tilelst =
                    List.map
                        (\x ->
                            if x.indice == pos then
                                { x | population = x.population * 2 }

                            else
                                x
                        )
                        tilelst_

                city =
                    { city_ | tilesIndex = tilelst }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        MegaCloneI ->
            let
                city_ =
                    model.city

                tilelst_ =
                    model.city.tilesIndex

                tilelst =
                    List.map (\x -> { x | population = round (toFloat x.population * 1.5) }) tilelst_

                city =
                    { city_ | tilesIndex = tilelst }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        PurificationI ( i, j ) ->
            let
                city_ =
                    model.city

                tilelst_ =
                    model.city.tilesIndex

                pos =
                    converHextoTile ( i, j )

                tilelst =
                    List.map
                        (\x ->
                            if x.indice == pos then
                                { x | sick = 0 }

                            else
                                x
                        )
                        tilelst_

                city =
                    { city_ | tilesIndex = tilelst }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        SacrificeI ( i, j ) ->
            let
                virus_ =
                    model.virus

                virpos_ =
                    virus_.pos

                virpos =
                    List.filter (\x -> converHextoTile x /= ( i, j )) virpos_

                city_ =
                    model.city

                tilelst_ =
                    model.city.tilesIndex

                tilepos =
                    converHextoTile ( i, j )

                tilelst =
                    List.map
                        (\x ->
                            if x.indice == tilepos then
                                { x
                                    | population = x.population - x.sick
                                    , sick = 0
                                    , dead = x.dead + x.sick
                                }

                            else
                                x
                        )
                        tilelst_

                city =
                    { city_ | tilesIndex = tilelst }

                virus =
                    { virus_ | pos = virpos }
            in
            ( { model | city = city, virus = virus } |> updateLog, Cmd.none )

        ResurgenceI ( i, j ) ->
            let
                city_ =
                    model.city

                tilelst_ =
                    model.city.tilesIndex

                pos =
                    converHextoTile ( i, j )

                tilelst =
                    List.map
                        (\x ->
                            if x.indice == pos then
                                { x
                                    | population = x.population + round (toFloat x.dead / 2)
                                    , dead = x.dead - round (toFloat x.dead / 2)
                                }

                            else
                                x
                        )
                        tilelst_

                city =
                    { city_ | tilesIndex = tilelst }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        FreezevirusI ( i, j ) ->
            let
                pos =
                    converHextoTile ( i, j )

                virus_ =
                    model.virus

                virpos =
                    List.filter (\x -> converHextoTile x /= pos) virus_.pos

                virus =
                    { virus_ | pos = virpos }
            in
            ( { model | virus = virus } |> updateLog, Cmd.none )

        HospitalI ( i, j ) ->
            let
                ( ti, tj ) =
                    converHextoTile ( i, j )

                city_ =
                    model.city

                city =
                    { city_
                        | tilesIndex =
                            List.map
                                (\x ->
                                    if x.indice == ( ti, tj ) then
                                        { x
                                            | hos = True
                                            , cureEff = 5
                                        }

                                    else
                                        x
                                )
                                city_.tilesIndex
                    }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        QuarantineI ( i, j ) ->
            let
                ( ti, tj ) =
                    converHextoTile ( i, j )

                city_ =
                    model.city

                city =
                    { city_
                        | tilesIndex =
                            List.map
                                (\x ->
                                    if x.indice == ( ti, tj ) then
                                        { x | qua = True }

                                    else
                                        x
                                )
                                city_.tilesIndex
                    }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        EnhancedHealingI ->
            let
                city_ =
                    model.city

                city =
                    { city_
                        | tilesIndex =
                            List.map
                                (\x ->
                                    if x.hos then
                                        { x | cureEff = x.cureEff + 1 }

                                    else
                                        x
                                )
                                city_.tilesIndex
                    }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        AttractPeoI ( i, j ) ->
            let
                ( ti, tj ) =
                    converHextoTile ( i, j )

                city_ =
                    model.city

                city =
                    { city_
                        | tilesIndex =
                            List.map
                                (\x ->
                                    if x.indice == ( ti, tj ) then
                                        { x | peoFlow = False }

                                    else
                                        x
                                )
                                city_.tilesIndex
                    }
            in
            ( { model | city = city } |> updateLog, Cmd.none )

        StopAttractI ( i, j ) ->
            let
                ( ti, tj ) =
                    converHextoTile ( i, j )

                city_ =
                    model.city

                city =
                    { city_
                        | tilesIndex =
                            List.map
                                (\x ->
                                    if x.indice == ( ti, tj ) then
                                        { x | peoFlow = True }

                                    else
                                        x
                                )
                                city_.tilesIndex
                    }
            in
            ( { model | city = city }, Cmd.none )

        DroughtI_Kill ( ( i, j ), prob ) ->
            ( { model | ecoRatio = 0.5 * model.ecoRatio } |> updateLog, Random.generate (KillTileVir ( ( i, j ), prob )) (Random.float 0 1) )

        WarehouseI ( i, j ) ->
            let
                ( ti, tj ) =
                    converHextoTile ( i, j )

                city_ =
                    model.city

                city =
                    { city_
                        | tilesIndex =
                            List.map
                                (\x ->
                                    if x.indice == ( ti, tj ) then
                                        { x | wareHouse = True }

                                    else
                                        x
                                )
                                city_.tilesIndex
                    }

                num =
                    model.warehouseNum + 1
            in
            ( { model | city = city, warehouseNum = num } |> updateLog, Cmd.none )

        Warmwave_KIA ( ( i, j ), prob ) ->
            ( model |> updateLog, Random.generate (KillTileVir ( ( i, j ), prob )) (Random.float 0 1) )

        AVI ( i, j ) ->
            ( { model | av = createAV ( i, j ) } |> updateLog, Cmd.none )

        JudgeI_Kill ( ( i, j ), prob ) ->
            ( model |> updateLog, Random.generate (JudgeVirPeo ( ( i, j ), prob )) (Random.float 0 1) )

        EvacuateI ( i, j ) ->
            let
                ( ti, tj ) =
                    converHextoTile ( i, j )

                tlst =
                    model.city.tilesIndex

                t =
                    List.filter (\x -> x.indice == ( ti, tj )) tlst
                        |> List.head
                        |> Maybe.withDefault (Tile ( -100, -100 ) 0 0 0 0 True False False False)

                city =
                    model.city

                city_ =
                    { city
                        | tilesIndex =
                            evacuate t city
                    }
            in
            ( { model | city = city_ } |> updateLog, Cmd.none )

        Summon cardlst ->
            let
                hands_ =
                    model.hands

                hands =
                    List.append hands_ cardlst
            in
            ( { model | hands = hands } |> updateLog, Cmd.none )

        _ ->
            ( model, Cmd.none )
