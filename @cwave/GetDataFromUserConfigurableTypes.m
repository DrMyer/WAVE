function [bOK, nData] = GetDataFromUserConfigurableTypes( oWave, cFiles, tbl, sLog, sType )
% [bOK, nData] = GetDataFromUserConfigurableTypes( oWave, cFiles, tbl, sLog, sType )
%
% Read data from a list of files using user configurable type information to
% interpret the contents of the file and return it.
%
% Parameters:
%   oWave   - main cwave object
%   cFiles  - list of files to load
%   tbl     - table of types & fcns from ListFmts_Winch, ListFmts_GPS, etc...
%   sLog    - cwave.sLog_... type to log entries
%   sType   - simple text description for logs. E.g. 'GPS', 'Winch', etc...
%
% Returns:
%   bOK     - T/F did the process succeed. If not, error already logged
%   nData   - matrix of read-in data.
%
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    
    % Default the return vars
    bOK   = true;
    nData = [];
    
    % Get the format for each file
    [~,iFileType] = isFile_FromTable( cFiles, tbl );
    
    % Process the files in groups according to their type. The read functions
    % take whole lists of files and put up progress through the file list. It is
    % unlikely there will be more than one type of input file so this means that
    % one progress window goes up and stays up through all the files instead of
    % flashing on/off for each file.
    for iType = 1:height(tbl)
        bType = (iFileType == iType);
        if ~any( bType )    % no files of this type, skip
            continue;
        end
        fcnRead = tbl.fcnRead{iType};
        try
            % Run all input files as one group
            nDataAdd = fcnRead( cFiles(bType), oWave.hFig );
            
            % If we got anything, log it
            if ~isempty( nDataAdd )
                if isempty( nData )
                    % NB: nDataAdd might be a table not a double matrix
                    nData = nDataAdd;
                else
                    nData = cat( 1, nData, nDataAdd );
                end
                oWave.AddLog( oWave.LogOK, sLog ...
                    , sprintf( 'Added %d lines from %s files of type "%s"' ...
                             , size(nDataAdd,1), sType, tbl.Name(iType) ) ...
                    );
            end
        catch Me
            % If it crashed, log the error and stop
            bOK = false;
            oWave.AddLog( oWave.LogError, sLog ...
                , sprintf( 'Error %s type "%s":: %s:%s' ...
                         , sType, tbl.Name(iType), Me.identifier, Me.message ) );
            sStack = '';
            for iStack = 1:numel(Me.stack)
                sStack = [sStack sprintf( ';%s (%d)', Me.stack(iStack).name, Me.stack(iStack).line )];
            end
            oWave.AddLog( oWave.LogError, sLog, sStack(2:end) );
            break;
        end
    end % loop through known types
    
    % If no data was found, that's an error
    if bOK && isempty( nData )
        oWave.AddLog( oWave.LogError, sLog, ['No ' sType ' data found.'] );
        bOK = false;
        return;
    end
    
    return;
end % GetDataFromUserConfigurableTypes
