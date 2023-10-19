function [bOK,cErrMsg] = ValidateTxNav( tData, ~, ~ ) % , hUIFig, bQuery )
% Validate a copy of the TX nav table. This table can be created by multiple
% processes or just imported by the user from external code.
%
% Params:
%   tData   - copy of the cwave::tableTxNav
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

% tableTxNav
% , 'VariableNames', { 'Time', 'Altitude', 'Depth', 'COG', 'Dip' ...
%                    , 'Longitude', 'Latitude', 'East', 'North' ...
% Don't bother to validate the other bits & pieces. They're normally created /
% overwritten *during* TxNav
%

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

% Eastings should be positive and at least 6 digits
bOK = tData.East >= 100000;
if ~all( bOK )
    cErrMsg = {'Eastings should be positive and 6 digits (UTM meridian is 500,000).'};
    return;
end

% Northings should be positive and at least 7 digits
bOK = tData.North >= 1000000;
if ~all( bOK )
    cErrMsg = {'Northings should be positive and 7 digits.'};
    return;
end


%% Warnings only below this point

return;
end % ValidateTxNav
