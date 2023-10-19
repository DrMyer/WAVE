function [bOK,cErrMsg] = ValidateSyncTable( tSync, hUIFig, bQuery )
% Validate a copy of the sync table - used primarily with w_panelTable.m and
% UITableEdit.m but may be used elsewhere.
%
% Params:
%   tSync   - copy of the cwave::tableSUESISync
%   hUIFig  - handle of a uifigure for calls to uiconfirm
%   bQuery  - T/F. If T, it's OK to ask questions. If F, validate silently
% Returns:
%   bOK     - logical(n,1) for n rows of table. Which are valid
%   cErrMsg - Text that the caller should uialert or log (as appropriate). If a
%           msg was already displayed, it should be empty even if ~all(bOK).
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% If all are NaT, complain. If only some are NaT and they have just a few lines
% in them each, then the user is ignoring short syncs and we can go on. If some
% are NaT and they have a lot of lines of data, confirm with the user

% Default the return vars
bNaT    = isnat( tSync.SyncTime );
bOK     = true(size(bNaT));
cErrMsg = {};

% Have times been entered? Or is it less than 15 min of S= lines?
if all( bNaT )  % no times entered
    bOK = false(size(bNaT));
    cErrMsg{end+1,1} = 'Enter synchronization date & time values for at least one entry.';
    return; % no reason to do any other checks
end

% Don't allow times to regress in one file. I.e. the time for sync group #2 must
% be > the time for sync #1, etc...
nDiffTime = diff( tSync.SyncTime );
nDiffSync = diff( tSync.SyncNo );
bRegress = (nDiffSync > 0) & (nDiffTime < 0);
if any( bRegress )
    bOK(2:end) = bOK(2:end) & ~bRegress;
    cErrMsg{end+1,1} = 'Sync date & time must INCREASE on subsequent sync numbers in the same file.';
end

% Don't allow there to be time overlaps between different sync sections. This
% occurs when the user has multiple SUESI logs from different sources (on
% Scarborough, we had THREE!). 
%
% NB: It's not common to want to process multiple but sometimes it happens. For
% example, at Scarborough one of the crappy log sources had the GPS but the
% other good sources did not. So I process the crappy to get the sync times then
% apply them to the good and blank out the crappy.
%
% NB: Each sync time range should only be inside the [from,to] of ONE set (its
% own). If it's in more than one set, there is overlap
%
nDuration = seconds( tSync.S_To - tSync.S_From );
nEndTime = tSync.SyncTime + nDuration;
nCntSets = arrayfun( @(dt)sum( isbetween( dt, tSync.SyncTime, nEndTime ) & ~isnat(nEndTime) ), tSync.SyncTime );
if any( nCntSets > 1 )
    bOK = bOK & (nCntSets < 2);
    cErrMsg{end+1,1} = [
        'Sync sections cannot overlap in time. Each must be unique. ' ...
        'If you are importing multiple SUESI logs with the same data, ' ...
        'you must pick one sync set and NaT the overlapping set.' ...
        ];
end

% Don't allow the Sync at S=x value to be outside the [S_From, S_To] range
bOut = ~between( tSync.S_From, tSync.S_Sync, tSync.S_To );
if any( bOut )
    bOK = bOK & ~bOut;
    cErrMsg{end+1,1} = [
        'The S= SUESI second that synchronizes the time for a sync ' ...
        'section must be between the S_From and S_To "S=" range ' ...
        'for that sync section.' ...
        ];
end


%------------------------------------------------------%
% If there are errors, exit now. Below is for warnings %
%------------------------------------------------------%
if ~isempty( cErrMsg )
    return;
end

% Sync sections with less than 15 min of S= lines can often be ignored
bShort = (nDuration < seconds( 900 ) );
bOK = bOK & (bShort | ~bNaT);
if all( bOK | bShort ) % All sync sections longer than X seconds have times assigned
    return;
end

% There are some big groups with no sync times. Confirm
if bQuery
    s = uiconfirm( hUIFig, [
        'Some of the synchronization groups which do NOT have ' ...
        'times assigned to them have more than 15 minutes of ' ...
        'data in them. Do you still want to save & continue?'
        ], 'Is this OK?', 'Options', {'Save', 'Cancel'} ...
        , 'DefaultOption', 2, 'CancelOption', 2 );
else
    s = 'Cancel';
end
if strcmpi( s, 'Save' )
    bOK(:) = true;
end

return;
end % ValidateSyncTable
