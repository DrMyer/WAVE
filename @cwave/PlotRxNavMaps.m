function PlotRxNavMaps( oWave )
% cwave::PlotRxNavMaps( oWave )
%
% Plot RX navigation maps. Public method of the cwave class.
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end

    % If the table is empty, don't allow plotting
    if isempty( oWave.tableRxNav )
        uialert( oWave.hFig, {
            'The Receiver navigation table is empty.'
            }, 'Plot Receiver Maps' );
        return;
    end
    
    % For convenience, shorten the reference to the table and make the UTM in km
    % instead of meters
    tbl = oWave.tableRxNav;
    tbl.East        = tbl.East / 1000;
    tbl.North       = tbl.North / 1000;
    tbl.XY_Major    = tbl.XY_Major / 1000;
    tbl.XY_Minor    = tbl.XY_Minor / 1000;
    
    % Create the Lon,Lat figure
    hFig = getStackedFig( 'pptHD' );
    hMap = axes( hFig );
    % Plot each point separately so that the user can turn the names on/off as
    % desired to clean up the map
    for iRx = 1:height(tbl)
        hLn = plot( hMap, tbl.Longitude(iRx), tbl.Latitude(iRx) ...
            , 'DisplayName', tbl.RxName{iRx} ...
            , 'Marker', '.', 'MarkerSize', 6, 'LineStyle', 'none', 'Color', 'k' ...
            , 'ButtonDownFcn', @ptText );
        hold( hMap, 'on' );
        hTx = text( hMap, tbl.Longitude(iRx), tbl.Latitude(iRx) ...
            , ['  ' tbl.RxName{iRx} '  '] ...
            , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'bottom' ...
            , 'UserData', hLn, 'ButtonDownFcn', {@clearText,hLn} );
        hLn.UserData = hTx;
    end
    hold( hMap, 'off' );
    axis( hMap, 'equal' );
    axisTight( hMap );
    xlabel( hMap, 'Longitude' );
    ylabel( hMap, 'Latitude' );
    title( hMap, {'Navigated Receiver Locations - Lon,Lat'; oWave.sPlotSubtitle} );
    hFig.Name = 'Navigated Receiver Locations - Lon,Lat';
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'RxNav_Map_LonLat' ), 'Save' );
    
    % Create the UTM figure
    hFig = getStackedFig( 'pptHD' );
    hMap = axes( hFig );
    for iRx = 1:height(tbl)
        hLn = plot( hMap, tbl.East(iRx), tbl.North(iRx), 'DisplayName', tbl.RxName{iRx} ...
            , 'Marker', '.', 'MarkerSize', 6, 'LineStyle', 'none', 'Color', 'k' ...
            , 'ButtonDownFcn', @ptText );
        hold( hMap, 'on' );
        hTx = text( hMap, tbl.East(iRx), tbl.North(iRx), ['  ' tbl.RxName{iRx} '  '] ...
            , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'bottom' ...
            , 'UserData', hLn, 'ButtonDownFcn', {@clearText,hLn} );
        hLn.UserData = hTx;
        %{
        %-- Error ellipses
        nAngles = pi() / 180 * (0:360);
        nX =  tbl.XY_Major(iRx) * cos(tbl.XY_Phi(iRx)) * cos(nAngles) ...
            - tbl.XY_Minor(iRx) * sin(tbl.XY_Phi(iRx)) * sin(nAngles);
        nY =  tbl.XY_Major(iRx) * sin(tbl.XY_Phi(iRx)) * cos(nAngles) ...
            + tbl.XY_Minor(iRx) * cos(tbl.XY_Phi(iRx)) * sin(nAngles);
        legendoff( plot( hMap, nX + tbl.East(iRx), nY + tbl.North(iRx) ...
            , 'Marker', 'none', 'Color', 'k' ...
            , 'LineStyle', '-', 'LineWidth', 0.5 ) );
        %}
    end
    hold( hMap, 'off' );
    axis( hMap, 'equal' );
    axisTight( hMap );
    axisTicksUTM( hMap, 'xy' );
    xlabel( hMap, 'Easting (km)' );
    ylabel( hMap, 'Northing (km)' );
    sTitle = ['Navigated Receiver Locations - UTM ' oWave.sUTMZoneDisp];
    title( hMap, {sTitle; oWave.sPlotSubtitle} );
    hFig.Name = sTitle;
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, ['RxNav_Map_UTM_' oWave.sUTMZoneFile] ), 'Save' );
    
    return;
end % PlotRxNavMaps

%-------------------------------------------------------------------------------
% Copy of clearText from inside ptText so I can start with the texts displayed
% and still mimic the behavior of click on/off
function clearText(hText,~,hObj)
    if ishandle( hObj )
        hObj.UserData = [];
    end
    delete( hText );
    return;
end
