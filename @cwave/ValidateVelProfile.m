function [bOK,cErrMsg] = ValidateVelProfile( tData, ~, ~ ) % hUIFig, bQuery )
% Validate a copy of the velocity-profiles-over-time table - used primarily
% with w_panelTable.m and UITableEdit.m but may be used elsewhere.
%
% Params:
%   tData   - copy of the cwave::tableVProfile.
%   hUIFig  - handle of a uifigure to which to parent uiconfirm
%   bQuery  - T/F. If T, it's OK to ask questions. If F, validate silently.
% Returns:
%   bOK     - logical(n,1) for n rows of table. Which are valid.
%   cErrMsg - Text that the caller should uialert or log (as appropriate). If a
%           msg was already displayed, it should be empty even if ~all(bOK).
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

cErrMsg = '';   % default a return value

% tableVProfile
% {'Name',  'DateFrom','DateTo'}
% {'string','datetime','datetime'}

% Name cannot be empty
bOK = ~ismissing( tData.Name );
if ~all( bOK )
    cErrMsg = {'Velocity profile names cannot be empty.'};
    return;
end

% If only one row, DateFrom/To are not required. If more than one row, then they
% are required.
if numel(bOK) > 1
    bOK = ~isnat( tData.DateFrom ) & ~isnat( tData.DateTo );
    if ~all( bOK )
        cErrMsg = {
            ['The Date from/to entries cannot be NaT when there are ' ...
            'multiple velocity profile entries.']
            ''
            ['Use multiple entries to indicate multiple ships (such as ' ...
            'different ships used on deployment & recovery) and/or drastically ' ...
            'changing water conditions such as a storm during the cruise.']
            ''
            ['If there is only one entry, then the dates can be NaT to ' ...
            'indicate that the one entry works for all Benthos data.']
            };
        return;
    end
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

return;
end % ValidateVelProfile
