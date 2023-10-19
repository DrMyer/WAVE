function PlotWaveIdeal( oWave )
% cwave:PlotWaveIdeal( oWave )
%
% Public method of the cwave class. Plot the user-created idealized waveform 
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % Get a generic plot figure centered over the main window
    hFig = figCenter( oWave.hFig );
    hAx = gca();
    
    plot( hAx, oWave.tableWaveIdeal.Time, oWave.tableWaveIdeal.Amplitude ...
        , 'Marker', 'none', 'LineStyle', '-' );
    
    axisTight( hAx );
    xlabel( hAx, 'Time (s)' );
    ylabel( hAx, 'Normalized Amplitude' );
    title( hAx, {
        'Idealized Waveform'
        oWave.sPlotSubtitle
        } );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'Waveform_Ideal' ) );
    
    return;
end % PlotWaveIdeal
