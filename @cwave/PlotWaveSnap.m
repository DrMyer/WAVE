function PlotWaveSnap( oWave )
% cwave:PlotWaveSnap( oWave )
%
% Public method of the cwave class. Plot the waveform created from SNAPs
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
    
    plot( hAx, oWave.tableWaveSNAP.Time, oWave.tableWaveSNAP.Amplitude ...
        , 'Marker', 'none', 'LineStyle', '-' );
    
    axisTight( hAx );
    xlabel( hAx, 'Time (s)' );
    ylabel( hAx, 'Normalized Amplitude' );
    title( hAx, {
        'Median Waveform derived from SNAP data'
        oWave.sPlotSubtitle
        } );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'Waveform_SNAP' ) );
    
    return;
end % PlotWaveSnap
