function tWinch = readWinch_GOFAR( cFiles, hUIFig )
% tWinch = readWinch_GOFAR( cFiles, hUIFig )
%
% Read & parse one or more winch info files from ship data in the format found
% in GOFAR from R/V Thompson
% 
% Params:
%   cFiles      - cell array of path+filenames to process all together
%   hUIFig      - (opt; dflt []) if given, handle to uifigure over which to use
%               uiprogressdlg to show activity.
% Returns:
%   tWinch      - table with variables: Time, WireOut
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

    % If the file param is a single file, make it into a cell
    if ~iscell(cFiles)
        cFiles = {cFiles};
    end
    
    % Handle optional params
    if exist( 'hUIFig', 'var' ) && ~isempty( hUIFig ) && isvalid( hUIFig )
        hWait = uiprogressdlg( hUIFig, 'Title', 'Reading Winch files...' );
    else
        hWait = [];
    end
    
    % Process each file
    tWinch = table( 'Size', [0 2] ...
        , 'VariableNames', {'Time', 'WireOut'} ...
        , 'VariableTypes', {'datetime', 'double'} ...
        );
    for iFile = 1:numel(cFiles)
        if ~isempty( hWait ) && isvalid( hWait )
            hWait.Value     = (iFile - 1) / numel(cFiles);
            [~,f,e]         = fileparts( cFiles{iFile} );
            hWait.Message   = ['Processing ' f e];
        end
        
        % Let MatLab do the heavy lifting on the read
        tbl = readtable( cFiles{iFile}, 'FileType', 'text' ...
            , 'Format', '%{MM/dd/yyyy}D %T %*f %f' ...
            , 'Delimiter', ',' );
        
        % Convert to simple matrix and datenum
        tWAdd           = copytable( tWinch, height(tbl) );
        tWAdd.Time      = tbl.Var1 + tbl.Var2;
        tWAdd.WireOut   = tbl.Var3;
        
        % Combine data
        tWinch = cat( 1, tWinch, tWAdd );
    end
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readWinch_GOFAR
