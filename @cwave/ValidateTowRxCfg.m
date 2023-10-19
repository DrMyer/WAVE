function [bOK,cErrMsg] = ValidateTowRxCfg( tRx, tCh, sCalibDir )
% Validate a copy of the TOWED RX config table.
%
% Params:
%   tRx     - copy of cwave::tableTowRxCfg
%   tCh     - copy of cwave::tableTowRxCh
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

% tableTowRxCfg
%     , 'VariableNames', { 'RxName', 'TrailingDist' ...
%                        , 'SyncTime', 'SyncTag', 'ShiftTime', 'ShiftTag' ...
%                        , 'DriftRate' ... 
%                        , 'BinFile', 'BinPath' ... 
%                        } ...
%     , 'VariableTypes', { 'string', 'double' ...
%                        , 'datetime','double','datetime','double' ...
%                        , 'double', 'string', 'string' } ...
%     );
% tableTowRxCh
%     , 'VariableNames', { 'RxName', 'ChanNo', 'Type' ...
%                        , 'Orient', 'Tilt' ... % NB: CountConv comes from readBinFile.m
%                        , 'DipLen', 'Gain' ...
%                        , 'CalibFile' ...
%                        } ...
%     , 'VariableTypes', [{'string','double','string'}, repmat({'double'},1,4), {'string'}] ...
%     );

% Simple checks
try
    bOK = cwave.ChkRxName( tRx.RxName ); assert( all(bOK), 'All site names must be alphanumeric only.' );
    bOK = cwave.FlagDupRxNames( tRx.RxName ); assert( all(bOK), 'Receiver name must be unique.' );
    bOK = isfile( fullfile( tRx.BinPath, tRx.BinFile ) ); assert( all(bOK), 'Binary file does not exist.' );
    bOK = tRx.TrailingDist >= 0; assert( all(bOK), 'Invalid trailing distance.' );
catch Me
    cErrMsg = {Me.message};
    return;
end

% Check the channel list of every receiver
[bFlagNoCh,bFlagFile,bFlagChNo] = deal(false);
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
    return;
end

%% Warnings only below this point

return;
end % ValidateTowRxCfg
