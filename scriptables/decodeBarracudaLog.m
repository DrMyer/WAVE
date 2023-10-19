function [bOK,tCuda,cErr,nYr] = decodeBarracudaLog( sFile, nYr, sEllipsoid, nUTMZone, hUIFig )
% [bOK,tCuda,cErr,nYr] = decodeBarracudaLog( sFile, nYr, sEllipsoid, nUTMZone, hUIFig )
%
% Decode the SIO Barracuda text log files - both old formats that don't have
% year and new formats which do.
%
% Params:
%   sFile   - path+file to parse
%   nYr     - year to use if one is not found in the file
%   sEllipsoid - (opt; dflt 'wgs84') ellipsoid for converting lon,lat to UTM
%   nUTMZone - (opt; dflt []) UTM zone to force lon,lat to
%   hUIFig  - (opt; dflt []) handle of uifigure (NOT figure) to put a
%           uiprogressbar over. If not given, no progress bar is used
%
% Returns:
%   bOK     - T/F did the process succeed?
%   tCuda   - a table containing the data
%   cErr    - cell array of errors generated
%   nYr     - the last year found in the file (or if none, what you passed in)
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
        sFile char
        nYr double
        sEllipsoid char = 'wgs84'
        nUTMZone double = []
        hUIFig handle   = []
    end
    
    % Default the return values
    bOK     = true;
    cErr    = cell(0,1);
    tCuda   = cwave.GetDfltFor( 'tableCudaGPS', 0 );
    
    % Setup a data buffer. 
    %
    % NB: setting tCuda one line at a time, even with preallocated rows, is
    % super slow. Poor internal MatLab implementation? My guess is that ML is
    % checking the data type every time you set a column. Doing it once is
    % better than 300,000 times.
    %
    % NB: datenum() gives double whereas datetime() cannot be put in a numeric
    % array. Conversion from datenum to datetime of an entire vector is very
    % fast whereas item-by-item is very slow. So all told, lots of time saved by
    % creating a bunch of datenums then converting them all at once to datetime
    nCuda   = zeros(100000,5); % DeviceNo, FileLine, Latitude, Longitude, datenum
    iNext   = 1;
    
    % Read the entire file in one go - this is way faster than using fgetl().
    % NB: Do NOT skip empty lines. Errors reference the line# in the file so I
    % need it to be accurate
    sLns = readlines( sFile, 'WhitespaceRule', 'trim', 'EmptyLineRule', 'read' );
    
    % Figure out which format this is. If it is the old format, then scan until
    % we find a day-of-year line so we can get the y,m,d
    bOldFmt = NaN;      % need definite determination of format
    nYMD    = [nYr 1 0];
    for iLn = 1:numel(sLns)
        if strncmpi( sLns(iLn), '*1Sync', 6 )
            c = strsplit(sLns(iLn),{':','-'});
            nYMD(3) = str2num(c{2});
            if ~isnan(bOldFmt)
                break;
            end
            % Don't stop yet. Need to see at least ONE )2NAV line so I can tell
            % if this is the old or new format. If the file starts with a *1Sync
            % line then I won't know at this point.
        elseif strncmpi( sLns(iLn), ')2NAV', 5 )
            c = strsplit( sLns(iLn), ',', 'CollapseDelimiters', false );
            switch( numel(c) )
            case 7 % old format
                bOldFmt = true;
                % If we have the date already, we know all we need. Drop out
                if nYMD(3) ~= 0
                    break;
                end
            case 8 % new format
                bOldFmt = false;
                nYr = 2000 + str2num(c{7}(5:6)); % for returning to the caller
                break;
            end
        end
    end
    if iLn >= numel(sLns)
        if isnan( bOldFmt )
            cErr{1,1} = 'Unable to determine file format';
        elseif bOldFmt
            cErr{1,1} = 'Old format file does not contain a "*1Sync" line with the day-of-year';
        else
            cErr{1,1} = 'Unable to parse file';
        end
        bOK = false;
        return;
    end
    
    % Set up for a progress bar
    if ~isempty( hUIFig )
        [~,sF] = fileparts( sFile );
        oProg = uiprogressdlg( hUIFig, 'Title', 'Parse Barracuda Log' ...
            , 'Message', ['Parsing "' sF '" ...'], 'Cancelable', 'on' );
        oPClose = onCleanup( @()close(oProg) );
        nLastPct = 0;
    end
    
    % Parse through the lines of text
    for iLn = 1:numel(sLns)
        nPct = floor( iLn / numel(sLns) * 100 );
        if nPct > nLastPct
            if ~isempty( hUIFig )
                if oProg.CancelRequested
                    bOK = false;
                    iNext = 1;  % force entire table to be deleted
                    break;
                end
                nLastPct = nPct;
                oProg.Value = nPct / 100;
            end
        end
        
        % Get the next line
        s = char(sLns(iLn));
        if length(s) < 18
            continue;
        end
        
        if s(2) == '$' || s(1) == '('
            %
            % NB: There are a tremendous number of lines in this file that we
            % ignore. They are there for J.Souder's debugging
            %
            % NB: The *$GPGL,Lat,N/S,Lon,E/W,hhmmss lines are the position of
            % the ship when the radio message was received
            %
        elseif strncmpi( s, ')2NAV', 5 )    % NMEA string with GPS tag replaced with radio ID
            % Old format: )2NAV2,1958.8514,S,11307.4198,E,180000,
            % New format: )2NAV1,0434.2488,S,10556.0746,W,223216.000,030222,A
            %
            % NB: Lat,Lon are (degrees)(minutes).(decimal minutes)
            %
            c = strsplit( s, ',', 'CollapseDelimiters', false );
            if ~ismember( numel(c), [7 8] ) % malformed line
                continue;
            end
            
            % guard against early lines with no lat,lon
            if any( cellfun(@isempty,c(2:5)) ) 
                continue;
            end
            
            try %#ok<TRYNC>
                % If any of the conversions crash, just ignore and go on. There
                % are often malformed lines in the logs because this stuff comes
                % to the ship via slow radio modem
                assert( between( '0', s(6), '9' ) );
                assert( sub_digitsOrdot(c{2}) );
                assert( c{3} == 'N' | c{3} == 'S' );
                assert( sub_digitsOrdot(c{4}) );
                assert( c{5} == 'E' | c{5} == 'W' );
                assert( sub_digitsOrdot(c{6}) );
                assert( bOldFmt || sub_digits(c{7}) );
                
                % Allocate a new block of memory if necessary
                if iNext > size( nCuda, 1 )
                    nCuda(end+1:end+10000,:) = NaN;
                end
                
                % Stash data. If anything crashes, we just ignore the line
                nCuda(iNext,1)  = s(6) - '0';               % NAVx DeviceNo
                nCuda(iNext,2)  = iLn;                      % File line
                nCuda(iNext,3)  = DecDeg( c{2}, c{3} );     % Latitude
                nCuda(iNext,4)  = DecDeg( c{4}, c{5} );     % Longitude
                
                % Date-time handling depends on the file format
                nHMS = sscanf( c{6}, '%2d%2d%f' ).';
                if bOldFmt
                    nCuda(iNext,5)  = datenum( [nYMD nHMS] );
                    if iNext > 1
                        % Watch out for flip over of day without a *1Sync line
                        if nHMS(1) == 0 && nHMS(2) == 0 && nHMS(3) < 10 ...
                        && nCuda(iNext,5) < nCuda(iNext-1,5)
                            nCuda(iNext,5) = nCuda(iNext,5) + 1;
                            nYMD(3) = nYMD(3) + 1;
                        end
                    end
                else
                    nYMD = fliplr(onerow(sscanf( c{7}, '%2d%2d%f' )));
                    nYMD(1) = nYMD(1) + 2000; % add century
                    nCuda(iNext,5) = datenum( [nYMD nHMS] );
                end
                
                % Successful. Point at the next empty row
                iNext = iNext + 1;
            end
            
        elseif bOldFmt && strncmpi( s, '*1Sync', 6 ) % Clock line with day-of-year on it
            % *1Sync Clock:149-18:00:01
            %  Time portion is: (day-of-year)-hh:mm:ss
            c = strsplit(s,{':','-'});
            if numel(c) == 5
                nYMD(3) = str2num(c{2});
                
                % If the day has been advanced too early (sometimes lines arrive
                % at the modem out of sync because of broadcast collisions) then
                % complain that the user should edit the file
                if iNext > 1 && day( datetime(nCuda(iNext-1,5),'ConvertFrom','datenum'), 'dayofyear' ) > nYMD(3)
                    cErr{1,1} = sprintf( 'Date out of sync at line %d. Manually repair file.', iLn );
                    bOK     = false;
                    return;
                end
            end
            
        end
    end % loop through file
    
    % Chop off extra pre-allocated stuff
    nCuda(iNext:end,:) = [];
    
    % Delete invalid locations
    nCuda(abs(nCuda(:,3)) > 89 | abs(nCuda(:,4)) > 360,:) = [];
    
    % Transfer to the table
    tCuda   = cwave.GetDfltFor( 'tableCudaGPS', size(nCuda,1) );
    tCuda.Time(:)       = datetime( nCuda(:,5), 'ConvertFrom', 'datenum' );
    tCuda.DeviceNo(:)   = nCuda(:,1);
    tCuda.FileLine(:)   = nCuda(:,2);
    tCuda.Latitude(:)   = nCuda(:,3);
    tCuda.Longitude(:)  = nCuda(:,4);
    clear nCuda
    
    % Convert Lon,Lat to UTM
    if ~isempty(tCuda)
        [tCuda.East,tCuda.North] = LonLat2UTM( tCuda.Longitude, tCuda.Latitude ...
            , nUTMZone, sEllipsoid );
    end
    
    return;
end % decodeBarracudaLog

%-------------------------------------------------------------------------------
% Convert the degrees lat,lon strings to numbers. They are formatted as:
%   <degrees><decimal minutes>  E.g. 11309.7415 == 113 deg, 9.7415 minutes
function nOut = DecDeg( sIn, sHemi )

    nIn  = str2num( sIn );
    nOut = floor( nIn / 100 );
    nIn  = nIn - nOut * 100;
    nOut = nOut + nIn / 60;
    if strncmpi( sHemi, 'S', 1 ) || strncmpi( sHemi, 'W', 1 )
        nOut = -nOut;
    end
    assert( ~isnan(nOut) && isreal(nOut) );
        
    return;
end % DecDeg

%-------------------------------------------------------------------------------
% There's a LOT of crap that comes across the air-modem from the Barracudas.
% Ensure the numeric entries are ONLY numeric characters. There will never be
% negatives only 0-9 and decimal
function b = sub_digits( c )
    b = all(between('0',c,'9'));
end
function b = sub_digitsOrdot( c )
    b = all(between('0',c,'9') | c=='.');
end
