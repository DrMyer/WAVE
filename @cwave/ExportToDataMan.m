function ExportToDataMan( oWave )
% Export nodal CSEM to Dataman for plotting, trimming, etc...
%
% Params:
%   oWave   - the cwave object with all the data
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    % Is there any processed Nodal CSEM?
    if isempty( oWave.cFiles_NodalCSEM )
        uialert( oWave.hFig, {
            'The list of processed nodal CSEM is empty.'
            'There is nothing to export.'
            }, 'Export to DataMan' );
        return;
    end
    
    % Create the output filename. Prompt user to confirm overwrite
    sOutDM = fullfile( oWave.sDir_Main, [oWave.sFileName '.dm']);
    if isfile( sOutDM )
        if ~strcmpi( 'Overwrite', uiconfirm( oWave.hFig, {
            'The destination DataMan file already exists.'
            'Do you want to overwrite it?'
            ''
            sOutDM
            }, 'Export to DataMan', 'Options', {'Overwrite', 'Cancel'} ) )
            return;
        end
    end
    
    % Get rid of old log entries
    oWave.ClearLogOfType( cwave.sLog_Nodal_DM );
    
    % Create the empty DataMan structure and fill in all the header that we can
    st = dm_EnforceMinStruct([]);
    st.nUTMZone = oWave.nUTMZone;
    st.sUTMHemi = oWave.cUTMHemi;
    st.sDatum   = char( oWave.sEllipsoid );
    st.listChan = {};
    st.listFreq = [];
    
    % Walk the list of CSEM data files and drop each one into the structure
    oProg = uiprogressdlg( oWave.hFig, 'Title', 'Export to DataMan', 'Cancelable', 'on' );
    cErr = {};
    iD = 1;
    for iFile = 1:numel( oWave.cFiles_NodalCSEM )
        % Update progress & look for user cancel
        if oProg.CancelRequested
            cErr{end+1,1} = 'User Canceled';
            break;
        end
        oProg.Value = (iFile-1) / numel( oWave.cFiles_NodalCSEM );
        oProg.Message = oWave.cFiles_NodalCSEM{iFile};
        
        try
            m = load( oWave.cFiles_NodalCSEM{iFile} );
            
            % Header info
            st.d(iD).cType      = 'C';
            st.d(iD).sRxName    = char(m.stRx.RxName);
            st.d(iD).RxN        = m.stRx.North;
            st.d(iD).RxE        = m.stRx.East;
            st.d(iD).RxZ        = m.stRx.Depth;
            st.d(iD).RxOrientX  = m.stRx.nOrientX;
            st.d(iD).CSEMMinErr = 0.02; % Two pct is typical. Can be easily changed in DataMan
            st.d(iD).FreqList   = reshape( oWave.tableHarmonics.Frequency, 1, [] );
            st.d(iD).cChan      = reshape( {m.tCh.Type{:}}, 1, [] ); %#ok<CCAT1>
            st.d(iD).bLag       = false;
            st.d(iD).bMagDipole = false;
            st.d(iD).TxLineNo   = m.stRx.TowNo;
            st.d(iD).TxDipLen   = oWave.nTxDipLen;
            st.d(iD).RxDipLen   = round( reshape( m.tCh.DipLen, 1, [] ), 3 );
            iX = find( ismember( m.tCh.Type, ["Hx", "Ex"] ), 1, 'first' );
            iY = find( ismember( m.tCh.Type, ["Hy", "Ey"] ), 1, 'first' );
            if isempty(iX)
                st.d(iD).RxDipX = 0;
            else
                st.d(iD).RxDipX = m.tCh.Tilt(iX);
            end
            if isempty(iY)
                st.d(iD).RxDipY = 0;
            else
                st.d(iD).RxDipY = m.tCh.Tilt(iY);
            end
            
            % Transmitter navigation
            st.d(iD).TxN        = m.tNav.North;
            st.d(iD).TxE        = m.tNav.East;
            st.d(iD).TxZ        = m.tNav.Depth;
            st.d(iD).TxEofN     = m.tNav.COG;
            st.d(iD).TxDip      = m.tNav.Dip;
            st.d(iD).TxAlt      = m.tNav.Altitude;
            st.d(iD).RangeH     = m.tNav.Range;
            st.d(iD).RangeAbs   = abs(m.tNav.Range);
            st.d(iD).TrackDist  = m.tNav.AlongTrack;
            
            % Data
            st.d(iD).TF         = m.nTF;            % dim(time,chan,freq)
            st.d(iD).StdDev     = abs( sqrt( m.nVar ) ); % force +0i to go away
            st.d(iD).Amp        = abs( st.d(iD).TF );
            st.d(iD).Phi        = 180/pi() * angle( st.d(iD).TF );
            st.d(iD).DelAmp     = NaN(size(m.nTF));
            st.d(iD).DelPhi     = NaN(size(m.nTF));
            
            % Let DataMan set the display name
            st.d(iD).sDisp      = dm_DispName( st, iD );
            
            % On load, DataMan loads the UI from some transient variables. Make
            % sure these are filled too
            st.listChan         = cat( 1, st.listChan, st.d(iD).cChan.' );
            st.listFreq         = cat( 1, st.listFreq, st.d(iD).FreqList.' );
            
            % Fill the "change log"
            st.d(iD).nLogTime   = now(); % dataman uses the old datenum fmt
            st.d(iD).cLogUser   = {dm_User()};
            st.d(iD).cLogType   = {'WAVE Export'};
            st.d(iD).cLogDesc   = {'Exported from WAVE project directly to a DataMan file'};
            
            % Release the Kraken ... uh ... I mean memory
            clear m
            
            % Successful, increment to the next structure element
            iD = iD + 1;
            
        catch Me
            cErr{end+1,1} = ['Error: ' Me.identifier ' for ' oWave.cFiles_NodalCSEM{iFile}];
        end
        
    end % loop over Nodal files
    close( oProg );
    
    if ~isempty( cErr )
        % Log the errors
        for i = 1:numel(cErr)
            oWave.AddLog( cwave.LogError, cwave.sLog_Nodal_DM, cErr{i} );
        end
        % NB: No need to use uialert(). w_panelAction will automatically display
        % the log if there are warnings or errors
    end
    
    % Log the action
    sMsg = sprintf( 'Exported %d of %d CSEM sites to DataMan' ...
        , iD - 1, numel(oWave.cFiles_NodalCSEM) );
    oWave.AddLog( cwave.LogOK, cwave.sLog_Nodal_DM, sMsg );
    
    % Save the dataman structure
    if iD > 1
        % get rid of any partial from a thrown error during read
        st.d(iD:end) = [];
        
        % Sort the site list. It will be in Line,Site above, but DataMan prefers
        % they be sorted by their "display name" which means site,line
        [st.listSite,iSort] = sort( {st.d.sDisp} );
        st.listSite         = reshape( st.listSite, [], 1 );
        st.d                = st.d(iSort);
        
        % On load, DataMan loads the UI from some transient variables. Make sure
        % these are filled too
        st.valSite  = 1;
        st.valFreq  = 1;
        st.valChan  = 1;
        st.listFreq = arrayfun( @num2str, unique(st.listFreq), 'UniformOutput', false );
        st.listChan = unique(st.listChan);
        st.radCSEM  = 1;
        st.radMT    = 0;
        st.radTip   = 0;
        st.radTD    = 0;
        
        % Save the file
        save( sOutDM, '-struct', 'st', '-v7.3' );
        
        % Launch DataMan. NB: do NOT call it directly. Launch it from the
        % command line so that copyDependents doesn't pick up all of DataMan's
        % dependencies.
        evalin( 'base', ['DataMan( ''' sOutDM ''' );'] );
    end
    
    return;
end % ExportToDataMan
