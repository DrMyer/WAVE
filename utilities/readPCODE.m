function [nGPS, colGPS] = readPCODE( cFiles, bReqLL, bUseMat, hUIFig )
% [nGPS, colGPS] = readPCODE( cFiles, bReqLL, bUseMat, hUIFig )
%
% Parse the ship's position from files that use NMEA GPS reporting
%
% David Myer, June 2009
% DGM: Minor overhaul 2/2023 for use with WAVE
%
% Params:
%   cFiles  - EITHER string folder+filename OR cell array of same
%   bReqLL  - (opt; dflt=false) if true or 'ReqLatLon', only keeps lines with 
%               lat & lon data
%   bUseMat - (opt; dflt=true) if true or 'UseMat', will make a .MAT file the 
%               first time a file is seen then use that .mat on subsequent calls
%   hUIFig  - (opt; dflt []) if a handle is given, it is assumed to be to a
%               uifigure (not figure). Progress is shown with a uiprogressbar
%               instead of the old waitbar and output to the command window is
%               generally suppressed
%
% Returns:
%   nGPS    - a matrix of GPS location & time data from only the NMEA
%           	sentences parsed by parseNMEA.m
%   colGPS  - a structure with the column names & numbers inside nGPS
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
% See also parseNMEA
    
    % If only one file is given, make a cell array anyway for simplicity
    if ~iscell(cFiles)
        cFiles = {cFiles};
    end
    
    % Handle optional parameters
    if ~exist('bReqLL','var') || isempty(bReqLL)
        bReqLL = false;
    elseif ischar( bReqLL )
        bReqLL = strncmpi( bReqLL, 'ReqLatLon', 4 );
    end
    if ~exist('bUseMat','var') || isempty(bUseMat)
        bUseMat = true;
    elseif ischar( bUseMat )
        bUseMat = strncmpi( bUseMat, 'UseMAT', 6 );
    end
    if ~exist('hUIFig','var') || isempty( hUIFig )
        bUIFig = false;
    else
        bUIFig = isvalid( hUIFig );
    end
    
    % Get the # of columns and pre-allocate return data.  This is MUCH faster
    % than adding one row at a time.
    [~,~,colGPS] = parseNMEA( 'FakeLine' );
    nGPS = NaN(1000000,length(fieldnames(colGPS)));
    iGPS = 0;
    
    % Create the progress window once
    if bUIFig
        hWait = uiprogressdlg( hUIFig, 'Title', 'Processing GPS NMEA data ...' );
    else
        hWait = waitbar( 0, 'Processing GPS NMEA data ...' );
    end
    
    % Process all the given files.
    for iFile = 1:numel(cFiles)
        % Update the progress window's message
        [~,f,e] = fileparts( cFiles{iFile} );
        if bUIFig
            hWait.Value   = 0;
            hWait.Message = [f e sprintf(' (%d/%d)', iFile, numel(cFiles)) ];
        else
            waitbar( 0, hWait, ['Processing NMEA from ' f e ' ...'] );
            disp( ['Processing NMEA from ' cFiles{iFile} ' ...'] );
        end
        
        % If a .mat file exists, use it
        if bUseMat
            sMat = [cFiles{iFile} '.mat'];
            if isfile( sMat )
                if ~bUIFig
                    disp( '  ... loading from previous .MAT file.' );
                end
                m                               = matfile( sMat );
                nGPS(iGPS+(1:size(m.nGPS,1)),:) = m.nGPS;
                iGPS                            = iGPS + size(m.nGPS,1);
                clear m % close the matfile object
                continue;
            else
                iSaveFrom = iGPS + 1;
            end
        end
        
        % Track progress by the byte position in the file
        fid = fopen( cFiles{iFile}, 'r' );
        fseek( fid, 0, 'eof' );
        nBytesTot = ftell(fid);
        fseek( fid, 0, 'bof' );
        
        % Loop through the unstructured text file line-by-line
        nOK   = 0;
        nSkip = 0;
        nErr  = 0;
        nLastPct    = 0;
        nLastDate   = 0;
        while ~feof(fid)
            
            % Read the next line
            s = fgetl( fid );
            if ~ischar(s)       % happens at eof if file is completely empty
                break;
            end
            if isempty(s)
                continue;
            end
            
            % Report progress
            nCurPct = round(ftell(fid)/nBytesTot*100);
            if nCurPct ~= nLastPct
                nLastPct = nCurPct;
                if bUIFig
                    hWait.Value = ftell(fid) / nBytesTot;
                else
                    waitbar( ftell(fid) / nBytesTot, hWait );
                end
            end
            
            % Parse one line
            [nCode, nData, colGPS] = parseNMEA( s, nLastDate );
            if nData(colGPS.Date) > 1 % has a date. Save for lines that only have time
                nLastDate = floor(nData(colGPS.Date));
            end
            if bReqLL && any(isnan(nData([colGPS.Lon colGPS.Lat])))
                nCode = 1;
            end
            
            % Put data into our block
            switch( nCode )
                case 0      % parsed OK
                    iGPS = iGPS + 1;
                    if iGPS > size(nGPS,1)
                        % Allocate another block of lines
                        nGPS(end+1:end+500000,:) = NaN;
                    end
                    nGPS(iGPS,:)   = nData;
                    nOK = nOK + 1;
                    
                case 1      % not a useful NMEA string
                    nSkip = nSkip + 1;
                    
                otherwise   % Error
                    disp( ['!!Error parsing NMEA: ' s] );
                    nErr = nErr + 1;
            end
            
        end % loop through one file, line-by-line
        
        % Report details on this file, but only for older uses of this code
        if ~bUIFig
            disp( ['  ' num2str(nOK) ' sentences used.'] );
            disp( ['  ' num2str(nSkip) ' sentences skipped.'] );
            disp( ['  ' num2str(nErr) ' sentences errored.'] );
        end
        
        % If .mat file usage requested, save this processed data for next time
        if bUseMat
            st.colGPS = colGPS;
            st.nGPS   = nGPS(iSaveFrom:iGPS,:);
            save( sMat, '-struct', 'st' );
            clear st
        end
    end % loop through list of files
    
    % Delete the progress window (if the user didn't already do it)
    if isvalid( hWait )
        delete( hWait );
    end
    
    % Drop any extra lines at the end
    if iGPS < size(nGPS,1)
        nGPS(iGPS+1:end,:) = [];
    end
    
    return;
end % readPCODE
