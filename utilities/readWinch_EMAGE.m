function tWinch = readWinch_EMAGE( cFiles, hUIFig )
% Quick function used by WAVE (via ListFmts_Winch.m) to read Winch info from one 
% or more files format from R/V Sikuliaq (2019 EMAGE)
%
% Params:
%   cFiles  - cell array of path+filenames to process all together
%   hUIFig  - (opt; dflt []) if given, handle to uifigure over which to use
%             uiprogressdlg to show activity.
% Returns:
%   tWinch   - table with columns: Time, WireOut (heading)
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
% See also ListFmts_Winch, testWinch_EMAGE

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
                    tWinch = [tWinch;m.tblWinch];
                    continue;
                end
            end
        end
        
        % Let MatLab do the heavy lifting on the read. This will read the data
        % into 3 columns: logger ID, LDS time stamp, data
        oOptIn = detectImportOptions( cFiles{iFile}, 'FileType', 'text' ...
            , 'NumHeaderLines', 8, 'Delimiter', char(9) ...
            , 'ReadVariableNames', false, 'ImportErrorRule', 'omitrow' );
        cCols = readmatrix( cFiles{iFile}, oOptIn );
        
        % Only process the proper winch lines
        %{
            @RCWD,2,3,103.64,0.42,-29.95,0,102.96,0.294791*3d
                ID [@RCWD]
                Winch Number [1, 2, 6, 7]
                Winch Mode [1=manual, 2=auto_payout, 3=auto_haulin]
                Length [meters] - motor calculated
                Tension [metric tons] - motor calculated
                Velocity [meters per minute]
                Alarm
                Length [meters] - block counting
                Tension [metric tons] - load cell
                CheckSum
        %}
        bWant = cellfun( @(c)strncmpi(c,'@RCWD,6',7), cCols(:,3) );
        cCols(~bWant,:) = [];
        
        % Convert the datetimes & headings
        iOut                 = (1:size(cCols,1)) + height(tWinch);
        tWinch{iOut,:}       = missing();
        tWinch.WireOut(iOut) = cellfun( @(c)sscanf(c,'@RCWD,6,%*d,%f'), cCols(:,3) );
        tWinch.Time(iOut)    ...
            = cellfun( @(c)datetime(onerow(sscanf( c, '%d-%d-%dT%d:%d:%fZ' ))), cCols(:,2) );
        
        % Save a shortcut file so we don't have to do this again. It takes a
        % lot of time.
        tblWinch = tWinch(iOut,:);
        save( sShortcut, 'tblWinch' );
        clear tblWinch
        
    end % loop through files
    
    % Sort
    tWinch = sortrows( tWinch, 'Time' );
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readWinch_EMAGE
