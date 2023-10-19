function [bOK,cErrMsg] = ValidateRxNav( tData, ~, ~ ) % , hUIFig, bQuery )
% Validate a copy of the RX nav table. Normally this table is created by RxNav.m
% but I allow the user to tweak the table. Minimal validation ensures nothing is
% completely crazy
%
% Params:
%   tData   - copy of the cwave::tableRxNav
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

% tableRxNav
% {'RxName','DucerFreq','Latitude','Longitude', 'East','North','Depth' ...
% , 'East_Std','North_Std','Depth_Std','RMS' ...
% , 'XY_Phi', 'XY_Major', 'XY_Minor' ...      % error ellipses
% , 'XZ_Phi', 'XZ_Major', 'XZ_Minor' ...      % error ellipses
% , 'YZ_Phi', 'YZ_Major', 'YZ_Minor' ...      % error ellipses
% , 'Drop_Lat','Drop_Lon','Drop_East','Drop_North','Drop_Depth'} ...
% [{'string','double','double','string'}, repmat({'double'},1,23)] ...

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
bOK = abs( tData.Drop_Lat ) <= 90;
if ~all( bOK )
    cErrMsg = {'Drop Latitude cannot be > 90 degrees.'};
    return;
end

% abs(Longitude) <= 360
bOK = abs( tData.Longitude ) <= 360;
if ~all( bOK )
    cErrMsg = {'Longitude cannot be > 360 degrees.'};
    return;
end
bOK = abs( tData.Drop_Lon ) <= 360;
if ~all( bOK )
    cErrMsg = {'Drop Longitude cannot be > 360 degrees.'};
    return;
end

% Depth must be >= 0 (+ve down)
bOK = tData.Depth >= 0;
if ~all( bOK )
    cErrMsg = {'Depth must be >= 0. (i.e. z is positive DOWN.)'};
    return;
end

% Eastings should be positive and 6 digits
bOK = tData.East >= 100000;
if ~all( bOK )
    cErrMsg = {'Eastings should be positive and 6 digits (UTM meridian is 500,000).'};
    return;
end
bOK = tData.Drop_East >= 100000;
if ~all( bOK )
    cErrMsg = {'Drop Eastings should be positive and 6 digits (UTM meridian is 500,000).'};
    return;
end

% Northings should be positive and 7 digits
bOK = tData.North >= 1000000;
if ~all( bOK )
    cErrMsg = {'Northings should be positive and 7 digits.'};
    return;
end
bOK = tData.Drop_North >= 1000000;
if ~all( bOK )
    cErrMsg = {'Drop Northings should be positive and 7 digits.'};
    return;
end

% All std must be positive
bOK = tData.East_Std > 0 & tData.North_Std > 0 & tData.Depth_Std > 0;
if ~all( bOK )
    cErrMsg = {'All standard deviations must be positive.'};
    return;
end

% All ellipse parameters must be positive
bOK = tData.XY_Major > 0 & tData.XY_Minor > 0 ...
    & tData.XZ_Major > 0 & tData.XZ_Minor > 0 ...
    & tData.YZ_Major > 0 & tData.YZ_Minor > 0;
if ~all( bOK )
    cErrMsg = {'All ellipse parameters must be positive'};
    return;
end


%% Warnings only below this point

return;
end % ValidateRxNav
