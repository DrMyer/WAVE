function PlotRxNavDriftMap( oWave )
% cwave::PlotRxNavDriftMap( oWave )
%
% Plot RX drift map - navigated location vs dropped location
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % If the table is empty, don't allow plotting
    if isempty( oWave.tableRxNav )
        uialert( oWave.hFig, {
            'The Receiver navigation table is empty.'
            }, 'Plot Receiver Drift Map' );
        return;
    end
    
    % For convenience, shorten the reference to the table and make the UTM in km
    % instead of meters
    tbl             = oWave.tableRxNav;
    tbl.East        = tbl.East / 1000;
    tbl.North       = tbl.North / 1000;
    tbl.Drop_East   = tbl.Drop_East / 1000;
    tbl.Drop_North  = tbl.Drop_North / 1000;
    
    % Create the figure & subplots
    hFig    = getStackedFig( 'pptHD' );
    hDrift  = axes( hFig );
    
    % Plot the site drift vectors
    dX = (tbl.East  - tbl.Drop_East)  * 1000; % km --> m
    dY = (tbl.North - tbl.Drop_North) * 1000; % km --> m
    d  = sqrt( dX.^2 + dY.^2 );
    nClrs = turbo( height(tbl) );
    for iRx = 1:height(tbl)
        plot( hDrift, [0 dX(iRx)], [0 dY(iRx)] ...
            , 'Marker', 'none', 'LineStyle', '-', 'Color', nClrs(iRx,:) ...
            , 'DisplayName', tbl.RxName{iRx}, 'ButtonDownFcn', @ptText );
        hold( hDrift, 'on' );
    end
    hold( hDrift, 'off' );
    axis( hDrift, 'equal' );
    axisTight( hDrift );
    xlabel( hDrift, 'Easterly Drift (m)' );
    ylabel( hDrift, 'Northerly Drift (m)' );
    title( hDrift, {'RX Navigation Drift Vectors'
        oWave.sPlotSubtitle
        sprintf( 'Mean Drift: %.0f +/- %.0f m', mean(d,'omitnan'), std(d,'omitnan') )
        } );
    hFig.Name = 'RX Navigation Drift Vectors';
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'RxNav_Drift' ), 'Save', [], 'PNGOnly' );
    
    return;
end % PlotRxNavDriftMap
