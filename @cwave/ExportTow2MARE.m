function ExportTow2MARE( oWave )
% Export towed CSEM to MARE2DEM inversion format
%
% Params:
%   oWave   - the cwave object with all the data
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    % Is there any processed towed CSEM data?
    if isempty( oWave.cFiles_TowedCSEM )
        uialert( oWave.hFig, {
            'The list of processed towed CSEM is empty.'
            'There is nothing to export.'
            }, 'Export to MARE2DEM' );
        return;
    end
    
    % Which vulcan/porpoise + towline data should be exported?
    [iExport,bOK] = listdlg( 'ListString', oWave.cFiles_TowedCSEM ...
        , 'ListSize', [400 300] ...
        , 'Name', 'Select data to export', 'PromptString', { ...
        'Select towed CSEM data files to export to MARE2DEM.'
        }, 'SelectionMode', 'multiple', 'OKString', 'Export' ...
        );
    if ~bOK     % user cancel
        return;
    end
    
    %{
    FUTURE:
        - Produce one output data file per tow line. Do this using the
        stRx.TowNo field. You have to scan all the files first to group them by
        TowNo. Then for each TowNo group, find the line center (nN0,nE0 below)
        so that the rotation/translations are the same for each input file.
        Aggregate the data for each tow, eliminate duplicate Tx positions (there
        will be some), then output the file.
        - This is probably a few days work to get right.
    %}
    
    % Ask for a folder to export to
    sOutDir = fullfile( oWave.sDir_Main, '_MARE2DEM' );
    if ~isfolder( sOutDir )
        try %#ok<TRYNC>
            mkdir( sOutDir );
        end
    end
    sOutDir = uigetdir( sOutDir, 'Select export folder' );
    if isnumeric( sOutDir ) % user cancel
        return;
    end
    
    % Get rid of old log entries
    oWave.ClearLogOfType( cwave.sLog_Towed_Export );
    
    % Create a separate .data file for each processed file. Log them.
    for iOut = onerow( iExport )
        % Create the output file name
        sIn = oWave.cFiles_TowedCSEM{iOut};
        [~,sFile] = fileparts( sIn );
        sFile = strrep( sFile, '.towedcsem', '' ); % strip 2nd extension
        sOutFile = fullfile( sOutDir, [sFile '.emdata'] );
        
        % Read in the data
        stRead = load( sIn );
        
        % Set zero,zero as the middle of the receiver locations
        nE0 = mean( stRead.tNavRx.East );
        nN0 = mean( stRead.tNavRx.North );
        
        % Move & Rotate Tx & Rx locations to be inline,crossline coordinates
        cRotTrans = {
            'Translate' [nE0 nN0]
            'Rotate' (-stRead.stRx.nTowOrient)
            };
        [xRx,yRx] = rotTrans( cRotTrans, [], stRead.tNavRx.East,    stRead.tNavRx.North );
        [xTx,yTx] = rotTrans( cRotTrans, [], stRead.tNavSuesi.East, stRead.tNavSuesi.North );
        
        % Meter precision on location is better than we can expect from nav
        xRx = round( xRx );
        yRx = round( yRx );
        xTx = round( xTx );
        yTx = round( yTx );
        
        % Format for Kerry Key's MARE2DEM
        stOut.comment = ['"' sFile '" exported from WAVE project: ' oWave.sFileName];
        stOut.stUTM.grid    = oWave.nUTMZone;
        stOut.stUTM.hemi    = oWave.cUTMHemi;
        stOut.stUTM.north0  = nN0;
        stOut.stUTM.east0   = nE0;
        stOut.stUTM.theta   = mod( stRead.stRx.nTowOrient - 90, 360 );
        
        stOut.stCSEM.phaseConvention    = 'lead';
        stOut.stCSEM.reciprocityUsed    = 'no';
        stOut.stCSEM.frequencies        = stRead.stRx.nFreqList;
        stOut.stCSEM.transmitters       = [
            xTx ...
            yTx ...
            round( stRead.tNavSuesi.Depth ) ...
            round( stRead.tNavSuesi.COG - stOut.stUTM.theta, 1 ) ...
            round( stRead.tNavSuesi.Dip, 1 )
            ];
        stOut.stCSEM.transmitters(:,6)  = oWave.nTxDipLen;  % Vulcan reqs finite dipole
        stOut.stCSEM.transmitterType    = repmat({'edipole'},height(stRead.tNavSuesi),1);
        stOut.stCSEM.receivers          = [
            xRx ...
            yRx ...
            round( stRead.tNavRx.Depth ) ...
            repmat( [0 0 0], height(stRead.tNavRx), 1 ) % theta=0 because using Ey as output data type
            ];
        
        % Create the data block - all frequencies, 2 chans (Ey+Ez), amp & phase
        iEy         = find( strcmpi( stRead.tCh.Type, 'Ey' ), 1, 'first' );
        iEz         = find( strcmpi( stRead.tCh.Type, 'Ez' ), 1, 'first' );
        nCntD       = size(stRead.nAmp,1);
        d           = zeros( nCntD, 6 );
        stOut.DATA  = zeros(0,6);
        
        for iFreq = 1:numel(stRead.stRx.nFreqList)
            d(:,1) = 23;    % Ey amplitude
            d(:,2) = iFreq;
            d(:,3) = 1:nCntD;
            d(:,4) = 1:nCntD;
            d(:,5) = stRead.nAmp(:,iEy,iFreq);
            d(:,6) = stRead.nAmpErr(:,iEy,iFreq);
            stOut.DATA = [stOut.DATA; d];
            
            d(:,1) = 24;    % Ey phase
            d(:,5) = stRead.nPhs(:,iEy,iFreq);
            d(:,6) = stRead.nPhsErr(:,iEy,iFreq);
            stOut.DATA = [stOut.DATA; d];
            
            d(:,1) = 25;    % Ez amplitude
            d(:,5) = stRead.nAmp(:,iEz,iFreq);
            d(:,6) = stRead.nAmpErr(:,iEz,iFreq);
            stOut.DATA = [stOut.DATA; d];
            
            d(:,1) = 26;    % Ez phase
            d(:,5) = stRead.nPhs(:,iEz,iFreq);
            d(:,6) = stRead.nPhsErr(:,iEz,iFreq);
            stOut.DATA = [stOut.DATA; d];
            
        end % loop through frequencies
        
        % Save the data file
        %  NB: Kerry's code doesn't return a success/failure code. Le sigh...
        try
            m2d_writeEMData2DFile( sOutFile, stOut );
            assert( isfile( sOutFile ), 'MARE2DEM''s m2d_writeEMData2DFile.m failed to create: %s', sOutFile );
        catch Me
            oWave.AddLog( cwave.LogError, cwave.sLog_Towed_Export ...
                , sprintf('Error %s: %s', Me.identifier, Me.message) );
            continue;
        end
        
        % Log it
        oWave.AddLog( cwave.LogOK, cwave.sLog_Towed_Export ...
            , sprintf('Exported %s to %s', sFile, sOutDir) );
        
    end % loop through files to export
    
    return;
end % ExportTow2MARE
