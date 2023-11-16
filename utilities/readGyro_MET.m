function tGyro = readGyro_MET( cFiles, hUIFig )
% tGyro = readGyro_MET( cFiles, hUIFig )
%
% Read & parse one or more Gyro info files from processed MET files created by
% the cwave::ProcessSIOMETFiles() function.
% 
% Params:
%   cFiles      - cell array of path+filenames to process all together
%   hUIFig      - (opt; dflt []) if given, handle to uifigure over which to use
%               uiprogressdlg to show activity.
% Returns:
%   tGyro      - table with variables: Time, Gyro
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
% See also ListFmts_Gyro, testGyro_MET, ProcessSIOMETFiles, MET2Table

    % If the file param is a single file, make it into a cell
    if ~iscell(cFiles)
        cFiles = {cFiles};
    end
    
    % Handle optional params
    if exist( 'hUIFig', 'var' ) && ~isempty( hUIFig ) && isvalid( hUIFig )
        hWait = uiprogressdlg( hUIFig, 'Title', 'Reading Gyro files...' );
    else
        hWait = [];
    end
    
    % Process each file
    tGyro = table( 'Size', [0 2] ...
        , 'VariableNames', {'Time', 'Gyro'} ...
        , 'VariableTypes', {'datetime', 'double'} ...
        );
    for iFile = 1:numel(cFiles)
        if ~isempty( hWait ) && isvalid( hWait )
            hWait.Value     = (iFile - 1) / numel(cFiles);
            [~,f,e]         = fileparts( cFiles{iFile} );
            hWait.Message   = ['Processing ' f e];
        end
        
        % Let MatLab do the heavy lifting on the read
        tbl = readtable( cFiles{iFile}, 'FileType', 'text', 'Delimiter', ',' );
        
        % Convert to simple matrix and datenum
        tGAdd      = copytable( tGyro, height(tbl) );
        tGAdd.Time = tbl.Time;
        if any( strcmpi( tbl.Properties.VariableNames, 'Gyro' ) )   % col can be either 'Gyro' or 'Gyrocompass'
            tGAdd.Gyro = tbl.Gyro;
        else
            tGAdd.Gyro = tbl.Gyrocompass;
        end
        
        % Combine data
        tGyro = cat( 1, tGyro, tGAdd );
    end
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readGyro_MET
