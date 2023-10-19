function [bOK,cErrMsg] = ValidateRxCfg( tRx, tCh, sCalibDir )
% Validate a copy of the RX config table.
%
% Params:
%   tRx     - copy of cwave::tableRxCfg
%   tCh     - copy of cwave::tableRxCh
%   sCalibDir - calibration dir (oWave.sDir_Calib)
% Returns:
%   bOK     - logical(n,1) for n rows of table. Which are valid.
%   cErrMsg - Text that the caller should uialert or log (as appropriate). If a
%           msg was already displayed, it should be empty even if ~all(bOK).
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% bOK     = true( height( tData ), 1 );
cErrMsg = '';   % default a return value

% tableRxCfg
%     , 'VariableNames', { 'RxName', 'Compass', 'Pitch', 'Roll' ...
%                        , 'SyncTime', 'SyncTag', 'ShiftTime', 'ShiftTag' ...
%                        , 'DriftRate' ...
%                        , 'Latitude', 'Longitude', 'Depth', 'East', 'North' ...
%                        , 'BinFile', 'BinPath' ...
%                        } ...
%     , 'VariableTypes', [{'string'}, repmat({'double'},1,14) ...
%                         , {'string', 'string', 'string'}] ...
%     );
% tableRxCh
%     , 'VariableNames', { 'RxName', 'ChanNo', 'Type' ...
%                        , 'Orient', 'Tilt', ...
%                        , 'DipLen', 'Gain', 'MTOutputOrder' ...
%                        , 'CalibFile' ...
%                        } ...
%     , 'VariableTypes', [{'string','double','string'}, repmat({'double'},1,5), {'string'}] ...
%     );

% Simple checks
try
    bOK = cwave.ChkRxName( tRx.RxName ); assert( all(bOK), 'All site names must be alphanumeric only.' );
    bOK = cwave.FlagDupRxNames( tRx.RxName ); assert( all(bOK), 'Receiver name must be unique.' );
    bOK = between( -360, tRx.Compass, 360 ); assert( all(bOK), 'Invalid Compass value' );
    bOK = between( -90, tRx.Pitch, 90 ); assert( all(bOK), 'Invalid Pitch value' );
    bOK = between( -90, tRx.Roll, 90 ); assert( all(bOK), 'Invalid Roll value' );
    bOK = between( -360, tRx.Longitude, 360 ); assert( all(bOK), 'Invalid Longitude value' );
    bOK = between( -90, tRx.Latitude, 90 ); assert( all(bOK), 'Invalid Latitude value' );
    bOK = tRx.Depth >= 0; assert( all(bOK), 'Invalid Depth value' );
    bOK = tRx.East >= 0; assert( all(bOK), 'Invalid Easting value' );
    bOK = tRx.North >= 0; assert( all(bOK), 'Invalid Northing value' );
    bOK = isfile( fullfile( tRx.BinPath, tRx.BinFile ) ); assert( all(bOK), 'Binary file does not exist.' );
catch Me
    cErrMsg = {Me.message};
    return;
end

% Check the channel list of every receiver
[bFlagNoCh,bFlagFile,bFlagChNo,bFlagMT] = deal(false);
for iRx = 1:height(tRx)
    % Get the channels for this receiver. Every Rx must have at least one
    bChs = strcmpi( tCh.RxName, tRx.RxName(iRx) );
    if ~any(bChs)
        bOK(iRx) = false;
        bFlagNoCh = true;
        continue;
    end
    tTheseCh = sortrows( tCh(bChs,:), 'ChanNo' );
    
    % Must have a calibration file on each valid channel
    cCal = fullfile( sCalibDir, tCh.CalibFile(bChs) );
    if ~all( isfile( cCal ) )
        bOK(iRx) = false;
        bFlagFile = true;
        continue;
    end
    
    % There cannot be duplicate or missing channel numbers
    if any(tTheseCh.ChanNo < 1) || ~isequal( tTheseCh.ChanNo, (1:height(tTheseCh)).' )
        bOK(iRx) = false;
        bFlagChNo = true;
        continue;
    end
        
    % Cannot have duplicate or missing MT output channel ordering
    nMT = tTheseCh.MTOutputOrder;
    nMT(nMT < 1 | isnan(nMT)) = [];
    if ~isempty(nMT)
        nMT = sort(nMT);
        if ~isequal( nMT, (1:numel(nMT)).' )
            bOK(iRx) = false;
            bFlagMT = true;
            continue;
        end
    end
    
end % loop through receivers

% If any of the errors were flagged, put the appropriate messages in the list
% and return
if ~all(bOK)
    if bFlagNoCh
        cErrMsg{end+1,1} = 'Receiver contains no channel data';
    end
    if bFlagChNo
        cErrMsg{end+1,1} = 'Receiver channel numbers are not unique & ascending without gaps';
    end
    if bFlagFile
        cErrMsg{end+1,1} = 'Channel calibration file(s) empty or do not exist';
    end
    if bFlagMT
        cErrMsg{end+1,1} = 'Receiver MT output order is not unique & ascending without gaps';
    end
    return;
end

%% Warnings only below this point

return;
end % ValidateRxCfg
