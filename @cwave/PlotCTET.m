function PlotCTET( oWave )
% cwave::PlotCTET( oWave )
%
% Plot CTET GPS time series
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
if isempty( oWave.tableCTET )
    uialert( oWave.hFig, {
        'The CTET time series is empty.'
        'There is nothing to plot.'
        }, 'Plot CTET Time Series', 'Icon', 'error' );
    return;
end

% Launch the generic table-plotting UI
[bChgd, tChg, cLog] = UITablePlot( oWave.tableCTET, 'East', 'North' ...
    , oWave.hFig, 'Plot CTET Time Series' ...
    , oWave.sPlotDir, oWave.sPlotSubtitle );

% If the user made changes, log them & update the main table. This will fire off
% listeners so do the log first
if bChgd
    for i = 1:numel(cLog)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_CTET, cLog{i} );
    end
    oWave.tableCTET = tChg;
end

return;
end % PlotCTET
