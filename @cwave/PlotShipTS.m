function PlotShipTS( oWave )
% cwave::PlotShipTS( oWave )
%
% Plot aggregated ship time series
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
if isempty( oWave.tableShipTS )
    uialert( oWave.hFig, {
        'The Ship Data time series is empty.'
        'There is nothing to plot.'
        }, 'Plot Ship Data Time Series', 'Icon', 'error' );
    return;
end

% Launch the generic table-plotting UI
[bChgd, tChg, cLog] = UITablePlot( oWave.tableShipTS, 'East', 'North' ...
    , oWave.hFig, 'Plot Ship Data Time Series' ...
    , oWave.sPlotDir, oWave.sPlotSubtitle );

% If the user made changes, log them & update the main table. This will fire off
% listeners so do the log first
if bChgd
    for i = 1:numel(cLog)
        oWave.AddLog( cwave.LogOK, cwave.sLog_ShipGPS, cLog{i} );
    end
    oWave.tableShipTS = tChg;
end

return;
end % PlotShipTS
