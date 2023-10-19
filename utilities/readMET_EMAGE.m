function tMET = readMET_EMAGE( cFiles, hUIFig )
% Quick function used by WAVE (via ListFmts_MET.m) to read MET info from one 
% or more files format from R/V Sikuliaq (2019 EMAGE)
%
% Params:
%   cFiles  - cell array of path+filenames to process all together
%   hUIFig  - (opt; dflt []) if given, handle to uifigure over which to use
%             uiprogressdlg to show activity.
% Returns:
%   tMET   - table with columns: Time, Pressure
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
% See also ListFmts_MET, testMET_EMAGE

    % If the file param is a single file, make it into a cell
    if ~iscell(cFiles)
        cFiles = {cFiles};
    end
    
    % Handle optional params
    if exist( 'hUIFig', 'var' ) && ~isempty( hUIFig ) && isvalid( hUIFig )
        hWait = uiprogressdlg( hUIFig, 'Title', 'Reading MET files...' );
    else
        hWait = [];
    end
    
    % Process each file
    tMET = table( 'Size', [0 2] ...
        , 'VariableNames', {'Time', 'Pressure'} ...
        , 'VariableTypes', {'datetime', 'double'} ...
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
                    tMET = [tMET;m.tblMET];
                    continue;
                end
            end
        end
        
        % Let MatLab do the heavy lifting on the read. This will read the data
        % into 3 columns: logger ID, LDS time stamp, data
        oOptIn = detectImportOptions( cFiles{iFile}, 'FileType', 'text' ...
            , 'NumHeaderLines', 24, 'Delimiter', char(9) ...
            , 'ReadVariableNames', false, 'ImportErrorRule', 'omitrow' );
        cCols = readmatrix( cFiles{iFile}, oOptIn );
        
        % Convert the datetimes & headings
        iOut               = (1:size(cCols,1)) + height(tMET);
        tMET{iOut,:}       = missing();
        tMET.Time(iOut)    ...
            = cellfun( @(c)datetime(onerow(sscanf( c, '%d-%d-%dT%d:%d:%fZ' ))), cCols(:,2) );
        
        % Pull the pressure part out of the format
        tMET.Pressure(iOut) = cellfun( @(c)str2num(c(11:18)), cCols(:,3) );
        
        % Save a shortcut file so we don't have to do this again. It takes a
        % lot of time.
        tblMET = tMET(iOut,:);
        save( sShortcut, 'tblMET' );
        clear tblMET
        
    end % loop through files
    
    % Sort
    tMET = sortrows( tMET, 'Time' );
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readMET_EMAGE
