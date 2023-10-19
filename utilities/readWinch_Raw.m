function tWinch = readWinch_Raw( cFiles, hUIFig )
% tWinch = readWinch_Raw( cFiles, hUIFig )
%
% Read & parse one or more winch info files from ship data in the raw format
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
        %
        % NB: .Raw format files sometimes have shortened "no data" rows in them.
        % It lookes like this:
%{
02/03/2022,14:26:55.657,03RD,2022-02-03T14:52:55.755,00000135,000000.0,-00004.5,2834
02/03/2022,14:26:55.720,03RD,2022-02-03T14:52:55.806,00000132,000000.0,-00004.5,2828
02/03/2022,14:26:55.782,03RD,2022-02-03T14:52:55.856,00000124,000000.0,-00004.5,2834
02/03/2022,14:26:55.782,03RR,307
02/03/2022,14:26:55.829,03RD,2022-02-03T14:52:55.907,00000086,000000.0,-00004.5,2838
02/03/2022,14:26:55.829,03RA,290
02/03/2022,14:26:55.876,03RD,2022-02-03T14:52:55.957,00000167,000000.0,000000.0,2837
02/03/2022,14:26:55.923,03RD,2022-02-03T14:52:56.000,00000151,000000.0,000000.0,2810
%}
        %
        % Code below blows up on some files. Need to do it the verbose way.
        % Don't know why you can't specify the various "Rule" options directly
        % in a call to readtable.
        %
        % tbl = readtable( cFiles{iFile}, 'FileType', 'text' ...
        %     , 'Format', '%{MM/dd/yyyy}D %T %*q %*q %*f %*f %f %*q' ...
        %     , 'Delimiter', ',' );
        % tbl(ismissing(tbl.Var3),:) = []; % deal with shortened rows
        
        opts = detectImportOptions( cFiles{iFile} ...
            , 'FileType', 'text' ...
            , 'Delimiter', ',' ...
            , 'ExpectedNumVariables', 8 ...
            , 'MissingRule', 'omitrow' ...
            , 'ImportErrorRule', 'omitrow' ... 
            , 'ExtraColumnsRule', 'ignore' );
        opts = setvaropts( opts, 1, 'InputFormat', 'MM/dd/yyyy' );
        tbl = readtable( cFiles{iFile}, opts );
        
        % Convert to simple matrix and datenum
        tWAdd           = table( 'Size', [height(tbl) 2] ...
            , 'VariableNames', {'Time', 'WireOut'} ...
            , 'VariableTypes', {'datetime', 'double'} ...
            );
        tWAdd.Time      = tbl.Var1 + tbl.Var2;
        tWAdd.WireOut   = tbl.Var7;
        
        % Combine data
        tWinch = cat( 1, tWinch, tWAdd );
    end
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readWinch_Raw
