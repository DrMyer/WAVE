function PlotBenthos( oWave )
% cwave::PlotBenthos( oWave )
%
% Plot benthos pings to barracudas (TX iLBL nav recorded by SUESI)
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
if isempty( oWave.tableBenthos )
    uialert( oWave.hFig, {
        'The Benthos ping time series is empty.'
        'There is nothing to plot.'
        }, 'Plot Benthos Pings', 'Icon', 'error' );
    return;
end

% Launch the generic table-plotting UI
[bChgd, tChg, cLog] = UITablePlot( oWave.tableBenthos, 'Time', 'ReplyTWTT' ...
    , oWave.hFig, 'Plot Benthos Ping Info' ...
    , oWave.sPlotDir, oWave.sPlotSubtitle );

% If the user made changes, log them & update the main table. This will fire off
% listeners so do the log first
if bChgd
    for i = 1:numel(cLog)
        oWave.AddLog( cwave.LogOK, cwave.sLog_S_Benthos, cLog{i} );
    end
    oWave.tableBenthos = tChg;
end

return;
end % PlotBenthos
