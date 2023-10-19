function Chk_nStackLen( ~, stValues )
% cwave::Chk_nStackLen( oWave, stValues )
%
% Contextual validation of oWave.nStackLen against other variables in the same
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

    % The stack length must be an integer multiple of the FFT window length
    assert( mod( stValues.nStackLen, stValues.nWindowLen ) == 0 ...
        , 'The stack length must be an integer multiple of the FFT window length.' );
    
    return;
end % Chk_nStackLen
