function tWinch = readWinch_Revelle( cFiles, hUIFig )
% tWinch = readWinch_Revelle( cFiles, hUIFig )
%
% Read & parse one or more winch info files from ship data. Has only been tested
% against the R/V Revelle Trawl winch. Based on the old readWinch.m
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
        [nSec nMS nWO] = textread( cFiles{iFile}, '%f %f S%fV%*fT%*fX%*f:' );
        
        % Some of these files have very negative spurious points. But note that
        % a small negative can be OK depending on where the cable was zeroed.
        bDel = nWO < -50;
        if any(bDel)
            nSec(bDel) = [];
            nMS(bDel)  = [];
            nWO(bDel)  = [];
        end

        % Date is given as "posix seconds" which is seconds since 1/1/1970
        tWAdd           = copytable( tWinch, numel(nSec) );
        tWAdd.Time      = datetime('01-Jan-1970') + nSec/86400 + nMS/86400000;
        tWAdd.WireOut   = nWO;
        
        % Combine data
        tWinch = cat( 1, tWinch, tWAdd );
    end
    
    % close the progress dialog
    if ~isempty( hWait ) && isvalid( hWait )
        delete( hWait );
    end

    return;
end % readWinch_Revelle
