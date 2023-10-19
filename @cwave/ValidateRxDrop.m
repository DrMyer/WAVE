function [bOK,cErrMsg] = ValidateRxDrop( tData, hUIFig, bQuery )
% Validate a copy of the RX Drop location & frequency table - used primarily
% with w_panelTable.m and UITableEdit.m but may be used elsewhere.
%
% Params:
%   tData   - copy of the cwave::tableRxDrop.
%   hUIFig  - handle of a uifigure to which to parent uiconfirm
%   bQuery  - T/F. If T, it's OK to ask questions. If F, validate silently.
% Returns:
%   bOK     - logical(n,1) for n rows of table. Which are valid.
%   cErrMsg - Text that the caller should uialert or log (as appropriate). If a
%           msg was already displayed, it should be empty even if ~all(bOK).
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% bOK     = true( height( tData ), 1 );
cErrMsg = '';   % default a return value

% tableRxDrop
% {'RxName','Latitude','Longitude','Depth','DucerFreq'} ...
% {'string', 'double', 'double','double','double'} ...

% Name cannot be empty, contain spaces, or invalid filename characters
bOK = cwave.ChkRxName( tData.RxName );
if ~all( bOK )
    cErrMsg = {'All site names must be alphanumeric only.'};
    return;
end

% Name must be unique
bOK = cwave.FlagDupRxNames( tData.RxName );
if ~all(bOK)
    cErrMsg = {'Receiver name must be unique.'};
    return;
end

% abs(Latitude) <= 90
bOK = abs( tData.Latitude ) <= 90;
if ~all( bOK )
    cErrMsg = {'Latitude cannot be > 90 degrees.'};
    return;
end

% abs(Longitude) <= 360
bOK = abs( tData.Longitude ) <= 360;
if ~all( bOK )
    cErrMsg = {'Longitude cannot be > 360 degrees.'};
    return;
end

% Depth must be >= 0 (+ve down)
bOK = tData.Depth >= 0;
if ~all( bOK )
    cErrMsg = {'Depth must be >= 0. (i.e. z is positive DOWN.)'};
    return;
end

% DucerFreq should be be positive and one of (5 : 0.5 : 15). We allow it to be
% empty in the case of Import but warn 
bWarn = ~between( 5, tData.DucerFreq, 15 );
if ~any( bWarn )    % all is well. Return now
    return;
end
if bQuery
    s = uiconfirm( hUIFig, [
        'The pinger frequency is not set or is outside ' ...
        'the usual values. Is this OK?'
        ], 'Is this OK?', 'Options', {'Yes', 'No'} ...
        , 'DefaultOption', 2, 'CancelOption', 2 );
else
    s = 'No';
    cErrMsg = {'Reply frequencies must be between 5 & 15'};
end
if ~strcmpi( s, 'yes' )
    bOK = ~bWarn;
end

return;
end % ValidateRxDrop
