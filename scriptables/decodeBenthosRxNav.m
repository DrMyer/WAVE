function [bOK,tblPing,cErrMsg] = decodeBenthosRxNav( sNavFile, bRtnAllReplies, hUIFig, bUseShortcuts, sEllipsoid, nUTMZone )
% [bOK,tblPing] = decodeBenthosRxNav( sNavFile, bRtnAllReplies, hUIFig, bUseShortcuts, sEllipsoid, nUTMZone )
%
% Decode a text file containing a mixture of ship's GPS location and Benthos
% ping-related strings.
%
% This code is based on getBenthosData.m which it SUPERCEDES.
% 
% NB: Benthos date/time is ignored because of a bug where it locks up.
% NB: In the text stream, the GPS data is output first, then the Benthos
%     data.  So whenever a new GPS string appears, new Benthos data follows.
%
% Params:
%   sNavFile    - path & filename to process.
%   bRtnAllReplies- (opt; dflt false) If true, multiple replies per ping are 
%               returned. If false, only the first reply per ping is returned.
%               Can also be texts 'All' or 'FirstOnly'.
%   hUIFig      - handle to a uifigure (not figure) for uiprogressdlg(). 
%               If [] then a waitbar is used centered over gcf()
%   bUseShortcuts - (opt; dflt true) if true, looks for a .mat file of the same
%               name and just loads it and returns. If the file doesn't exist,
%               then when the text file processing is done, it creates it so
%               that subsequent parsing of these files goes quickly.
%                   Can be text 'Shortcuts' or 'NoShortcuts'
%   sEllipsoid - (opt; dflt 'wgs84') ellipsoid for LonLat2UTM()
%   nUTMZone - (opt; dflt []) UTM zone to force lon,lat to
% Returns:
%   bOK     - T/F if successful
%   tblPing - a table containing the ping info (see code for definition)
%   cErrMsg - if ~bOK, a cell array of error message strings suitable for
%               passing to uialert. No error shown to the user. You do that.
%
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
    arguments
        sNavFile
        bRtnAllReplies      = false
        hUIFig              = NaN
        bUseShortcuts       = true
        sEllipsoid string   = "wgs84"
        nUTMZone double     = []
    end
    
    % Deal with optional params
    if isempty( bRtnAllReplies )
        bRtnAllReplies = false;
    elseif ischar( bRtnAllReplies ) || isstring( bRtnAllReplies )
        bRtnAllReplies = strncmpi( bRtnAllReplies, 'All', 3 );
    end
    if isempty( hUIFig )
        hUIFig = NaN;
    end
    if isempty( bUseShortcuts )
        bUseShortcuts = true;
    elseif ischar( bUseShortcuts ) || isstring( bUseShortcuts )
        bUseShortcuts = strncmpi( bUseShortcuts, 'Short', 5 );
    end
    
    % Gain Based Delay Correction, from Page 12 in Benthos' DS-7000 manual:
    % Corrections for gains 1-9, in seconds (many thanks to KWK for pointing
    % this out)
    nGainCorr = [8.74 8.74 8.74 7.58 6.70 5.99 5.46 5.23 4.66] / 1000;
    
    % Init return vars
    bOK     = true;
    cErrMsg = {};
    tblPing = table( 'Size', [0 9] ...
        , 'VariableNames', {'Time','Lon','Lat','E','N','PingFreq','ReplyFreq','TWTT','LineNo'} ...
        , 'VariableTypes', [{'datetime'} repmat({'double'},1,8)] ...
        );
    
    % If a shortcut file is called for and it exists and is NEWER than the text
    % file, load & return
    if bUseShortcuts
        stDirTX = dir( sNavFile );
        stDirSC = dir( [sNavFile '.mat'] );
        if ~isempty( stDirSC ) && ~isempty( stDirTX ) && stDirSC.datenum > stDirTX.datenum
            oMat    = matfile( [sNavFile '.mat'] );
            tblPing = oMat.tblPing;
            
            % NB: *always* recalc E,N from Lon,Lat because the user may change
            % the UTM zone - some surveys are quite large or bridge across a
            % zone boundary and users are fickle creatures.
            [tblPing.E,tblPing.N] = LonLat2UTM( tblPing.Lon, tblPing.Lat ...
                , nUTMZone, sEllipsoid );
            
            return;
        end
    end
    
    % Pre-allocate the return table in one chunk. This is far more efficient
    % than adding one row at a time, which causes lots of memory reallocations.
    tblPing{1:10000,:} = missing();
    iPing = 1;
    
    % Set up the progress bar
    fid = fopen( sNavFile, 'r' );
    fseek( fid, 0, 'eof' );
    nByteTot = ftell( fid );
    fseek( fid, 0, 'bof' );
    
    [sPathIn,sFile] = fileparts( sNavFile );
    if ishandle( hUIFig )
        oProg = uiprogressdlg( hUIFig, 'Title', 'Parse Benthos File' ...
            , 'Message', {sFile;sPathIn}, 'Cancelable', true );
    else
        oProg = figCenter( 0, waitbar( 0, sFile, 'Name', 'Parse Benthos File' ) );
    end
    
    % Read the file line-by-line & process it.
    tTic    = tic();
    nLineNo = 0;
    try
        while( ~feof(fid) )
            % Has the user canceled?
            if ishandle( hUIFig )       % uiprogressdlg
                if oProg.CancelRequested
                    error( 'User Canceled!' );
                end
            else                        % waitbar
                if ~ishandle( oProg )   % user closed the progress window = cancel
                    error( 'User Canceled!' );
                end
            end
            
            % Report progress every now and then
            if toc(tTic) >= 1
                if ishandle( hUIFig )   % uiprogressdlg
                    oProg.Value = ftell( fid ) / nByteTot;
                else                    % waitbar
                    waitbar( ftell( fid ) / nByteTot, oProg );
                end
                tTic = tic(); % reset the timer
            end
            
            %  Get the next line
            s       = strtrim( fgetl(fid) );
            nLineNo = nLineNo + 1;
            if isempty(s)
                continue;
            end
            tblPing.LineNo(iPing) = nLineNo;
            
            % A GPS line:
            % 2009 145 09 48 47 2 4 1 19 57.9476 S 113 20.8870 E 14.60
            % year daynum hh mm ss ? ? ? lat latmin N/S lon lonmin E/W HtOverGeoid
            if strncmpi( s, '20', 2 ) % Yes. This will break in 2100. So what.
                nStuff = sscanf( s, '%d %d %d %d %d %*d %*d %*d %d %f %c %d %f %c %*f' );
                if numel(nStuff) == 11
                    tblPing.Time(iPing) = datetime( [nStuff(1) 1 nStuff(2:5).'] );
                    tblPing.Lat(iPing)  = (nStuff(6) + nStuff(7)/60) ...
                        * ((upper(nStuff(8))=='N')*2 - 1);
                    tblPing.Lon(iPing)  = (nStuff(9) + nStuff(10)/60) ...
                        * ((upper(nStuff(11))=='E')*2 - 1);
                end
                
                % A Ping command (tells the ping freq)
                % PI=10.50 N 03/27/09 17:25:31
                % NB: date/time is always bad because of a Benthos bug
            elseif strncmpi( s, 'PI=', 3 )
                nStuff = sscanf( s, 'PI=%f' );
                if numel( nStuff ) == 1
                    tblPing.PingFreq(iPing) = nStuff( 1 );
                end
                
                % A Ping reply (tells the TWTT and the reply freq)
                % @01 12.00 06 000.6651
                % @channel replyfreq gainlevel twtt
            elseif s(1) == '@'
                nStuff = sscanf( s, '@%*d %f %f %f' );
                if numel(nStuff) == 3 && between( 1, nStuff(2), numel(nGainCorr) )
                    tblPing.ReplyFreq(iPing)    = nStuff(1);
                    tblPing.TWTT(iPing)         = nStuff(3) - nGainCorr(nStuff(2));
                    
                    % If I have GPS data & a ping freq, then increment iPing. If
                    % it's beyond the table, allocate another block of data
                    if ~ismissing( tblPing.Time(iPing) ) ...
                    && ~ismissing( tblPing.PingFreq(iPing) )
                        % Move to the next table row
                        iPing = iPing + 1;
                        if iPing > height( tblPing )
                            tblPing{iPing:(iPing+10000),:} = missing();
                        end
                        
                        % If the user wants multiple replies per ping, then copy
                        % the header info to the next row
                        if bRtnAllReplies
                            tblPing(iPing,:)            = tblPing(iPing-1,:);
                            tblPing.ReplyFreq(iPing)    = missing();
                            tblPing.TWTT(iPing)         = missing();
                        end
                    end
                end
            end % if/elseif looking at what type of line this is
            
        end % loop through the file
    catch Me
        bOK = false;
        cErrMsg = {
            ['Error: ' Me.identifier '::' Me.message]
            sNavFile
            };
    end
    
    % KWK pointed out in 6/2019 that sometimes the ship is moving rather fast
    % during Rx navigation so we should be looking at the lon,lat location for
    % the ship at the center of the TWTT - i.e. the time the ping reached the
    % receiver. He modified getBenthosData.m accordingly.
    % 
    % HOWEVER, he assumed that the GPS date/times reported are the time that the
    % ping occurred, which is wrong. The GPS times are reported at irregular
    % intervals between 3 & 10 seconds. The PI= line hits the text file when the
    % ping is sent and the @ch reply is reported when received. The GPS times
    % are NOT directly correlated with the ping or reply text lines in the file.
    % There is slop of possibly quite a few seconds. So moving to a center TWTT
    % to try to be more accurate introduces a BIAS in the data. Don't do it.
    %
    % I wish people would TALK to me before modifying my code. Sigh.
    
    % Close up various objects
    fclose(fid);
    if ~isempty( oProg )    % NB: oProg is either a handle or a uiprogressdlg
        try %#ok<TRYNC>
            delete( oProg );
        end
    end
    
    % Finish up the table
    if bOK
        % Get rid of all the extraneous pre-allocated space in the table
        tblPing(iPing:end,:) = [];
        
        % If the table is empty, something went wrong
        if isempty( tblPing )
            bOK = false;
            cErrMsg = {['No data found in (supposed) Benthos log file: ' sNavFile]};
        else
            % Convert lon,lat to UTM
            [tblPing.E,tblPing.N] = LonLat2UTM( tblPing.Lon, tblPing.Lat ...
                , nUTMZone, sEllipsoid );
        end
    else
        tblPing(1:end,:) = [];
    end
    
    % If all is OK and shortcut file use is OK, then save a shortcut file
    if bOK && bUseShortcuts
        save( [sNavFile '.mat'], 'tblPing' );
    end
    
    return;
end % decodeBenthosRxNav
