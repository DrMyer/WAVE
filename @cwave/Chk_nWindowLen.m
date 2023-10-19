function Chk_nWindowLen( oWave, stValues )
% cwave::Chk_nWindowLen( oWave )
%
% Contextual validation of oWave.nWindowLen against other variables in the same
% UIEditVars window and other oWave data.
%
% Parameters:
%   oWave - the controlling cwave instance
%   stValues - structure containing stValues.(variable) references to the
%           current values of variables in the UIEditVars window. If called from
%           w_panelInput, then it's another copy of oWave
% Returns:
%   <nothing> Errors are thrown out to a try/catch
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % The FFT window length must be an integer multiple of the length of the
    % waveform. 
    if ~isempty( oWave.tableHarmonics )
        nWaveLen = oWave.tableHarmonics.Harmonic(1) / oWave.tableHarmonics.Frequency(1);
    
    % Prefer snap over ideal waveforms
    elseif ~isempty( oWave.tableWaveSNAP )
        % Assume uniform time steps
        nTmStep  = diff( oWave.tableWaveSNAP.Time(1:2) );
        nWaveLen = height( oWave.tableWaveSNAP ) * nTmStep;
        
    elseif ~isempty( oWave.tableWaveIdeal )
        nT = decodeSUESITXTiming( ...
             encodeSUESITXTiming( oWave.tableWaveIdeal.Time * 400 ...
                                , oWave.tableWaveIdeal.Amplitude ) ...
            , 'LongForm' );
        nWaveLen = numel(nT) / 400; % SUESI is always at 400 Hz
    else
        % no waveform information. Cannot validate
        return;
    end
    
    % Use round to deal with floating point inaccuracies
    assert( mod( stValues.nWindowLen, round( nWaveLen, 2 ) ) == 0 ...
        , 'The FFT window length must be an integer multiple of the waveform length (%ss).', nWaveLen );
    
    return;
end % Chk_nWindowLen
