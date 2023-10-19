function PlotCudaGPS( oWave )
% cwave::PlotCudaGPS( oWave )
%
% Plot aggregated barracuda GPS time series
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
    if isempty( oWave.tableCudaGPS )
        uialert( oWave.hFig, {
            'The Barracuda time series is empty.'
            'There is nothing to plot.'
            }, 'Plot Barracuda Time Series', 'Icon', 'error' );
        return;
    end
    
    % Ask which plot they want
    switch( uiconfirm( oWave.hFig, {
        'Which plot do you want?'
        ' '
        '1) The QC plot looking for aberrant data'
        '2) Generic plotting / editing UI'
        }, 'Plot Barracuda Time Series' ...
        , 'Options', {'QC Plot', 'Generic UI', 'Cancel'} ...
        , 'DefaultOption', 2, 'CancelOption', 3 ) )
    case 'QC Plot'
        oWave.PlotCudaGPS_QC();
        
    case 'Generic UI'
        % Launch the generic table-plotting UI
        [bChgd, tChg, cLog] = UITablePlot( oWave.tableCudaGPS, 'East', 'North' ...
            , oWave.hFig, 'Plot Barracuda Time Series' ...
            , oWave.sPlotDir, oWave.sPlotSubtitle );
        
        % If the user made changes, log them & update the main table. This will fire off
        % listeners so do the log first
        if bChgd
            for i = 1:numel(cLog)
                oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_CudaTS, cLog{i} );
            end
            oWave.tableCudaGPS = tChg;
        end
    end

    return;
end % PlotCudaGPS
