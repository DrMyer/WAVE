function [bOK,sErrMsg] = ValidateAtmPTable( tData, hUIFig, bQuery )
% Validate a copy of the avg'd atmospheric pressure table - used primarily with
% w_panelTable.m and UITableEdit.m but may be used elsewhere.
%
% Params:
%   tData   - copy of the cwave::tableAtmPres.
%   hUIFig  - handle of a uifigure to which to parent uiconfirm
%   bQuery  - T/F. If T, it's OK to ask questions. If F, validate silently.
% Returns:
%   bOK     - logical(n,1) for n rows of table. Which are valid.
%   sErrMsg - Text that the caller should uialert or log (as appropriate). If a
%           msg was already displayed, it should be empty even if ~all(bOK).
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

sErrMsg = '';   % default a return value

% All the dates must be valid
bOK = ~isnat(tData.Date);
if ~all( bOK )
    sErrMsg = 'Dates must be valid.';
    return;
end

% No Mean value may be zero, negative, or empty
bOK = (tData.Mean > 0);
if ~all( bOK )      % got some invalid entries
    sErrMsg = 'The average atmospheric pressure values must be > 0.';
    return;
end
bWarn = (tData.Mean < 900); % did they get the units right?
if ~any( bWarn )    % all is well
    return;
end

% Some of the values are kinda low. Confirm
if bQuery
    s = uiconfirm( hUIFig, [
        'Some of the average atmospheric values look rather low. ' ...
        'These values should be entered in millibars so a typical ' ...
        'value would be 1000. Are you sure you entered the values ' ...
        'in the correct units?'
        ], 'Is this OK?', 'Options', {'Yes', 'No'} ...
        , 'DefaultOption', 2, 'CancelOption', 2 );
else
    s = 'No';
end
if ~strcmpi( s, 'yes' )
    bOK = ~bWarn;
end
return;
end % ValidateAtmPTable
