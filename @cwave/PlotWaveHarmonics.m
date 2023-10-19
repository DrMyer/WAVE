function PlotWaveHarmonics( oWave )
% cwave::PlotWaveHarmonics( oWave )
%
% Public method of the cwave class. Plot the user-selected waveform harmonics
% from either a SNAP-derived or Idealized waveform
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % There can be Ideal and/or SNAP. If both, always use SNAP.
    if ~isempty( oWave.tableWaveSNAP )
        % What's the sampling frequency?
        nSampFreq = 1 ./ median( diff( oWave.tableWaveSNAP.Time ) );
        [nFFT, nFreqList] = calcFFT( oWave.tableWaveSNAP.Amplitude, nSampFreq );
        sPrefix = 'SNAP-derived ';
    else
        % The ideal waveform will be in 'brief' format. Change it to
        % full samples so I can get a proper FFT on it
        [~,nA] = decodeSUESITXTiming( ...
            encodeSUESITXTiming( oWave.tableWaveIdeal.Time * 400 ...
            , oWave.tableWaveIdeal.Amplitude ) ...
            , 'LongForm' );
        [nFFT, nFreqList] = calcFFT( nA, 400 );
        sPrefix = 'Idealized ';
    end
    
    % Get a generic plot figure centered over the main window
    hFig = figCenter( oWave.hFig, 'ppt' );
    
    % Plot the amplitudes
    hAxAmp = subplot( 3, 1, [1 2] );
    stem( hAxAmp, nFreqList, abs( nFFT ), 'Marker', '.' );
    hold( hAxAmp, 'on' );
    plot( hAxAmp, nFreqList(oWave.tableHarmonics.Harmonic) ...
        , abs( nFFT(oWave.tableHarmonics.Harmonic) ) ...
        , 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 12 ...
        , 'Color', 'r', 'HitTest', 'off' );
    hold( hAxAmp, 'off' );
    hAxAmp.XScale = 'log';
    axisTight( hAxAmp, 'x' );
    decadeTick( hAxAmp, 'x' );
    title( hAxAmp, {
        [sPrefix 'Waveform Harmonic Amplitudes']
        oWave.sPlotSubtitle
        } );
    xlabel( hAxAmp, 'Frequency (Hz)' );
    ylabel( hAxAmp, 'Amplitude' );
    
    % Plot the phases
    hAxPhs = subplot( 3, 1, 3 );
    semilogx( hAxPhs, nFreqList, 180 / pi() * angle( nFFT ) ...
        , 'LineStyle', 'none', 'Marker', '.' );
    axisTight( hAxPhs, 'x' );
    decadeTick( hAxPhs, 'x' );
    hAxPhs.YLim  = [-190 190];
    hAxPhs.YTick = -180:90:180;
    title( hAxPhs, 'Waveform Phase' );
    xlabel( hAxPhs, 'Frequency (Hz)' );
    ylabel( hAxPhs, 'Phase (deg)' );
    
    linkaxes( [hAxAmp hAxPhs], 'x' );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'Waveform_Harmonics' ) );
    
    return;
end % PlotWaveHarmonics
