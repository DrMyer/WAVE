function [nMet,colMet] = readMET( sFileList, bQuiet, hParent, bUseNaNs )
% [nMet,colMet] = readMET( sFileList ) - read a ship's MET files
% ("meteorological" data) and return as a matrix along with a structure that
% tells what columns have been included.
%
% DGM May 2009; updated 2022-3
%
% Params:
%   sFileList   - single path+file or cell array of them to read.
%   bQuiet      - t/f whether stuff should be spewed to the cmd window.
%                   Can be 'Quiet' = True
%   hParent     - (opt; dflt []) if given, MUST be a uifigure. uiprogressdlg()
%                   is used on top of hParent to show progress
%   bUseNaNs    - (opt; dflt 0) if true, certain columns will have their "not
%               valid" values changed to NaN. Valid entries for this param:
%                   true/false/'UseNaNs'/'NoNaNs'
%
% Returns:
%   nMet    - matrix of MET data. Columns depend on the files loaded.
%   colMet  - names of the columns of nMet. These names are taken directly
%           from the MET file's header and are usually 2-char codes (such as
%           GY for Gyro compass, CR for GPS Course-over-ground) sometimes
%           with a "_1" or "_2" ....  The full list of these codes is found
%           in the "MetAcq.pdf" which accompanies the data.  See appendix A.
%           All column names will be FORCED TO UPPERCASE.
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
% See also MET2Table

    % For convenience, ensure that sFileList is a cell array.
    if ~iscell(sFileList)
        sFileList = {sFileList};
    end
    if ~exist( 'bQuiet', 'var' ) || isempty( bQuiet )
        bQuiet = false;
    elseif ischar( bQuiet )
        bQuiet = strncmpi( bQuiet, 'Q', 1 );
    end
    if ~exist( 'hParent', 'var' ) || isempty( hParent )
        hParent = NaN;
    end
    if ~exist( 'bUseNaNs', 'var' ) || isempty( bUseNaNs )
        bUseNaNs = false;
    elseif ischar( bUseNaNs )
        bUseNaNs = strncmpi( bUseNaNs, 'U', 1 );
    end
    
    % Sort the file list!!
    sFileList = sort(sFileList);
    
    % Init return vars
    nMet    = [];
    colMet  = [];
    
    % If given a uifigure, show a progress bar
    if ishandle( hParent )
        oProg = uiprogressdlg( hParent, 'Title', 'Reading MET files...' );
    else
        oProg = NaN;
    end
    
    % For each file...
    nFieldCnt= 0;
    sPrevHdr = [];
    for iFile = 1:numel(sFileList)
        sFile = sFileList{iFile};
        if ~bQuiet
            disp( ['Processing ' sFile ' ...'] );
        end
        if ishandle( hParent )
            oProg.Value     = iFile / numel(sFileList);
            oProg.Message   = {sprintf( 'File %d/%d', iFile, numel(sFileList) ); sFile};
        end
        
        % Does the file exist?
        if ~exist( sFile, 'file' )
            error( ['readMET cannot find file ' sFile] );
        end
        
        % Read the file header. If this isn't the first file, then is must
        % match the header from the first file EXACTLY or the file cannot be
        % put into the same matrix (columns won't match!).
        %   According to the manual, there are 4 header lines, the last of
        % which contains the column headers.
        fid = fopen( sFile, 'r' );
        if bQuiet
            fgetl(fid);
            fgetl(fid);
            fgetl(fid);
        else
            disp( ['   ' fgetl(fid)] );
            disp( ['   ' fgetl(fid)] );
            disp( ['   ' fgetl(fid)] );
        end
        sHdr = fgetl(fid);
        if iFile > 1 && ~strcmpi(sHdr,sPrevHdr)
            if ~bQuiet
                disp( 'ERROR: Cannot merge this file with the previous because' );
                disp( '       the column headers don''t match!' );
                disp(['  Old Hdr: ' sPrevHdr] );
                disp(['  New Hdr: ' sHdr] );
            end
            error( 'Mismatched MET file headers!' );
        end
        
        % If this is the first file, parse the header into columns
        if iFile == 1
            sPrevHdr = sHdr;
            c = split( sHdr(2:end) ); % skip beginning "#"
            
            % Force uppercase and convert dashes to underscores.
            c           = strrep( upper(c), '-', '_' );
            nFieldCnt   = length(c);
            
            % Populate the structure
            for i = 1:nFieldCnt
                colMet.(c{i}) = i;
            end
        end
        
        % Read the file data
        % NB: fscanf() below will read all numbers as a single column
        nData   = reshape( fscanf( fid, '%g', inf ), nFieldCnt, [] ).';
        if ~bQuiet
            disp(['   Read ' num2str(size(nData,1)) ' lines.'] );
        end
        
        % Convert the time column into a MatLab datetime number.  The date
        % is in the met filename.
        [~,f,~] = fileparts(sFile);
        nDate   = datenum( sprintf('%s/%s/20%s', f(3:4), f(5:6), f(1:2)) );
        nTime   = nData(:,colMet.TIME);
        nHr     = floor( nTime / 10000 );
        nMin    = floor( (nTime - nHr*10000) / 100 );
        nSec    = mod( nTime, 100 );
        nData(:,colMet.TIME)    =  nDate + nHr / 24 + nMin / 1440 + nSec / 86400;
        clear nTime nHr nMin nSec f
        
        % Add to the output matrix
        nMet(end+1:end+size(nData,1),:) = nData;
        clear nData
        
        % Cleanup
        fclose(fid);
    end % loop through files
    if ishandle( hParent )
        close( oProg );
    end
    
    % Some fields use -99 to indicate NaN. Update that now
    if bUseNaNs
        cFlds = fieldnames( colMet );
        for cCode = {'OC','OT','OS','OX','WT','BT','SH','SM','SR'}
            for iCol = reshape( find( strncmpi( cFlds, cCode{1}, 2 ) ), 1, [] )
                bChg = (nMet(:,iCol) == -99);
                if any(bChg)
                    nMet(bChg,iCol) = NaN;
                end
            end
        end
    end
    
    return
end % readMET
