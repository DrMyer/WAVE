function PlotSDM( oWave )
% cwave::PlotSDM( oWave )
%
% Plot source dipole moment
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
if isempty( oWave.tableSDM )
    uialert( oWave.hFig, {
        'The source dipole moment time series is empty.'
        'There is nothing to plot.'
        }, 'Plot SDM Time Series', 'Icon', 'error' );
    return;
end

% Launch the generic table-plotting UI
[bChgd, tChg, cLog] = UITablePlot( oWave.tableSDM, 'Time', 'SDM' ...
    , oWave.hFig, 'Plot SDM Time Series' ...
    , oWave.sPlotDir, oWave.sPlotSubtitle );

% If the user made changes, log them & update the main table. This will fire off
% listeners so do the log first
if bChgd
    for i = 1:numel(cLog)
        oWave.AddLog( cwave.LogOK, cwave.sLog_S_SDM, cLog{i} );
    end
    oWave.tableSDM = tChg;
end

return;
end % PlotSDM
