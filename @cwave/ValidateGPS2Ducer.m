function [bOK,cErrMsg] = ValidateGPS2Ducer( tData, hUIFig, bQuery )
% Validate a copy of the GPS-to-transducer offset table - used primarily with
% w_panelTable.m and UITableEdit.m but may be used elsewhere.
%
% Params:
%   tData   - copy of the cwave::tableGPS2Ducer.
%   hUIFig  - handle of a uifigure to which to parent uiconfirm
%   bQuery  - T/F. If T, it's OK to ask questions. If F, validate silently.
% Returns:
%   bOK     - logical(n,1) for n rows of table. Which are valid.
%   cErrMsg - Text that the caller should uialert or log (as appropriate). If a
%           msg was already displayed, it should be empty even if ~all(bOK).
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

bOK     = true( height( tData ), 1 );
cErrMsg = '';   % default a return value

% tableGPS2Ducer
% {'Name','North_Offset','East_Offset','Depth_Below_Sea','DateFrom','DateTo','Desc'} ...
% {'string', 'double',     'double',   'double',       'datetime', 'datetime', 'string'} ...

% If only one row, DateFrom/To are not required. If more than one row, then they
% are required.
if numel(bOK) > 1
    bOK = ~isnat( tData.DateFrom ) & ~isnat( tData.DateTo );
    if ~all( bOK )
        cErrMsg = {
            ['The Date from/to entries cannot be NaT when there are ' ...
            'multiple GPS-to-Transducer entries.']
            ''
            ['Use multiple entries to indicate multiple ships (such as ' ...
            'different ships used on deployment & recovery) and/or multiple ' ...
            'transducer locations (such as if different transducers on the ' ...
            'ship''s hull are used or a temporary is lashed to the side.)']
            ''
            ['If there is only one entry, then the dates can be NaT to ' ...
            'indicate that the one entry works for all Benthos data.']
            };
        return;
    end
end

% Depth must be >= 0
bOK = (tData.Depth_Below_Sea >= 0);
if ~all( bOK )
    cErrMsg = {'The depth below sealevel for each tranducer must be >= 0.'};
    return;
end

% Date/times cannot overlap (though it's OK if their ends align)
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

% If abs(N,E offsets) > 40m, warn that they look too long
%
% If depth > 20m, warn
%
bWarn = abs( tData.North_Offset ) > 40 | abs( tData.East_Offset ) > 40 ...
      | tData.Depth_Below_Sea > 20;
if ~any( bWarn )
    return;
end
if bQuery
    s = uiconfirm( hUIFig, {
        ['North and/or East offsets of > 40 meters between the ' ...
        'GPS mast and the transducer are unusual.']
        ''
        'Transducer depths > 20 meters are unusual.'
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
end % ValidateGPS2Ducer
