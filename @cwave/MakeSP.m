function MakeSP( oWave )
% Create .sp files for external MT processing from the nodal RX config info
%
% Params:
%   oWave   - the cwave object with all the data
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    % Are there any nodal CSEM sites to make SP files for?
    if isempty( oWave.tableRxCfg )
        uialert( oWave.hFig, {
            'There are no nodal receivers in the configuration list.'
            }, 'Make SP Files' );
        return;
    end
    
    % Get rid of old log entries
    oWave.ClearLogOfType( cwave.sLog_Nodal_MakeSP );
    
    % Where are these files going?
    sPath = oWave.sSPDir();
    
    % Only process sites whose configuration is complete. This allows the user
    % to process CSEM as data are recovered from the seafloor then just re-run
    % every time they recover more sites
    bOK = cwave.ValidateRxCfg( oWave.tableRxCfg, oWave.tableRxCh, oWave.sDir_Calib );
    
    % Walk the list and make an SP for each one in the proper folder
    cErr = {};
    nCntOK = 0;
    nSkip  = 0;
    oProg = uiprogressdlg( oWave.hFig, 'Title', 'Make SP files' );
    for iRx = 1:height( oWave.tableRxCfg )
        if ~bOK(iRx)
            nSkip = nSkip + 1;
            continue;
        end
        
        % Get the channel info for this receiver
        tCh = oWave.tableRxCh(strcmpi(oWave.tableRxCh.RxName,oWave.tableRxCfg.RxName(iRx)),:);
        
        % NB: The .sp file names are expected to match the binary file names in
        % MT processing...
        [~,sOut] = fileparts( oWave.tableRxCfg.BinFile(iRx) ); % strip off extension
        sFile = [char(sOut) '.sp'];
        sOut = fullfile( sPath, sFile );
        
        % Update progress with the output name
        oProg.Value = (iRx-1) / height( oWave.tableRxCfg );
        oProg.Message = sFile;
        
        % Get the binary file's header for needed info
        try
            stData = readBinData( fullfile( oWave.tableRxCfg.BinPath(iRx), oWave.tableRxCfg.BinFile(iRx) ) );
        catch Me
            cErr{end+1,1} = sprintf( '%s: error %s', oWave.tableRxCfg.RxName(iRx) ...
                , Me.message );
            continue;
        end
        
        % Create the output file
        fid = fopen( sOut, 'w' );
        
        % The SP file is a FIXED FORMAT file. Ordering is critical.
        fprintf( fid, '%-25s : Site name\n', oWave.tableRxCfg.RxName(iRx) );
        fprintf( fid, '%-8.4f %-16.4f : Lat, Lon (decimal)\n' ...
            , oWave.tableRxCfg.Latitude(iRx), oWave.tableRxCfg.Longitude(iRx) );
        fprintf( fid, '%-25.4f : Geomagnetic declination\n', 0 );
        fprintf( fid, '%-25d : Number of channels\n', height(tCh) );
        fprintf( fid, '%-25.8f : Sample rate in seconds\n', 1 ./ stData.nFreq );
        fprintf( fid, '0  %-22.8f : Clock offset and linear drift\n' ...
            , oWave.tableRxCfg.DriftRate(iRx) );
        
        % Channel specific info
        nMTOut = [];
        for iCh = 1:height(tCh)
            if tCh.MTOutputOrder(iCh) > 0
                nMTOut(tCh.MTOutputOrder(iCh)) = iCh;
            end
            fprintf( fid, '%-25s : Channel Type\n' ...
                , tCh.Type(iCh) );
            if strncmpi( tCh.Type(iCh), 'H', 1 )
                fprintf( fid, '%-6.1f %-18.1f : Orientation and tilt\n' ...
                    , tCh.Orient(iCh), tCh.Tilt(iCh) );
            else
                % NB: Egbert's MT requires length in km
                s = sprintf( '%g %6.1f %5.1f %g' ...
                    , tCh.DipLen(iCh) / 1000, tCh.Orient(iCh), tCh.Tilt(iCh), tCh.Gain(iCh) );
                if length(s) < 25
                    s = [s repmat(' ',1,25-length(s))];
                end
                fprintf( fid, [s ' : Dipole len (km), Orientation, tilt, amp gain\n'] );
            end
            s = sprintf( '%.7g 1', stData.nCntConv );
            if length(s) < 25
                s = [s repmat(' ',1,25-length(s))];
            end
            fprintf( fid, [s ' : A/D count conversion (V/count), # filter corrections\n'] );
            fprintf( fid, 'AP                        : Filter type, AP = ampl and phase\n' );
            fprintf( fid, '''%s''\n', tCh.CalibFile(iCh) );
        end
        
        % Output ordering (for MT)
        if ~isempty( nMTOut )
            fprintf( fid, '%-25d : dnff output channel ordering\n' ...
                , numel(nMTOut) );
            fprintf( fid, '%d ', nMTOut );
            fprintf( fid, [repmat(' ', 1, 26-numel(nMTOut)*2) ': channels to output\n'] );
        end
        
        fclose(fid);
        nCntOK = nCntOK + 1;
        
    end % loop over receivers
    close( oProg );
    
    % Log any errors
    if ~isempty( cErr )
        for i = 1:numel(cErr)
            oWave.AddLog( cwave.LogError, cwave.sLog_Nodal_MakeSP, cErr{i} );
        end
    end
    
    % Let the user know we're done
    sMsg = sprintf( 'Created %d .sp files in %s', nCntOK, sPath );
    oWave.AddLog( cwave.LogOK, cwave.sLog_Nodal_MakeSP, sMsg );
    if nSkip > 0
        sMsg = {sMsg};
        sMsg{2} = sprintf( '%d RXs skipped because of incomplete setup.', nSkip );
        oWave.AddLog( cwave.LogWarn, cwave.sLog_Nodal_MakeSP, sMsg{2} );
    end
    
    if isempty( cErr )
        uialert( oWave.hFig, sMsg, 'Make SP Files', 'Icon', 'success' );
    else
        if numel(cErr) > 5
            cErr(4:end) = [];
            cErr{5} = '... etc ... (See log)';
        end
        uialert( oWave.hFig, [
            {sMsg;''}
            cErr
            ], 'Make SP Files', 'Icon', 'warning' );
    end
    
    return;
end % MakeSP
