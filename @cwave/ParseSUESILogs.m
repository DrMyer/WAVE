function ParseSUESILogs( oWave, sScope )
% Parse multiple SUESI text log files, extracting SNAPs, Valeport info, and the
% source-dipole-moment time series.
%
% Params:
%   oWave   - the cwave object with all the data
%   sScope  - 'New' or 'All' - which log files to process
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% New or All?
% NB: Input & Output names are the same, only the path & file extension differ.
cInList     = oWave.cFiles_SUESIraw;
bProcess    = true( numel( oWave.cFiles_SUESIraw ), 1 );
if strcmpi( sScope, 'New' ) && ~isempty( oWave.cFiles_SUESImat )
    cOutList  = oWave.cFiles_SUESImat;
    cSNAPList = oWave.cFiles_SNAP;
    
    % Strip down to just the filename with no path or extension
    cInFile = cell(size(cInList));
    for iFile = 1:numel( cInList )
        [~,cInFile{iFile}] = fileparts( cInList{iFile} );
    end
    
    % Strip down to just the filename with no path or extension
    cOutFile = cell( size(cOutList) );
    for iFile = 1:numel( cOutList )
        [~,cOutFile{iFile}] = fileparts( cOutList{iFile} );
    end
    
    % Look for cases where the raw suesi file is newer than the processed file
    % or where the processed file doesn't exist.
    bProcess = true(size(cInFile));
    for iFile = 1:numel(cInFile)
        iAt = find( strcmpi( cInFile{iFile}, cOutFile), 1, 'first' );
        if ~isempty( iAt )
            % If the file is already in the output list, see if the input is
            % newer than the output
            stDirIn  = dir( cInList{iFile} );   % use the full path+file
            stDirOut = dir( cOutList{iAt} );    % use the full path+file
            bProcess(iFile) = (stDirIn.datenum > stDirOut.datenum);
        else
            bProcess(iFile) = true;
        end
    end
    if ~any( bProcess )
        uialert( oWave.hFig, { 
            'All of the SUESI logs have been processed.'
            'There are no new logs.'
            ''
            'If you want to reprocess just one log, then'
            'you should delete the .mat file version of'
            'the processed log and press "Run New" again.'
            }, 'Parse SUESI Logs' );
        return;
    end
else
    % For a "Run All", remove all decode items from the log AND clear the output
    % file list since cwave is using the 'AbortSet' property to suppress
    % duplicate listener calls from occurring if a var is set to its current
    % value again.
    oWave.ClearLogOfType( oWave.sLog_S_Decode );
    % NB: listeners for the variables below will cascade changes right now
    oWave.cFiles_SUESImat   = cwave.GetDfltFor( 'cFiles_SUESImat' );
    oWave.cFiles_SNAP       = cwave.GetDfltFor( 'cFiles_SNAP' );
    cOutList  = {};
    cSNAPList = {};
end

% Process each raw log file
for iProc = reshape( find( bProcess ), 1, [] )
    % For consistency, assemble the 'start', 'succeeded', & 'fail' log strings
    sLogStart   = ['START decode of SUESI log: ' cInList{iProc}];
    sLogFail    = ['FAILED decode of SUESI log: ' cInList{iProc}];
    sLogDone    = ['COMPLETED decode of SUESI log: ' cInList{iProc}];
    
    % For a "Run New" remove decode items from the log that fall between the
    % "START ..." and "COMPLETED" or "FAILED" lines for that file so that
    % previous errors are removed.
    if ~strcmpi( sScope, 'All' )
        bRightType = strcmpi( oWave.cLog(:,oWave.colLog.Type), oWave.sLog_S_Decode );
        iFrom = find( bRightType & strcmpi( oWave.cLog(:,oWave.colLog.Desc), sLogStart ) ...
            , 1, 'first' );
        if ~isempty( iFrom )
            iTo = find( bRightType & strcmpi( oWave.cLog(:,oWave.colLog.Desc), sLogFail ) ...
                , 1, 'last' );
            if isempty( iTo )
                iTo = find( bRightType & strcmpi( oWave.cLog(:,oWave.colLog.Desc), sLogDone ) ...
                    , 1, 'last' );
            end
            
            if ~isempty( iTo )
                oWave.cLog(iFrom:iTo,:) = [];
            end
        end
    end
    
    % Log that we're starting work
    oWave.AddLog( oWave.LogOK, oWave.sLog_S_Decode, sLogStart );
    tStart = tic();
    
    % Is this actually a SUESI log file? If not, log & continue
    if ~isFile_SUESILog( cInList{iProc} )
        oWave.AddLog( oWave.LogError, oWave.sLog_S_Decode, 'Failed isFile_SUESILog() check' );
        oWave.AddLog( oWave.LogError, oWave.sLog_S_Decode, sLogFail );
        continue;
    end
    
    % Decode the log
    [bOK,cWarn,cErr,sOutParsed,sOutSNAP,sOutLog,nLineCnt] = decodeSUESI( ...
          cInList{iProc} ...
        , oWave.sSuesiDir ...
        , 'CaptureLog' ...
        , oWave.sLogDir ...
        , oWave.hFig );
    
    % Catalog any warnings & errors in the cwave log
    for iMsg = 1:numel(cErr)
        oWave.AddLog( oWave.LogError, oWave.sLog_S_Decode, cErr{iMsg} );
    end
    % NB: Don't log the warnings. Just tell the user they can look at the dump
    % log to see the details. Most of these are harmless character errors in the
    % SUESI stream
    if numel(cWarn) > 1
        oWave.AddLog( oWave.LogWarn, oWave.sLog_S_Decode ...
            , sprintf( '%d warnings saved in the dump log.', numel(cWarn) ) );
    end
    
    % Record final disposition from the decode
    nDur = seconds( toc(tStart) );
    nDur.Format = 'hh:mm:ss';
    oWave.AddLog( cwave.LogOK, cwave.sLog_S_Decode, ['Process time: ' char(nDur)] );
    if bOK
        oWave.AddLog( oWave.LogOK, oWave.sLog_S_Decode, ['--> Output: ' sOutParsed] );
        cOutList{end+1}  = sOutParsed;
        
        if isempty( sOutSNAP )
            oWave.AddLog( oWave.LogOK, oWave.sLog_S_Decode, '--> SNAP: None' );
        else
            oWave.AddLog( oWave.LogOK, oWave.sLog_S_Decode, ['--> SNAP: ' sOutSNAP] );
            cSNAPList{end+1} = sOutSNAP;
        end
        
        oWave.AddLog( oWave.LogOK, oWave.sLog_S_Decode, ['--> Text Log: ' sOutLog] );
        oWave.AddLog( oWave.LogOK, oWave.sLog_S_Decode, ['--> Lines processed: ' num2str(nLineCnt)] );
        oWave.AddLog( oWave.LogOK, oWave.sLog_S_Decode, sLogDone );
    else
        oWave.AddLog( oWave.LogError, oWave.sLog_S_Decode, sLogFail );
    end
    
end % loop over files to be processed

% Update the processed file & SNAP file lists - this will trigger listeners
oWave.cFiles_SUESImat   = reshape( unique( cOutList ), [], 1 );
oWave.cFiles_SNAP       = reshape( unique( cSNAPList ), [], 1 );

return;
end % ParseSUESILogs
