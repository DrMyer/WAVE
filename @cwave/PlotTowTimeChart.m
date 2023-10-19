function PlotTowTimeChart( oWave )
% cwave::PlotTowTimeChart( oWave )
%
% Plot tableTow - tow number, times, & TX time lag
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
    
    % Must have something to plot
    if isempty( oWave.tableTow )
        uialert( oWave.hFig, {
            'The tow time table is empty.'
            'There is nothing to plot.'
            }, 'Plot Tow Charts', 'Icon', 'error' );
        return;
    end
    if isempty( oWave.tableSDM )
        uialert( oWave.hFig, {
            'The SDM Time Series table is empty.'
            'There is nothing to plot.'
            }, 'Plot Tow Charts', 'Icon', 'error' );
        return;
    end
    
    % How many tows are there? Get colors for each and the from-to coverage
    iTow    = cwave.IndexIntoTimeTable( oWave.tableTow, oWave.tableSDM.Time );
    iTowList= unique( iTow(~isnan(iTow)) );
    nClrs   = DavesDiscreteColors( numel(iTowList) );
    
    % Plot two maps - one in lon,lat the other in UTM
    
    %-- Lon,Lat
    hFig = figCenter( oWave.hFig, 'ppt', 'Name', 'Tow Time Chart - Lon,Lat' );
    hMap = axes( hFig );
    plot( hMap, oWave.tableSDM.Ship_Lon, oWave.tableSDM.Ship_Lat ...
        , 'Color', 'k', 'Marker', '.', 'MarkerSize', 3 ...
        , 'LineStyle', 'None', 'DisplayName', 'Ship' );
    hold( hMap, 'on' );
    for i = 1:numel(iTowList)
        bPlot = (iTow == iTowList(i));
        plot( hMap, oWave.tableSDM.Ship_Lon(bPlot), oWave.tableSDM.Ship_Lat(bPlot) ...
            , 'Color', nClrs(i,:), 'Marker', 'o', 'MarkerSize', 6 ...
            , 'LineStyle', 'None' ...
            , 'DisplayName', ['Tow ' num2str(oWave.tableTow.TowNo(iTowList(i)))] );
    end
    title( hMap, {'Tow Time Chart'; oWave.sPlotSubtitle} );
    xlabel( hMap, 'Longitude' );
    ylabel( hMap, 'Latitude' );
    axisTight( hMap );
    axis( hMap, 'equal' );
    legend( hMap, 'Location', 'best' );
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'TowTimeChart_LonLat' ) ...
        , 'Save', 'NoStrip', 'PNGOnly' );
    
    %-- UTM
    nE = oWave.tableSDM.Ship_East / 1000;       % m --> km
    nN = oWave.tableSDM.Ship_North / 1000;
    hFig = figCenter( oWave.hFig, 'ppt', 'Name', 'Tow Time Chart - UTM' );
    hMap = axes( hFig );
    plot( hMap, nE, nN, 'Color', 'k', 'Marker', '.', 'MarkerSize', 3 ...
        , 'LineStyle', 'None', 'DisplayName', 'Ship' );
    hold( hMap, 'on' );
    for i = 1:numel(iTowList)
        bPlot = (iTow == iTowList(i));
        plot( hMap, nE(bPlot), nN(bPlot) ...
            , 'Color', nClrs(i,:), 'Marker', 'o', 'MarkerSize', 6 ...
            , 'LineStyle', 'None' ...
            , 'DisplayName', ['Tow ' num2str(oWave.tableTow.TowNo(iTowList(i)))] );
    end
    title( hMap, {'Tow Time Chart'; oWave.sPlotSubtitle} );
    xlabel( hMap, ['Easting (km) - UTM ' oWave.sUTMZoneDisp] );
    ylabel( hMap, 'Northing (km)' );
    axisTight( hMap );
    axis( hMap, 'equal' );
    legend( hMap, 'Location', 'best' );
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, ['TowTimeChart_UTM_' oWave.sUTMZoneFile])...
        , 'Save', 'NoStrip', 'PNGOnly' );
    
    return;
end % PlotTowTimeChart
