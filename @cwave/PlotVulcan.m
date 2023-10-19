function PlotVulcan( oWave )
% cwave::PlotVulcan( oWave )
%
% Plot towed-device depth time series
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
if isempty( oWave.tableVulcan )
    uialert( oWave.hFig, {
        'The Vulcan/TET depth time series is empty.'
        'There is nothing to plot.'
        }, 'Plot Vulcan/TET Depths', 'Icon', 'error' );
    return;
end

% Launch the generic table-plotting UI
[bChgd, tChg, cLog] = UITablePlot( oWave.tableVulcan, 'Time', 'Depth' ...
    , oWave.hFig, 'Plot Towed Device Time Series' ...
    , oWave.sPlotDir, oWave.sPlotSubtitle );

% If the user made changes, log them & update the main table. This will fire off
% listeners so do the log first
if bChgd
    for i = 1:numel(cLog)
        oWave.AddLog( cwave.LogOK, cwave.sLog_S_Vulcan, cLog{i} );
    end
    oWave.tableVulcan = tChg;
end

return;
end % PlotVulcan
