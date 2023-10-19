function ParseBarracudaLogs( oWave )
% Parse multiple Barracuda text GPS log files into time series
%
% Params:
%   oWave   - the cwave object with all the data
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    % Get the survey year from the ship time series. Older Barracuda logs have
    % the day-of-year but not the actual year in them. Newer logs have year
    % tacked on.
    if ~isempty( oWave.tableSDM )
        nYr = year( oWave.tableSDM.Time(1) );
    elseif ~isempty( oWave.tableBenthos )
        nYr = year( oWave.tableBenthos.Time(1) );
    else
        uialert( oWave.hFig, 'Process SUESI logs first.', 'Parse Barracuda Logs' );
        return;
    end
    
    % Clear the logs
    oWave.ClearLogOfType( cwave.sLog_TxN_BParse );
    
    % We're completely replacing the existing table so create a new one
    tCuda = cwave.GetDfltFor( 'tableCudaGPS', 0 );
    
    % Show the user some progress & allow cancel
    oProg = uiprogressdlg( oWave.hFig, 'Title', 'Parse Barracuda Logs' ...
        , 'Message', 'Parsing log files...', 'Cancelable', 'on' );
    
    % Process each file in the list
    tStart = tic();
    nCntOK = 0;
    for iFile = 1:numel(oWave.cFiles_TxBLogs)
        % Progress
        if oProg.CancelRequested
            oWave.AddLog( cwave.LogError, cwave.sLog_TxN_BParse, 'User Cancel' );
            break;
        end
        oProg.Value = (iFile - 1) / numel(oWave.cFiles_TxBLogs);
        
        % Does the file exist & can we open it?
        sFile = oWave.cFiles_TxBLogs{iFile};
        if ~isfile( sFile )
            oWave.AddLog( cwave.LogError, cwave.sLog_TxN_BParse ...
                , ['File not found: ' sFile] );
            continue;
        end
        
        % Handle one file
        [bOK,tAdd,cErr,nYr] = decodeBarracudaLog( sFile, nYr ...
            , oWave.sEllipsoid, oWave.nUTMZone, oWave.hFig );
        if bOK && ~isempty( tAdd )
            tCuda   = [tCuda; tAdd];
            nCntOK  = nCntOK + 1;
            oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_BParse ...
                , sprintf( '%d GPS entries for %d unique NAV from: %s' ...
                , height(tAdd), numel(unique(tAdd.DeviceNo)), sFile ) );
        elseif ~isempty( cErr )
            for i = 1:numel(cErr)
                oWave.AddLog( cwave.LogError, cwave.sLog_TxN_BParse ...
                    , ['Error: ' cErr{i} ' from:' sFile] );
            end
        else
            oWave.AddLog( cwave.LogError, cwave.sLog_TxN_BParse ...
                , ['decodeBarracudaLog() returned no data from:' sFile] );
        end
        
    end % loop through log files
    
    % Clear the progress window
    close( oProg );
    
    % Log what we've done
    nDur = seconds( toc(tStart) );
    nDur.Format = 'hh:mm:ss';
    oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_BParse, ['Process time: ' char(nDur)] );
    if nCntOK == 0
        oWave.AddLog( cwave.LogError, cwave.sLog_TxN_BParse, 'No barracuda GPS data obtained.' );
    else
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_BParse ...
            , sprintf( 'Successfully parsed %d of %d files.', nCntOK, numel(oWave.cFiles_TxBLogs) ) );
    end
    
    % Update the internal variables - firing off listeners
    oWave.tableCudaGPS = tCuda;
    
    % Throw up a QC plot. Spurious points will have high dE/dt or dN/dt
    oWave.PlotCudaGPS_QC();
    
    return;
end % ParseBarracudaLogs
