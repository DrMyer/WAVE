function tGPS = readGPS_GGA_Raw( cFiles, hUIFig )
% Quick function used by WAVE (via ListFmts_Master.m) to read GPS info from one
% or more files in the "raw GGA" format.
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
% See also ListFmts_GPS, testGPS_GGA_Raw

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
    tGPS = table( 'Size', [0 3] ...
        , 'VariableNames', {'Time', 'Lat', 'Lon'} ...
        , 'VariableTypes', {'datetime', 'double', 'double'} ...
        );
    for iFile = 1:numel(cFiles)
        if ~isempty( hWait ) && isvalid( hWait )
            hWait.Value     = (iFile - 1) / numel(cFiles);
            [~,f,e]         = fileparts( cFiles{iFile} );
            hWait.Message   = ['Processing ' f e];
        end
        
        % Let MatLab do the heavy lifting on the read
        %
        % NB: Assume $INGGA or $GPGGA in the 3rd column. Don't bother reading &
        % verifying. It takes too long
        tbl = readtable( cFiles{iFile}, 'FileType', 'text' ...
            , 'Format', '%{MM/dd/yyyy}D %T %*q %*f %f %q %f %q %*q %*q %*q %*q %*q %*q %*q %*q %*q' ...
            , 'Delimiter', ',' );
        
        % Convert to simple matrix and datenum
        tGPSAdd = table( 'Size', [height(tbl) 3] ...
            , 'VariableNames', {'Time', 'Lat', 'Lon'} ...
            , 'VariableTypes', {'datetime', 'double', 'double'} ...
            );
        tGPSAdd.Time = tbl.Var1 + tbl.Var2;
        tGPSAdd.Lat  = Cvt_degminfrac( tbl.Var3, tbl.Var4 );
        tGPSAdd.Lon  = Cvt_degminfrac( tbl.Var5, tbl.Var6 );
        
        % Combine data
        tGPS = cat( 1, tGPS, tGPSAdd );
    end
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readGPS_GGA_Raw
