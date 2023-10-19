function PlotAtmPressure( oWave )
% cwave::PlotAtmPressure( oWave )
%
% Public method of the cwave class. Plot the avg atm pressure table
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % If the table is empty, don't allow plotting
    if isempty( oWave.tableAtmPres )
        uialert( oWave.hFig, {
            'The average atmospheric pressure table is empty.'
            ''
            'You can fill this table automatically on the "Ship Data"'
            'tab from a variety of formats of ship-produced log files.'
            ''
            'You can also manually create an average pressure table'
            'on either the "Ship Data" or "SUESI Logs" tabs.'
            }, 'Plot Atmospheric Pressure' );
        return;
    end
    
    % Get a generic plot figure centered over the main window
    hFig = figCenter( oWave.hFig );
    hAx  = gca();
    
    % NB: unfortunately, errorbar() does NOT support datetime data types
    % errorbar( hAx, oWave.tableAtmPres.Date, oWave.tableAtmPres.Mean, oWave.tableAtmPres.Std );
    x = oWave.tableAtmPres.Date;
    y = oWave.tableAtmPres.Mean;
    hLn = plot( hAx, x, y, 'Marker', '.', 'LineStyle', 'none' );
    
    % Plot error bars
    hold( hAx, 'on' );
    s = reshape( oWave.tableAtmPres.Std, 1, [] );
    s = [-s; s; s*NaN] + reshape( y, 1, [] );
    plot( hAx, repmat(reshape(x,1,[]),3,1), s ...
        , 'Marker', 'none', 'LineStyle', '-', 'Color', hLn.Color );
    
    % Finish up the plot
    axisTight( hAx );
    hAx.XTickLabelRotation = 30;    % ticks are labeled with datetime strings
    ylabel( hAx, 'Pressure (mbar)' );
    title( hAx, {
        'Average Atmospheric Pressure'
        oWave.sPlotSubtitle
        } );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'AvgAtmPressure' ), 'Save' );
    
    return;
end % PlotAtmPressure
