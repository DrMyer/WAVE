function [bOK,cErrMsg] = ValidateTowTimes( tData, hUIFig, bQuery )
% Validate a copy of the Tow times & time lag table - used primarily
% with w_panelTable.m and UITableEdit.m but may be used elsewhere.
%
% Params:
%   tData   - copy of the cwave::tableTow.
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

% Tow numbers must be unique
[c,~,ic] = unique(tData.TowNo);
if numel(c) ~= height(tData)
    % Flag the copies
    nCnt    = accumarray( ic, ones(size(ic)) );
    bOK     = (nCnt(ic) == 1);
    cErrMsg = {'Tow number must be unique.'};
    return;
end

% TX Tag time cannot be NaN
bOK = ~isnan( tData.Lag );
if any(~bOK)
    cErrMsg = {'Transmitter time lag cannot be NaN. Use SUESI tag from logbook.'};
    return;
end

% Phase Shift cannot be NaN
bOK = ~isnan( tData.PhaseShift );
if any(~bOK)
    cErrMsg = {'Transmitter phase shift cannot be NaN. Use 180 to flip polarity.'};
    return;
end

% WireOutTare cannot be NaN
bOK = ~isnan( tData.WireOutTare );
if any(~bOK)
    cErrMsg = {'Wire-out Tare value cannot be NaN. Zero or a few meters are typical.'};
    return;
end

% IgnoreNav flag must be either 0 or 1 (NB: s/b logical but missing() doesn't
% support that type)
bOK = tData.IgnoreNav == 0 | tData.IgnoreNav == 1;
if any(~bOK)
    cErrMsg = {'"Ignore Nav" flag must be either 0 or 1(= use layback in shiptrack)'};
    return;
end

% The smoothing window length must be either NaN(= search for one) or a positive
% number in seconds
bOK = isnan( tData.SmoothSec ) | tData.SmoothSec > 1;
if any(~bOK)
    cErrMsg = {'Nav smoothing window must be either NaN(=solve) or +ve seconds'};
    return;
end

% Tow dates cannot overlap
for iRow = 2:height( tData )
    for iUp = iRow-1:-1:1
        bOverlap = ~( ...
               ( tData.DateFrom(iRow) < tData.DateFrom(iUp) ...
              && tData.DateTo(iRow)  <= tData.DateFrom(iUp)) ...
            || ( tData.DateFrom(iRow)>= tData.DateTo(iUp) ...
              && tData.DateTo(iRow)   > tData.DateTo(iUp)) ...
              );
        if bOverlap
            break;
        end
    end
    if bOverlap
        bOK(iRow) = false;
    end
end
if ~all( bOK )
    cErrMsg = {'From/To dates cannot overlap for multiple entries.'};
    return;
end

%---------------------------------%
% WARNINGS only, below this point %
%---------------------------------%

% Transmitter lag should be entered in seconds, not milliseconds. Make sure it
% looks correct
bWarn = (tData.Lag >= 1.0);
if ~any( bWarn )
    return;
end
if bQuery
    s = uiconfirm( hUIFig, {
        'The transmitter lag time should be entered in seconds not milliseconds.'
        'Lag times >= 1.0 are unusual.'
        ''
        'Are you sure you entered the correct values?'
        }, 'Is this OK?', 'Options', {'Yes', 'No'} ...
        , 'DefaultOption', 2, 'CancelOption', 2 );
else
    s = 'No';
end
if strcmpi( s, 'No' )   % if not OK, turn warnings into errors
    bOK = ~bWarn;
    % NB: don't set cErrMsg on warnings
end

return;
end % ValidateTowTimes
