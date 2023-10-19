function PlotRxDropMaps( oWave )
% cwave::PlotRxDropMaps( oWave )
%
% Plot Nodal RX DROP LOCATION maps
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
    if isempty( oWave.tableRxDrop )
        uialert( oWave.hFig, {
            'The Nodal Receiver drop location table is empty.'
            }, 'Plot Nodal RX Drop Maps' );
        return;
    end
    
    
    % Plot a lat,lon map of the navigated locations
    hFig = figCenter( oWave.hFig, 'pptHD' );
    hAx  = gca();    % create the plot axes
    plot( hAx, oWave.tableRxDrop.Longitude, oWave.tableRxDrop.Latitude ...
        , 'Marker', '.', 'Color', 'r', 'LineStyle', 'none' );
    hold( hAx, 'on' );
    text( hAx, oWave.tableRxDrop.Longitude, oWave.tableRxDrop.Latitude ...
        , oWave.tableRxDrop.RxName, 'FontSize', 8 ...
        , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'bottom' );
    text( hAx, oWave.tableRxDrop.Longitude, oWave.tableRxDrop.Latitude ...
        , num2str( oWave.tableRxDrop.DucerFreq ), 'FontSize', 8 ...
        , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'top' );
    hold( hAx, 'off' );
    axis( hAx, 'equal' );
    axisTight( hAx );
    xlabel( hAx, 'Longitude' );
    ylabel( hAx, 'Latitude' );
    title( hAx, {
        'Nodal Receiver DROP Locations (Lon,Lat)'
        oWave.sPlotSubtitle
        } );
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'RxDropMap_LonLat' ), 'Save' );
    
    
    % Create a Google Earth KML file
    makeGoogleEarthKML( fullfile( oWave.sPlotDir, 'RxDropMap_LonLat.kml' ) ...
        , oWave.tableRxDrop.Longitude, oWave.tableRxDrop.Latitude ...
        , oWave.tableRxDrop.RxName, false ...
        , ['Nodal RX DROP locations for ' oWave.sPlotSubtitle] );
    
    
    % Plot a UTM map of the navigated locations
    [nE,nN] = oWave.LonLat2UTM( cwave.sLog_Nodal ...
        , oWave.tableRxDrop.Longitude, oWave.tableRxDrop.Latitude );
    nE   = nE / 1000;   % m --> km
    nN   = nN / 1000;
    hFig = getStackedFig( 'pptHD' );
    hAx  = gca();
    plot( hAx, nE, nN, 'Marker', '.', 'Color', 'r', 'LineStyle', 'none' );
    hold( hAx, 'on' );
    text( hAx, nE, nN, oWave.tableRxDrop.RxName, 'FontSize', 8 ...
        , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'bottom' );
    text( hAx, nE, nN, num2str( oWave.tableRxDrop.DucerFreq ), 'FontSize', 8 ...
        , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'top' );
    hold( hAx, 'off' );
    axis( hAx, 'equal' );
    axisTight( hAx );
    axisTicksUTM( hAx );
    xlabel( hAx, ['Easting (km) - ' oWave.sUTMZoneDisp] );
    ylabel( hAx, 'Northing (km)' );
    title( hAx, {
        'Nodal Receiver DROP Locations (UTM)'
        oWave.sPlotSubtitle
        } );
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, ['RxDropMap_UTM_' oWave.sUTMZoneFile] ), 'Save' );
    
    
    return;
end % PlotRxDropMaps
