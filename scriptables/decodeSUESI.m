function [bOK,cWarn,cErr,sOutParsed,sOutSNAP,sOutLog,nFileLine] = decodeSUESI( sFileIn, sPathOut, bCaptureLog, sLogPath, hUIfig )
% [bOK,cWarn,cErr,sOutParsed,sOutSNAP,sOutLog,nLineCnt] = decodeSUESI( sFileIn, sPathOut, bCaptureLog, sLogPath, hUIfig )
%
% Parse a SUESI raw text log file and create multiple output files in the given
% destination folder for: parsed suesi, snap, log.
%
% This code is based on parseSuesiLog.m which I wrote in 2006 and had some
% additions & corrections from Kerry Key, Brent Wheelock, & Karen Weitemeyer.
% I've rewritten / repackaged the code to remove some extraneous bullshit (never
% used) and make it work for both inside the new WAVE workbench GUI and as an
% external scripting tool for people who think GUIs are doomed to fail in EM
% world (looking at you, Peter).
%
% This code supercedes parseSuesiLog.m which is no longer being maintained.
%
% Params:
%   sFileIn - path+file of the raw text SUESI log file to parse
%   sPathOut - path to write the output files. The following files will be
%           created with the input file's name but with suffixes:
%               <>.mat  - ALL SUESI parsed data, sync'd & unsync'd
%               <>_SNAP.mat - all snaps found in the log
%   bCaptureLog - (opt; dflt true) true/false or text 'CaptureLog' to indicate
%           if the output should be streamed to the command window (false) or
%           captured in a text log file (true). If you provide a char input for
%           this parameter, only the first letter is examine. 'C' = true
%   sLogPath - (opt; dflt sPathOut) if bCaptureLog, creates text output log:
%               <>_Log.txt - text output log 
%   hUIfig - (opt; dflt []) if given, MUST be a uifigure. uiprogressdlg()
%            is used on top of hUIfig to show progress. If [] then waitbar() 
%            is used on top of whatever gcf() is.
%
% Returns:
%   bOK     - T/F did the process succeed?
%   cWarn   - cell array of warning texts generated
%   cErr    - ditto for errors
%   sOutParsed,sOutSNAP,sOutLog - path+filename to the 3 outputs created
%   nLineCnt - # of lines in the input file
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer
%
% This program is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, version 3. This program is distributed in the hope that it will be
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. To view the GNU General
% Public License see <https://www.gnu.org/licenses/>
%-------------------------------------------------------------------------------

% Handle optional input parameters
if ~exist( 'bCaptureLog', 'var' ) || isempty( bCaptureLog )
    bCaptureLog = true;
elseif ischar( bCaptureLog )
    bCaptureLog = strncmpi( bCaptureLog, 'C', 1 );
end
if ~exist( 'hUIfig', 'var' ) || isempty( hUIfig )
    hUIfig = NaN;
end

% Default the return vars so an early return doesn't crash
bOK     = true;         % Go ahead. Be an optimist. Try it. I promise it'll all be OK... eventually.
cWarn   = cell(0,1);
cErr    = cell(0,1);

% Create the output filenames
[sPathIn,sFile] = fileparts( sFileIn );
sOutParsed = fullfile( sPathOut, [sFile '.mat'] );
sOutSNAP = fullfile( sPathOut, [sFile '_SNAP.mat'] );
if bCaptureLog
    sOutLog = fullfile( sLogPath, [sFile '_Log.txt'] );
else
    sOutLog = '';
end

% For fatal errors
oProg   = [];
fidLog  = 0;
try
    % Set up the log capture or use stdout
    if bCaptureLog
        [fidLog,sErr] = fopen( sOutLog, 'w' );
        if fidLog < 0
            error( 'Failed to open output log in path "%s": %s', sPathOut, sErr );
        end
    else
        fidLog = 1; % MatLab reserves 0=stdin, 1=stdout, 2=stderr
    end
    fprintf( fidLog, 'decodeSUESI - Started by %s on %s\n', dm_User, datestr( now() ) );
    fprintf( fidLog, '\nFile: %s\n', sFileIn );
    fprintf( fidLog, 'Output folder: %s\n', sPathOut );
    
    % Create the progress bar
    if ishandle( hUIfig )
        oProg = uiprogressdlg( hUIfig, 'Title', 'Parse SUESI Log' ...
            , 'Message', {sFile;sPathIn}, 'Cancelable', true );
    else
        oProg = figCenter( 0, waitbar( 0, sFileIn, 'Name', 'Parse SUESI Log' ) );
    end
    
    % Read the entire file in one go - this is way faster than using fgetl().
    % NB: Do NOT skip empty lines. Errors reference the line# in the file so I
    % need it to be accurate
    sLns = readlines( sFileIn, 'WhitespaceRule', 'trim', 'EmptyLineRule', 'read' );
    
    % Gain Based Delay Correction, from Page 12 in Benthos' DS-7000 manual.
    % Thanks to Kerry Key for finding this (6/2010).
    %
    % Corrections for gains 1-9,in seconds:
    nGainCorrection = [8.74 8.74 8.74 7.58 6.70 5.99 5.46 5.23 4.66] / 1000;
    
    % Benthos (pings from SUESI to Barracudas & TETs) & Vulcan data are
    % different from the other data reported in this log in that there can be
    % MANY "B=..." or "W=..." lines within a single S= block. Everything else
    % reports one per S=. So do Benthos & Vulcan data as their own tables. I use
    % tables because they make code easier to read and are clearer when you're
    % hand-editing .mat files. I didn't use a table for SUESI's data for 
    % historical reasons.
    %
    % NB: stashing data into a table() one row at a time is achingly slow in
    % MatLab, even if the rows have been pre-allocated (I'm guessing it's
    % because of the data type validation checks). So put the data into a
    % standard matrix then convert it at the end
    %
    nDataB = NaN(10000,7);
    colB = colstruct( 'FileLine', 'SuesiSec', 'PingNo', 'PingFreq', 'ReplyCh', 'ReplyFreq', 'ReplyTWTT' );
    iNextB      = 1;
    nLastPingHz = NaN;
    nPingNo     = 0;
    
    nDataV = NaN(10000,6);
    colV = colstruct( 'Time', 'DeviceNo', 'Heading', 'Pitch', 'Roll', 'Pressure' );
    iNextV = 1;
    
    % Transmitter timings go into a table which WAVE will use to get the default
    % idealized waveform for this survey
    tblWaveForm = table( 'Size', [0 3] ...
            , 'VariableNames', {'FileLine', 'SuesiSec', 'Timing'} ...
            , 'VariableTypes', {'double', 'double', 'string'} ...
            );
    
    % Init variables
    col = colstruct( ...
        'FileLine' ... APPROX source line in the log file - may be many lines rolled up together
        , 'Sync' ... is SUESI sync'd to GPS for this data line?
        , 'SuesiSec', 'Alt' ... SUESI seconds (S=) & altimeter (A=) (good to <= 200m)
        , 'ValeSpeed', 'ValePres', 'ValeTemp', 'ValeCond' ... V= Valeport data
        , 'Tilt1', 'Tilt2', 'Heading', 'CompassTemp' ... C= internal compass
        , 'Amp1', 'Amp2', 'Amp3', 'Amp4' ... O= output amps (3 <new> or 4 <old> cols)
        , 'Yr', 'Mo', 'Day', 'Hr', 'Min', 'Sec' ... from w= and/or $G gps reporting
        , 'ShipLat', 'ShipLon', 'GPSMastHt' ... from $G ship GPS reporting (rarely used since 2010)
        ... IGNORING T= lines, not useful, ... T= temperatures (10 <new> or 12 <old> cols)
        );
    
    % Consider "data" to be everything EXCEPT S= and $G date/time stuff
    cols_Data = col.Alt:col.Amp4;
    
    % Pre-allocate a large block of data to make the process fast. realloc() can
    % be very time consuming as the block gets larger. (200k rows ~ 50 Mb)
    %-----------------------------
    % NB: If your log file starts SYNCd, then edit THAT FILE & put a sync line
    % at the top to indicate so. Do NOT edit this code and change bSync!
    bSync       = false;    % ASSUME file always starts NOT sync'd. 
    %-----------------------------
    nData       = NaN( 200000, numel(fieldnames(col)) );
    nCurRow     = 1;
    nRow        = nData(1,:); % working space. Added to nData when filled up
    cSnapList   = {};
    bNextIsSnap = false;
    nLastS      = 0;
    nLastPct    = 0;
    for nFileLine = 1:numel(sLns)
        % Report progress every percentage
        nPct = floor( nFileLine / numel(sLns) * 100 );
        if nPct > nLastPct
            nLastPct = nPct;
            if ishandle( hUIfig )   % uiprogressdlg
                oProg.Value = nPct / 100;
            else                    % waitbar
                waitbar( nPct / 100, oProg );
            end
            
            % Has the user canceled?
            % NB: Only check occasionally. It's a time-expensive operation
            if ishandle( hUIfig )       % uiprogressdlg
                if oProg.CancelRequested
                    error( 'User Canceled!' );
                end
            else                        % waitbar
                if ~ishandle( oProg )   % user closed the progress window = cancel
                    error( 'User Canceled!' );
                end
            end
        end
        
        % Read a line & update the line #. This is the ONLY PLACE where data is
        % read from the text file so that the line # can be kept correct.
        s = char(sLns(nFileLine));  % pre-trimmed of spaces
        if isempty(s)
%             % NB: Blank lines always separate groups of data spewed out by
%             % SUESI. If there's GPS (not usually the case since 2010) it's
%             % advantageous to recognize the blank line and force the buffer into
%             % the datablock.
%             sub_KickOutLine( cols_Data );
% No. Fouls up reporting of SUESI events like GPS sync state
            continue;
        end
        if s(1) == 0    % June 2009 - getting blocks of NULLs in some logs
            continue;
        end
        if length(s) < 2 || (length(s) == 2 && s(2) == '=')
            continue;   % June 2009 - found empty C= lines in Scarborough log
        end
        if bNextIsSnap
            % 2009 Sometimes SNAP data gets started at the end of the "snap
            % complete" notification & loses "this is snap data" indicator for
            % the next output row.
            cSnapList{end+1} = s;
            bNextIsSnap = false;
            continue;
        end
        
        %--------------------------------------------% YES, that's really old.
        % Example of standard set of lines from 2006 % So am I.
        %--------------------------------------------% Shut up.
        % 2006 184 22 30 55 2 4 1 18 51.6317 N 155 14.7932 W 7.62 
        % S=     5055
        % |
        % 2006 184 22 31 00 2 4 1 18 51.6328 N 155 14.7915 W 5.75 
        % O=     5     8    0    0
        % T=  4.9  5.1  5.0  5.0 10.2 10.6  7.5  7.4 20.6  0.0 17.4 14.1
        % A=????
        % C=  -2.43   2.79 216.60   3.05
        % V=1483.062 1066.500 0004.008 0033.485
        % B=PI=12.00 N 03/13/92 23:32:35
        % 2006 184 22 31 00 2 4 1 18 51.6333 N 155 14.7909 W 5.91 
        % B=@02 08.00 07 000.3578
        % 2006 184 22 31 00 2 4 1 18 51.6333 N 155 14.7909 W 5.91 
        % B=@01 12.00 06 001.4152
        % 2006 184 22 31 01 2 4 1 18 51.6333 N 155 14.7909 W 5.91 
        % 
        
        % Parse known types of lines
        %---------------------------%
        %-- Standard SUESI output --%
        %---------------------------%
        if s(2) == '='                              % Standard SUESI reporting
            sub_SuesiRptLine( s );
            
        %----------%
        %-- SNAP --%
        %----------%
        elseif strncmpi( s, '# ', 2 )               % SNAP data line
            cSnapList{end+1} = s(3:end);
        elseif strncmpi( s, '#|', 2 )               % SNAP data interrupted by minute mark
            bNextIsSnap = true;
        elseif strncmpi( s, '-- starting snap', 16 )% SNAP collection started
            sub_LogThis( 'SNAP started' );
            cSnapList{end+1} = s;
        elseif strncmpi( s, '-- snap completed', 17 ) % SNAP done & ready to dump
            sub_LogThis( 'SNAP completed' );
            % NB: SOMETIMES has first snap data on the end of it!
            iSnapData = find( s == '#', 1, 'first' );
            if ~isempty(iSnapData)
                % Separate the "I finished" message from the data
                cSnapList{end+1} = s(1:iSnapData-1);
                cSnapList{end+1} = s(iSnapData+2:end);
            else
                cSnapList{end+1} = s;
            end
            
        %-----------------------------------------------%
        %-- SUESI event or response to a user command --%
        %-----------------------------------------------%
        elseif strncmpi( s, '-- ', 3 ) || strncmpi( s, '!- ', 3 ) || strncmpi( s, 'csync', 5 )
            sub_SuesiEvent( s );
            
        %-------------------------------------%
        %-- NMEA GPS - not used since 2010? --%
        %-------------------------------------%
        elseif strncmpi( s, '$GP', 3 )              % NMEA GPS strings
            sub_NMEA( s );
            
        %---------------------------%
        %-- Misc irrelevant codes --%
        %---------------------------%
        elseif strncmpi( s, '[R:', 3 )  % Tx timing report (user requested)
            sub_LogThis( ['Ignoring: ' s] );
            
        %------------------------------------------------%
        %-- Typed commands, outdated output, & unknown --%
        %------------------------------------------------%
        else
            % Some older logs have a GPS line integrated in from the computer
            % capturing the logs. It has a very defined output structure. I'm
            % not sure this has been used in the past decade at least...
            nGPS = onerow( sscanf( s, '%i %d %d %d %d %i %i %i %i %f %c %i %f %c %g %*s' ) );
            if numel(nGPS) == 15
                %   year day-of-year hour min sec mode tfom unknown
                %   latdeg latmin N/S londeg lonmin E/W height
                %   (NB: might end with optional hex checksum, e.g. '3A')
                nRow(col.Yr:col.Sec) = datevec( datenum( [nGPS(1) 1 nGPS(2:5)] ) );
                nRow(col.ShipLat) = (nGPS(9) + nGPS(10) / 60) ...
                    * iif( strcmpi( char(nGPS(11)), 'S' ), -1, 1 );
                nRow(col.ShipLon) = (nGPS(12) + nGPS(13) / 60) ...
                    * iif( strcmpi( char(nGPS(14)), 'W' ), -1, 1 );
                nRow(col.GPSMastHt) = nGPS(15);
            else
                % Ignore user-typed commands & some other miscellany
                sub_Ignorables( s );
                
            end
            
        end % chain of if/elseif/else for line type
    end % walk through input file one line at a time
    
    % Make sure the final row of data has been written out to the data block
    if sub_RowHasData()
        sub_MoveRowToDataBlock();
    end
    
    % Get rid of extra pre-allocated rows in each data block
    nData(nCurRow+1:end,:)  = [];
    nDataB(iNextB:end,:)    = [];
    nDataV(iNextV:end,:)    = [];
    
    % Convert the data blocks to tables - see note about how slow tables are
    % near the top of this function...
    tblBenthos = array2table( nDataB, 'VariableNames', fieldnames(colB) );
    clear nDataB colB
    
%     tblVulcan = table( 'Size', [10000 6] ...
%         , 'VariableNames', {'Time', 'DeviceNo', 'Heading', 'Pitch', 'Roll', 'Pressure'} ...
%         , 'VariableTypes', {'datetime','double','double','double','double','double'} ...
%         );
    tblVulcan = array2table( nDataV, 'VariableNames', fieldnames(colV) );
    tblVulcan.Time = datetime( tblVulcan.Time, 'ConvertFrom', 'datenum' );
    clear nDataV colV
    
    % Get rid of all lines with S=NaN. These data are worthless and generally
    % only occur when a SNAP or some other log interruption has messed up the
    % data stream
    nData(isnan(nData(:,col.SuesiSec)),:) = [];
    
    % Find all the places where sync state changes & create a list of from-to
    % rows for later convenience.
    %
    % NB: If the file STARTS already sync'd, there is NO WAY TO KNOW THAT
    % because there was no sync message saying so. If that's the case, then you
    % should edit the log and insert "-- sync successful" as the first line.
    iSyncChg = find( diff( nData(:,col.Sync) ) );
    if isempty( iSyncChg ) && nData(1,col.Sync) 
        % NB: The entire log is syncd from start to finish. This ONLY happens if
        % the user has edited the log and removed all the non-sync'd data.
        iSyncChg = 1;
    end
    if mod( numel(iSyncChg), 2 ) == 1 % ended sync'd
        iSyncChg(end+1) = size(nData,1);
    end
    nSyncRange = reshape( iSyncChg, 2, [] ).';  % Nx2 cols: from, to
    nSyncRange(:,1) = nSyncRange(:,1) + 1;      % has index of last non-sync, want 1st sync in range
    
    % NB: nSyncRange will be empty if all data are NOT sync'd
    if isempty( nSyncRange )
        bOK = false;
        cErr{end+1} = ['No data syncd to GPS in "' sFileIn '"'];
    else
        % For each sync range, propagate GPS date,time data through the range
        % based on a linear relationship between datetime and S= number. Note
        % that if there is no GPS info, there won't be any datetime info.
        for iSyncRow = 1:size(nSyncRange,1)
            iFromTo = nSyncRange(iSyncRow,1):nSyncRange(iSyncRow,2);
            
            % Look for the errored state where the S= goes backwards but no
            % change in sync state has occurred. Call this a critical error.
            iAt = find( diff( nData(iFromTo,col.SuesiSec) ) < 0 );
            if numel(iAt) > 0
                bOK = false;
                for i = onerow( iAt )
                    cErr{end+1} = sprintf( ...
                        'ERROR: S= resets from %d to %d between lines %d and %d without sync reset.' ...
                        , nData(iFromTo(i:i+1),col.SuesiSec) ...
                        , nData(iFromTo(i:i+1),col.FileLine) ...
                        );
                    cErr{end+1} = 'Fix the file manually. Ensure there is at least one S=<number>';
                    cErr{end+1} = 'line between when sync is lost and regained.';
                end
            end
            
            % If there's no GPS date, then nothing to propagate. Skip
            bHasDt  = ~isnan( nData(iFromTo,col.Yr) );
            if ~any(bHasDt)
                continue;
            end
            d = nData(iFromTo,[col.SuesiSec col.Yr:col.Sec]);
            nSSrc = d(bHasDt,1);
            nDSrc = datetime( d(bHasDt,2:7) );
            if numel(nSSrc) == 1
                nSSrc(end+1,1) = nSSrc + 86400;
                nDSrc(end+1,1) = nDSrc + 1;
            end
            nDEst = interp1NonUniq( nSSrc, nDSrc, d(~bHasDt,1) );
            d(~bHasDt,2:7) = datevec(nDEst);
            nData(iFromTo,col.Yr:col.Sec) = d(:,2:7);
        end
    end
    
    % If there were any transmitter waveform entries, dummy a last one so that
    % the table contains the final S= number in it. That makes it easier to
    % determine which of the many waveforms was in use the longest.
    if ~isempty( tblWaveForm )
        tblWaveForm{end+1,:}        = missing(); % add a new row
        tblWaveForm.FileLine(end)   = nFileLine;
        tblWaveForm.SuesiSec(end)   = nData(end,col.SuesiSec);
        tblWaveForm.Timing(end)     = '';
    end
    
    % Save the data to the various files
    % NB: nData might be really large. Use HDF5 format (v7.3)
    save( sOutParsed, 'nSyncRange', 'nData', 'col' ...
                    , 'tblWaveForm', 'tblBenthos', 'tblVulcan' ...
                    , '-v7.3' );
    if isempty( cSnapList )
        sOutSNAP = '';
    else
        save( sOutSNAP, 'cSnapList' );
    end
    
catch MeIfYouCan
    % Fatal error was thrown. Report & cleanly exit
    bOK = false;
    if isempty( MeIfYouCan.identifier )
        cErr{end+1,1} = MeIfYouCan.message;
    else
        % If there's an identifier, it's most likely a MATLAB crash. Give the
        % full call stack.
        if exist( 'nFileLine', 'var' )
            cErr{end+1,1} = ['At nFileLine ' num2str(nFileLine)];
        end
        for iStack = 1:numel( MeIfYouCan.stack )
            cErr{end+1,1} = ['Line: ' num2str(MeIfYouCan.stack(iStack).line) ' ' MeIfYouCan.stack(iStack).name];
        end
        cErr{end+1,1} = [MeIfYouCan.identifier '::' MeIfYouCan.message];
    end
    if fidLog > 0
        fprintf( fidLog, 'FATAL ERROR: %s\n', cErr{end} );
    end
end

% Close the text capture log, if open
if fidLog >= 3
    fclose( fidLog );
end

% Kill the progress bar if it ever existed
if ~isempty( oProg )    % NB: oProg is either a handle or a ProgressDialog object
    try %#ok<TRYNC>
        delete( oProg );
    end
end

return;

%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------
% Embedded functions - these have access to ALL the variables in the main fcn
%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------
    
    %---------------------------------------------------------------------------
    % Output something for the log and optionally put into the warn / error list
    function sub_LogThis( sMsg, sWarnErr )
        sMsg = [
            '(Line ' num2str(nFileLine) ...
            '  S=' num2str(nRow(col.SuesiSec)) ')  :: ' ...
            sMsg
            ];
        fprintf( fidLog, '%s\n', sMsg );
        if exist( 'sWarnErr', 'var' )
            if sWarnErr(1) == 'W'
                cWarn{end+1} = sMsg;
            else
                cErr{end+1} = sMsg;
            end
        end
        return;
    end % sub_LogThis

    %---------------------------------------------------------------------------
    % Does the current working row contain "data"?
    %
    % NB: not all columns actually constitute data we need to keep track of
    % separately.
    function bYup = sub_RowHasData()
        bYup = any( ~isnan(nRow(cols_Data)) ); % other data besides time stamps
        return;
    end % sub_RowHasData
    
    %---------------------------------------------------------------------------
    % Move the current working row into the data block. Don't create a brand-new
    % row in the data block if the current line there is empty of actual data.
    function sub_MoveRowToDataBlock()
        if all( isnan( nData(nCurRow,cols_Data) ) )
            % The current row in the output array is empty of actual data. Don't
            % increment row count. Overwrite this row
        else
            % If need to grow the data buffer, don't do it by just one new
            % row - do it by a lot at a time.  This is MUCH faster when the
            % tow generates 100,000's of lines.
            nCurRow = nCurRow + 1;
            if nCurRow > size(nData,1)
                fprintf( fidLog, 'Growing output buffer by 50,000 more rows.\n' );
                nData(end+1:end+50000,:) = NaN;
            end
        end
        nData(nCurRow,:)    = nRow;
        
        % Clear the assembly buffer & set the file line no. Set it here because
        % moving data usually occurs when we've read a new line which needs to
        % clear out the assembly buffer before filling it again. That file line
        % no belongs to the new data.
        nRow                = NaN(1,size(nData,2));
        nRow(col.FileLine)  = nFileLine;
        nRow(col.Sync)      = bSync;
        return;
    end % sub_MoveRowToDataBlock
    
    %---------------------------------------------------------------------------
    % If the cols I'm about to write in already have data, then don't overwrite,
    % move to the output list and reset the row.
    function sub_KickOutLine( nChkCols )
        if any( ~isnan( nRow(nChkCols) ) )
            sub_MoveRowToDataBlock();
        end
        return;
    end % sub_KickOutLine
    
    %---------------------------------------------------------------------------
    % Look for stuff that can be ignored. Log anything else as a warning.
    function sub_Ignorables( s )
        % Look for user-typed commands, which get echoed into the log ONE
        % character at a time, repeating all previous characters on each
        % subsequent line. Example:
        % B         <-- NB: single char lines are dropped above
        % BS
        % BST
        % BSTA
        % BSTAR
        % BSTART
        nLen = length(s);
        if strncmpi( s, 'suesi', min(nLen,5)) ...
        || strncmpi( s, 'start', min(nLen,5)) ...   OUTPUT current
        || strncmpi( s, 'stop', min(nLen,4)) ...
        || strncmpi( s, 'aon', min(nLen,3)) ...     ALTIMETER on/off
        || strncmpi( s, 'aoff', min(nLen,4)) ...
        || strncmpi( s, 'auxon', min(nLen,5)) ...   ?
        || strncmpi( s, 'bclr', min(nLen,4)) ...    BENTHOS pinger commands
        || strncmpi( s, 'bdly', min(nLen,4)) ...
        || strncmpi( s, 'bfreq', min(nLen,5)) ...
        || strncmpi( s, 'bpo', min(nLen,3)) ...
        || strncmpi( s, 'bp=', min(nLen,3)) ...
        || strncmpi( s, 'brate', min(nLen,5)) ...
        || strncmpi( s, 'bsave', min(nLen,5)) ...
        || strncmpi( s, 'bstart', min(nLen,6)) ...
        || strncmpi( s, 'bstop', min(nLen,5)) ...
        || strncmpi( s, 'bview', min(nLen,5)) ...
        || strncmpi( s, 'bstat', min(nLen,5)) ...
        || strncmpi( s, 'bon', min(nLen,3)) ...
        || strncmpi( s, 'boff', min(nLen,4)) ...
        || strncmpi( s, 'csyn', min(nLen,5)) ...    NB: let full CSYNC command fall through but ignore typing up to it
        || strncmpi( s, 'fon', min(nLen,3)) ...     ?
        || strncmpi( s, 'foff', min(nLen,4)) ...
        || strncmpi( s, 'logon', min(nLen,5)) ...   ?
        || strncmpi( s, 'snap', min(nLen,4)) ...    SNAP
        || strncmpi( s, 'ss=', min(nLen,3)) ...     ?
        || strncmpi( s, 'sr=', min(nLen,3)) ...     ?
        || strncmpi( s, 'stat', min(nLen,4)) ...    Rqst SUESI status
        || strncmpi( s, 'von', min(nLen,3)) ...     VALEPORT on/off
        || strncmpi( s, 'voff', min(nLen,4)) ...
        || strncmpi( s, 'wav', min(nLen,3)) ...     WAVEFORM specification
        || strncmpi( s, 'wclr', min(nLen,4)) ...
        || strncmpi( s, 'wload', min(nLen,5)) ...
        || strncmpi( s, 'wsave', min(nLen,5)) ...
        || strncmpi( s, 'wview', min(nLen,5))
            % do nothing - ignore typed commands
        else
            sub_LogThis( ['Unknown line:: ' s], 'Warn' );
        end
        return;
    end % sub_Ignorables

    %---------------------------------------------------------------------------
    % Parse standard set of <C>=<data> SUESI output lines
    function sub_SuesiRptLine( s )
        
        switch( upper(s(1)) )
        case 'S'    % SUESI's number of seconds since power up
            % If there's already a stamp, kick out a new line.
            sub_KickOutLine( col.SuesiSec );
            nRow(col.FileLine)  = nFileLine;
            nRow(col.Sync)      = bSync;
            nLastS              = str2double( s(3:end) );
            nRow(col.SuesiSec)  = nLastS;
            
        case 'A'    % Altitude
            if s(3) ~= '?' % altimeter reports '?' when out of range
                % If there's already a value, kick out a new line.
                sub_KickOutLine( col.Alt );
                nRow(col.Alt) = str2double( s(3:end) );
            end

        case 'V'    % Valeport
            % There's an ANCIENT problem (2006 vintage) where valeport lines
            % have crap in them. Clear this in case it crops up again. The
            % Valeport equipment is itself ancient and un-updated.
            %
            % Example: V=üÿ1483.39C 0927.12R 0004.65C 0033.9
            if s(3) ~= '?'  % ignore V=???? lines
                s(s > 127) = ' ';
                nVal = sscanf(s(3:end),'%f');
                if numel(nVal) ~= 4
                    sub_LogThis( ['Unknown line:: ' s], 'Warn' );
                else
                    sub_KickOutLine( col.ValeSpeed:col.ValeCond );
                    nRow([col.ValeSpeed col.ValePres col.ValeTemp col.ValeCond]) = nVal;
                end
            end
            
        case 'C'    % Compass: tilt, tilt, heading, temperature (uncalibrated)
            if s(3) ~= '?' && ~strncmpi(s,'C=FalmoutScientic',17)
                nVal = sscanf(s(3:end),'%f');
                if numel(nVal) ~= 4
                    sub_LogThis( ['Unknown line:: ' s], 'Warn' );
                else
                    sub_KickOutLine( col.Tilt1:col.CompassTemp );
                    nRow([col.Tilt1 col.Tilt2 col.Heading col.CompassTemp]) = nVal;
                end
            end
            
        case 'B'    % Benthos - cld be pinging OR commands entered by user
            if length(s) < 5
                % Probably the user typing a benthos command.  They are
                % often "B=...".
            elseif strcmpi( s(3:5), '@pi' ) % ignore ping confirmation message

            elseif (length(s) > 5 && strcmpi( s(3:5), 'pi=' )) ... B=PI= ping
                || (length(s) > 6 && strcmpi( s(3:6), '@PR=' ))
                % B=PI=09.00 N 05/27/09 15:50:48
                %
                % DGM Jun 2009 - getting some B=@PR= which are also pings. This
                % might be Scarborough only but perhaps it's a recurring bug in
                % the Benthos software?
                %
                % NB: ignore date+time on these lines because it is always
                % wrong. No one bothers to set it correctly and sometimes it
                % sticks on the same date & time for hours (c.f. Scarborough)
                %
                nPingNo = nPingNo + 1;
                if s(3) == '@'
                    nLastPingHz = sscanf(s(7:end),'%f',1);
                else
                    nLastPingHz = sscanf(s(6:end),'%f',1);
                end
                nLastPingHz = round( nLastPingHz, 1 );  % only 1 dec place supported

            elseif s(3) == '@'              % B=@nn -- ping reply
                % NB: GOFAR log has lots of 'B=@01 PI10.00 ...' lines. Where is
                % that 'PI' coming from? Is this GOFAR only or many surveys?
                nVal = sscanf( strrep( s(4:end), 'PI', '' ), '%f' );
                if numel(nVal) ~= 4
                    sub_LogThis( ['Unknown line:: ' s], 'Warn' );
                    return;
                end
                
                % Apply the gain-based TWTT correction that KK discovered in the
                % Benthos manual. And as BW found, watch out for invalid gain
                % values. Floating point ambiguity from sscanf can screw this up
                nVal(3) = floor( nVal(3) );
                if between( 1, nVal(3), numel(nGainCorrection) )
                    nVal(4) = nVal(4) - nGainCorrection( nVal(3) );
                end
                if ~between( 0, nVal(4), 12 ) % even 12 seconds is generous
                    sub_LogThis( ['Ping reply outside valid TWTT: ' s], 'Warn' );
                    return;
                end
                
                % NB: keep track of the ping number because this groups together
                % all the replies from a single ping. Depending on water
                % conditions, there can be a lot of multi-path replies from
                % bounces off the seafloor and sea surface. Having them grouped
                % allows for easier elimination of multiples.
                if iNextB > size(nDataB,1)
                    nDataB(iNextB:iNextB+1000,:) = NaN;
                end
                nDataB(iNextB,colB.FileLine)    = nRow(col.FileLine);
                nDataB(iNextB,colB.SuesiSec)    = nLastS;
                nDataB(iNextB,colB.PingNo)      = nPingNo;
                nDataB(iNextB,colB.PingFreq)    = nLastPingHz;
                nDataB(iNextB,colB.ReplyCh)     = round( nVal(1) );
                nDataB(iNextB,colB.ReplyFreq)   = round( nVal(2), 1 );
                nDataB(iNextB,colB.ReplyTWTT)   = nVal(4);
                
                iNextB = iNextB + 1;
            end

        case 'O'    % Output power  % KWK May 2013: updated to also handle new 3 column O output
            nVal = sscanf(s(3:end),'%f');
            if numel(nVal) ~= 4 && numel(nVal) ~= 3
                sub_LogThis( ['Unknown line:: ' s], 'Warn' );
            else
                sub_KickOutLine( col.Amp1:col.Amp4 );
                nRow(col.Amp1 + (1:numel(nVal)) - 1) = nVal;
            end

        case 'T'    % Temperatures
            % 12/2022 as far as I know, no one ever uses the Temp lines so I've
            % completely omitted them from this version of the parsing code.
            % We'll see if anyone ever notices.

        case 'W'    % Vulcan upstream reporting
            % Vulcans & other devices send data up the stream. The format is:
            %
            % [device #], mm/dd/yy hh:mm:ss heading pitch roll "*0001"psi
            %
            % w=[ 3] 02/03/22 20:01:56 75.1,-31.2,-0.5 *00014024.69
            % w=[ 2] 02/03/22 20:02:00 100.5,-32.6,-8.5 *00014411.96
            % w=[ 4] 02/03/22 20:02:00 69.4,-34.8,-3.9 *00013866.66
            %
            % Note from J.Souders 12/14/2022:
            %   First vulcan in the string is #3. #1 and #2 are inside the ATET. 
            %   I don't believe #1 sends data.
            %
            % Note from J.Souders 5/25/2023:
            %   The pressure values are from PAROSCI instruments in psi.
            %
            nVal = sscanf( s, 'w=[%d] %d/%d/%d %d:%d:%d %f,%f,%f *0001%f' );
            if numel(nVal) ~= 11
                % NB: often see cases in the GOFAR SUESI log where a character's
                % high bit is turned on. If sscanf fails the first time, try
                % stripping the high bit.
                %
                % NB: also often see cases where there is a (b)11111111 char
                % before the open bracket
                if s(4) == '['
                    s(3) = [];
                end
                nVal = sscanf( char(mod(s,128)), 'w=[%d] %d/%d/%d %d:%d:%d %f,%f,%f *0001%f' );
            end
            if numel(nVal) ~= 11
                sub_LogThis( ['Unknown line:: ' s], 'Warn' );
                return;
            end
            
            % Vulcans know the time. Put this into SUESI's log so the S= gets
            % automatically synced to real time
            if nVal(4) < 100    % missing the century
                nVal(4) = nVal(4) + 2000;
            end
            iColOrder = [col.Mo col.Day col.Yr col.Hr col.Min col.Sec];
            sub_KickOutLine( iColOrder );
            nRow(iColOrder) = nVal(2:7);
            
            % Put it in the vulcan table
            if iNextV > size(nDataV,1)
                nDataV(iNextV:iNextV+10000,:) = NaN;
            end
            nDataV(iNextV,colV.Time)      = datenum(onerow(nVal([4 2 3 5 6 7])));
            nDataV(iNextV,colV.DeviceNo)  = nVal(1);
            nDataV(iNextV,colV.Heading)   = nVal(8);
            nDataV(iNextV,colV.Pitch)     = nVal(9);
            nDataV(iNextV,colV.Roll)      = nVal(10);
            nDataV(iNextV,colV.Pressure)  = nVal(11);
            iNextV = iNextV + 1;
            
        otherwise   % Unknown!
            sub_LogThis( ['Unknown line:: ' s], 'Warn' );
        end
        
        return;
    end % sub_SuesiRptLine

    %---------------------------------------------------------------------------
    % SUESI reporting some event
    function sub_SuesiEvent( s )
        sLower = lower(s);
        
        if contains( sLower, '-- reset ' ) ...
        || contains( sLower, 'not synced' ) ...
        || contains( sLower, 'system resetting' ) ...
        || strncmpi( s, 'csync', 5 ) ...  CSYNC command causes reset without a reset string notification
        || strncmpi( s, '!- Switching to internal clock', 30 )
            % NOTE: System reset ALWAYS loses GPS sync!  This is a reboot of the
            % SUESI software. Curiously, the "seconds since start" sometimes
            % continues without interruption. It takes a powerdown to reset this
            % number -- it must be an interrupt latch in the pic. If we were
            % sync'd but now aren't, then the system reset itself. We need to
            % segregate the output because the GPS time offset will be different
            % for each sync period.
            
            % Tell the user - system not sync'd to GPS time.
            sub_LogThis( s );
            sub_LogThis( ['SUESI GPS SYNC = false (was ' iif(bSync,'true','false') ')'] );
            
            % At change of sync state, force out any current data
            sub_MoveRowToDataBlock();
            
            % Now change the sync flag
            bSync           = false;
            nRow(col.Sync)  = false;
            
        elseif contains( sLower, 'gps sync ok' ) ...
        || contains( sLower, 'clock: external' ) ...    NB: at some point John S. removed ', synced to gps'
        ... || contains( sLower, 'clock: external, synced to gps' ) ...
        || contains( sLower, 'sync successful' )
    
            % Tell the user - system now sync'd
            sub_LogThis( s );
            sub_LogThis( ['SUESI GPS SYNC = true (was ' iif(bSync,'true','false') ')'] );
            
            % At change of sync state, force out any current data
            sub_MoveRowToDataBlock();
            
            % It's possible for sync to reset so quickly that no data lines are
            % output but the S= number restarts (see every SUESI log in the
            % GOFAR cruise). If that happens, then insert a bogus data line
            % marked as out of sync so that the reset is "seen" by code further
            % on that gathers the sync sections together.
            bWasSyncd = iif( isnan(nData(nCurRow,col.Sync)), false, nData(nCurRow,col.Sync) );
            if ~bSync && bWasSyncd && nCurRow > 1
                nRow                = nData(nCurRow,:);
                nRow(col.SuesiSec)  = nRow(col.SuesiSec) + 1;
                nRow(col.Sync)      = false;
                sub_MoveRowToDataBlock();
            end
            
            % Change the flag
            bSync           = true;
            nRow(col.Sync)  = true;
            
        elseif strncmpi( s, '-- TRANSMITTER TIMING:', 22 )
            % Transmitter timings go into a table which WAVE will use to get the
            % default idealized waveform for this survey
            if numel(s) > 22 % some older surveys have empty timing lines
                tblWaveForm{end+1,:} = missing();   % add a new row
                tblWaveForm.FileLine(end) = nFileLine;
                tblWaveForm.Timing(end)   = s(23:end);
                tblWaveForm.SuesiSec(end) = nRow(col.SuesiSec);
                if isnan(tblWaveForm.SuesiSec(end))
                    if nCurRow > 1
                        tblWaveForm.SuesiSec(end) = nData(nCurRow-1,col.SuesiSec);
                    else
                        tblWaveForm.SuesiSec(end) = 0;  % start of file. No S= line yet
                    end
                end
            end
            
        elseif strncmpi( s, '!- Invalid Command', 18 )
            % do nothing
            
        else
            % No need to warn or error. Just an event report or response to a
            % user query
            sub_LogThis( s );
            
        end
        return;
    end % sub_SuesiEvent
    
    %---------------------------------------------------------------------------
    function sub_NMEA( s )
        [nRtnCode, mGPS, colGPS] = parseNMEA( s );
        switch( nRtnCode )
        case 0      % parsed OK
            % Handle date & time.  Some sentences have neither, some have only
            % time and no date (ick!).
            if ~isnan( mGPS(colGPS.Date) )
                % If no date, just time, then look back through
                % previous data and grab the date from there. Check
                % for passing over midnight.
                if mGPS(colGPS.Date) < 1
                    for iLookBack = (nCurRow-1):-1:1
                        if isnan( nData(iLookBack,col.Yr) )
                            continue;
                        end
                        if datenum( [0 0 0 nData(iLookBack,col.Hr:col.Sec)] ) ...
                        > mGPS(colGPS.Date)
                            
                            mGPS(colGPS.Date) = mGPS(colGPS.Date) ...
                                + floor(datenum(nData(iLookBack,col.Yr:col.Sec))) ...
                                + 1;    % went over the day boundary
                            sub_LogThis( 'NMEA had time only. Date from previous GPS. Midnight crossed, guessing date!' );
                        else
                            mGPS(colGPS.Date) = mGPS(colGPS.Date) ...
                                + floor(datenum(nData(iLookBack,col.Yr:col.Sec)));
                        end
                        break;
                    end
                end
                
                % If this line has more than just date/time, then explore the
                % possibility of kicking out the current row buffer and starting
                % a new one.
                % If it has only date/time, then it is probably a $GPZDA and I
                % just want to update the current row and move on.
                if sum(~isnan(mGPS)) > 1
                    if any(~isnan(nRow(col.Yr:col.Sec))) ...
                    && ~isequal( nRow(col.Yr:col.Sec), datevec(mGPS(colGPS.Date)) ) ...
                    && sub_RowHasData()
                        sub_MoveRowToDataBlock();
                        
                        % Preserve the "S=" if multiple GPS strings occur within
                        % one block of SUESI output lines (this is frequent)
                        nRow(col.SuesiSec)  = nData(nCurRow,col.SuesiSec);
                    end
                end
                
                % Store the date/time in the current row buffer
                nRow(col.Yr:col.Sec) = datevec(mGPS(colGPS.Date));
                if mGPS(colGPS.Date) < 1
                    nRow(col.Yr:col.Day) = NaN;     % no date, just time

                    % If didn't get a date (i.e. no dates since beginning of the
                    % log), warn and continue.
                    sub_LogThis( 'NMEA had time only. Have no date since beginning of log.' );
                end
            end
            
            % Handle the other data...
            if ~isnan(mGPS(colGPS.Lon))
                nRow(col.ShipLon) = mGPS(colGPS.Lon);
            end
            if ~isnan(mGPS(colGPS.Lat))
                nRow(col.ShipLat) = mGPS(colGPS.Lat);
            end
            if ~isnan(mGPS(colGPS.AntHt))
                nRow(col.GPSMastHt) = mGPS(colGPS.AntHt);
            end
            
        case 1      % ignored - nothing we want on this sentence
        case 2      % error in parsing
            sub_LogThis( ['Unparsable GPS line:: ' s], 'Warn' );
        end
        return;
    end % sub_NMEA
    
end % decodeSUESI
