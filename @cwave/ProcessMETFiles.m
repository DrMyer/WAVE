function ProcessMETFiles( oWave )
% cwave::ProcessMETFiles( oWave )
%
% Public method of the cwave class. Average a ship's meterological data into avg
% atmospheric pressure per day for use calibrating SUESI's Valeport instrument
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    % This process is always a "run all"
    oWave.ClearLogOfType( cwave.sLog_ProcMET );
    
    % Parse all the files into atm pressure time series
    tm = tic();
    [bOK, tblMET] = oWave.GetDataFromUserConfigurableTypes( ...
        oWave.cFiles_MET, ListFmts_MET(), cwave.sLog_ProcMET, 'MET' );
    if ~bOK || isempty( tblMET )
        return;
    end
    tblMET(isnat(tblMET.Time),:) = [];
    oWave.AddLog( oWave.LogOK, cwave.sLog_ProcMET ...
        , sprintf( 'Processed %d atm pressure lines from %d files in %d seconds' ...
                 , height(tblMET), numel(oWave.cFiles_ShipGPS), ceil(toc(tm)) ) );
    
    % Create daily averages (the second-by-second variations are not useful)
    [nDay,~,iB]     = unique( yyyymmdd( tblMET.Time ) );
    tblAtmP         = cwave.GetDfltFor( 'tableAtmPres', numel(nDay) );
    tblAtmP.Date    = datetime( nDay, 'ConvertFrom', 'yyyymmdd' ) + hours(12); % avg is at midday
    tblAtmP.Mean    = accumarray( iB, tblMET.Pressure, [], @mean );
    tblAtmP.Std     = accumarray( iB, tblMET.Pressure, [], @std );
    
    % Log success & save the table (invokes listeners)
    oWave.AddLog( cwave.LogOK, cwave.sLog_ProcMET ...
        , sprintf( 'Averaged atm pressure for %d days. Total time %d s' ...
                 , size(nDay,1), ceil(toc(tm)) ) );
    oWave.tableAtmPres  = tblAtmP;
    
    return;
end % ProcessMETFiles
