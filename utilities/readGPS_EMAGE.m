function tGPS = readGPS_EMAGE( cFiles, hUIFig )
% Quick function used by WAVE (via ListFmts_GPS.m) to read GPS info from one or
% more files in ins_seapath_position format from R/V Sikuliaq (2019 EMAGE)
%
% Params:
%   cFiles  - cell array of path+filenames to process all together
%   hUIFig  - (opt; dflt []) if given, handle to uifigure over which to use
%             uiprogressdlg to show activity.
% Returns:
%   tGPS    - table with columns: Time, Lat, Lon
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
% See also ListFmts_GPS, testGPS_EMAGE

    % If the file param is a single file, make it into a cell
    if ~iscell(cFiles)
        cFiles = {cFiles};
    end
    
    % Handle optional params
    if exist( 'hUIFig', 'var' ) && ~isempty( hUIFig ) && isvalid( hUIFig )
        hWait = uiprogressdlg( hUIFig, 'Title', 'Reading GPS files...' );
    else
        hWait = [];
    end
    
    % Process each file
    iOut = 1;
    tGPS = table( 'Size', [100000 3] ...
        , 'VariableNames', {'Time', 'Lat', 'Lon'} ...
        , 'VariableTypes', {'datetime', 'double', 'double'} ...
        );
    for iFile = 1:numel(cFiles)
        if ~isempty( hWait ) && isvalid( hWait )
            hWait.Value     = (iFile - 1) / numel(cFiles);
            [~,f,e]         = fileparts( cFiles{iFile} );
            hWait.Message   = ['Processing ' f e];
        end
        
        % Processing these LDS files can take a considerable amount of time. So
        % having to re-process them is a bugger. Instead, I save a .mat file
        % with the already processed data for faster re-processing.
        sShortcut = [cFiles{iFile} '.mat'];
        if isfile( sShortcut )
            stDir1 = dir( cFiles{iFile} );
            stDir2 = dir( sShortcut );
            if stDir2.datenum > stDir1.datenum % .mat is newer
                try %#ok<TRYNC>
                    m = matfile( sShortcut );
                    tGPSAdd = m.tblGPS;
                    iAt = (1:height(tGPSAdd)) + iOut;
                    tGPS(iAt,:) = tGPSAdd;
                    iOut = iOut + height(tGPSAdd);
                    continue;
                end
            end
        end
        
        % Let MatLab do the heavy lifting on the read. This will read the data
        % into 3 columns: logger ID, LDS time stamp, NMEA data
        oOptIn = detectImportOptions( cFiles{iFile}, 'FileType', 'text' ...
            , 'NumHeaderLines', 8, 'Delimiter', char(9) ...
            , 'ReadVariableNames', false, 'ImportErrorRule', 'omitrow' );
        cCols = readmatrix( cFiles{iFile}, oOptIn );
        
        % Since we have the LDS time stamp, I don't need all the various NMEA
        % strings, just the Geographic Lat Lon
        bWant = cellfun( @(c)strncmpi(c,'$GPGLL',6), cCols(:,3) );
        cCols(~bWant,:) = [];
        
        % Loop through the data
        iStart = iOut;
        for iLn = 1:size(cCols,1)
            % Parse this NMEA. Do we want it?
            [nRtnCode, nGPS, colGPS] = parseNMEA( cCols{iLn,3} );
            if nRtnCode ~= 0 || isnan( nGPS(1,colGPS.Lon) )
                continue;
            end
            
            % Stash GPS data. Use LDS time. It should be identical to that
            % in the NMEA line, but just in case it isn't, this ensures
            % that everything is in the same frame of reference.
            nYMDHMS = onerow( sscanf( cCols{iLn,2}, '%d-%d-%dT%d:%d:%fZ' ) );
            tGPS.Time(iOut) = datetime( nYMDHMS );
            tGPS.Lat(iOut)  = nGPS(1,colGPS.Lat);
            tGPS.Lon(iOut)  = nGPS(1,colGPS.Lon);
            
            % Increment output pointer
            iOut = iOut + 1;
            
            % Pre-allocate another block if needed
            if iOut > height(tGPS)
                tGPS{iOut:iOut+50000,:} = missing();
            end
        end % loop through lines from one file
        
        % Save a shortcut file so we don't have to do this again. It takes a
        % lot of time.
        tblGPS = tGPS(iStart:(iOut-1),:);
        save( sShortcut, 'tblGPS' );
        clear tblGPS
        
    end % loop through files
    
    % Get rid of extra pre-allocated data
    tGPS(iOut:end,:) = [];
    
    % Sort
    tGPS = sortrows( tGPS, 'Time' );
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readGPS_EMAGE
