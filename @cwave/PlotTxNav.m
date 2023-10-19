function PlotTxNav( oWave )
% cwave::PlotTxNav( oWave )
%
% Plot TX Navigation
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
if isempty( oWave.tableTxNav )
    uialert( oWave.hFig, {
        'The TX Navigation time series is empty.'
        'There is nothing to plot.'
        }, 'Plot TX Nav Time Series', 'Icon', 'error' );
    return;
end

% Launch the generic table-plotting UI
[bChgd, tChg, cLog] = UITablePlot( oWave.tableTxNav, 'East', 'North' ...
    , oWave.hFig, 'Plot Tx Nav' ...
    , oWave.sPlotDir, oWave.sPlotSubtitle );

% If the user made changes, log them & update the main table. This will fire off
% listeners so do the log first
if bChgd
    for i = 1:numel(cLog)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction, cLog{i} );
    end
    oWave.tableTxNav = tChg;
end

return;
end % PlotTxNav
