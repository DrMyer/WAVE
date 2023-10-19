function ProcessSIOMETFiles( oWave )
% cwave::ProcessSIOMETFiles( oWave )
%
% Public method of the cwave class. Runs the process to average SIO all-in-one
% meterological data into avg atmospheric pressure per day and produce a time
% series of the ship GPS, COG, and winch wire-out data to backfill for any ship
% time-series data that are missing
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% This process is always a "run all". So first clear the log of all previous
% entries of this type
oWave.ClearLogOfType( cwave.sLog_AtmPres );
oWave.ClearLogOfType( cwave.sLog_ProcSIOMET );

% If there's nothing to do, log it as an error so the user doesn't just keep
% pressing the button wondering why nothing is happening.
if isempty( oWave.cFiles_SIOMET )
    oWave.AddLog( cwave.LogError, cwave.sLog_ProcSIOMET ...
        , 'No MET files selected in the file list. Select files first, then run.' );
    return;
end

% Generate errors for invalid files
bIsMET = isFile_MET( oWave.cFiles_SIOMET );
if all( ~bIsMET )
    oWave.AddLog( cwave.LogError, cwave.sLog_ProcSIOMET ...
        , 'None of the files in the MET file list are recognized as MET files.' );
    return;
end
if any( ~bIsMET )
    for iFile = reshape( find( ~bIsMET ), 1, [] )
        oWave.AddLog( cwave.LogError, cwave.sLog_ProcSIOMET ...
            , sprintf('File %d: Not a valid MET file: %s', iFile, oWave.cFiles_SIOMET{iFile} ) ...
            );
    end
end

% Only process files recognized as MET files
try
    [nMet,colMET] = readMET( oWave.cFiles_SIOMET(bIsMET), 'Quiet', oWave.hFig, 'UseNaNs' );
catch Me
    % If there are variations in the file formats, then isFile_MET.m and
    % readMET.m need to be updated.
    oWave.AddLog( cwave.LogError, cwave.sLog_ProcSIOMET ...
        , sprintf( 'Error in readMET.m. Invalid file?? %s %s', Me.identifier, Me.message ) ...
        );
    return;
end
oWave.AddLog( cwave.LogOK, cwave.sLog_ProcSIOMET ...
    , sprintf( 'Read %d entries from %d MET files.', size(nMet,1), sum(bIsMET) ) ...
    );

% Summarize the atmospheric pressure
colMET.dayonly = size(nMet,2) + 1;
nMet(:,colMET.dayonly) = floor( nMet(:,colMET.TIME) ); % chop off hh:mm:ss from datenum
[nDay,~,iB] = unique( nMet(:,colMET.dayonly) );
nMean = accumarray( iB, nMet(:,colMET.BP), [], @mean );
nStd  = accumarray( iB, nMet(:,colMET.BP), [], @std );

% Create summary table by day
% 
% NB: Because there may be listeners, assemble the table as a local variable,
% then copy it to the main object.
tblAtmP            = cwave.GetDfltFor( 'tableAtmPres', numel(nDay) );
tblAtmP.Date       = datetime( nDay, 'ConvertFrom', 'datenum' ) + hours(12); % avg is at midday
tblAtmP.Mean       = nMean;
tblAtmP.Std        = nStd;
oWave.tableAtmPres = tblAtmP;

% Log success 
oWave.AddLog( cwave.LogOK, cwave.sLog_AtmPres ...
    , sprintf( 'Averaged atm pressure for %d days.', size(nDay,1) ) ...
    );

% Create the time-series table. Start by trimming down to just the columns we
% want in the time series - most of the MET data cols are irrelevant
%
% NB: All the fields chosen here will be output to the csv text file. But not
% all of them will necessarily end up in cwave::tableShipTS. This is fine.
%
cFlds   = fieldnames( colMET );
nOutCol = colMET.TIME;  % TIME should be the first output column
cFldsOut= {'TIME'};
for c = {'LA','LO','ZO','CR','BP','GY'} % Lat,Lon,ZO=Wire_Out,CR=COG,BP=BaroPress,GY=gyroscope
    sType = c{1};
    iAt = reshape( find( strncmpi( cFlds, sType, 2 ) ), 1, [] );
    switch( numel(iAt) )
    case 0  % not found
        break;
    case 1  % only one found
        nOutCol(1,end+1)    = iAt;
        cFldsOut{1,end+1}   = sType;
    otherwise % There are several. Make the user choose just ONE
        % Make a table of just the TIME data & the duplicate columns
        tPick = MET2Table( nMet(:,[colMET.TIME iAt]), colstruct( [{'TIME'} cFlds{iAt}] ) );
        iPick = UIPickOneFromPlot( tPick, oWave.hFig ...
            , 'Duplicate MET data found - Pick ONE' ...
            , ['INSTRUCTIONS: Multiple copies of the same data stream have ' ...
            'been found in the MET file(s). This is common. Pick the one that ' ...
            'is actually useful to your survey.' ...
            ] ...
            , 'NoCancel' );
        nOutCol(1,end+1)    = iAt(iPick-1);     % NB: iPick is column in tPick which is off by one
        cFldsOut{1,end+1}   = sType;
        
        % Log the user's choice
        oWave.AddLog( cwave.LogOK, cwave.sLog_ProcSIOMET ...
            , ['Duplicate MET field found. User chose: ' cFlds{iAt(iPick-1)}] );
    end
end

% Construct the table with nice explanatory names instead of the MET's opaque
% 2-char abbreviation codes
%
% NB: Above ensures there are NO duplicate names so there will never be any
% column names in tOutMET that have '1' or '2' suffixed on them
tOutMET = MET2Table( nMet(:,nOutCol), colstruct( cFldsOut ) );
oWave.AddLog( cwave.LogOK, cwave.sLog_ProcSIOMET ...
    , sprintf( 'MET Ship Data time series: %d rows; median time step %gs' ...
            , height(tOutMET), seconds( median( diff( tOutMET.Time ) ) ) ) ...
    );

% Save the table (for the user) to a comma delimited file. This file can be
% pulled into any of the ship file lists (GPS, Winch, Gyro) to be used for
% info that's missing. Ex: Scarborough didn't have separate Gyro info - it was
% in the MET files. But it had GPS & Winch wire-out files at 1s intervals as
% opposed to the MET's 30s intervals
sOutFile = fullfile( oWave.sSuesiDir, 'MET_ShipData.txt' );
hProg    = uiprogressdlg( oWave.hFig, 'Title', 'MET Data Processing' ...
                    , 'Message', ['Writing ' sOutFile], 'Indeterminate', 'on' );
oWave.AddLog( cwave.LogOK, cwave.sLog_ProcSIOMET, ['Write MET to file: ' sOutFile] );
writetable( tOutMET, sOutFile, 'FileType', 'text', 'WriteVariableNames', true ...
    , 'WriteMode', 'overwrite', 'Delimiter', 'comma' );
if isvalid( hProg )
    delete( hProg );
end

% Backfill any empty file list. This fires off listeners. NB: only add to the
% appropriate file list if we know the correct fields are in the MET data and
% the filelist is currently empty. MET data are generally only every 30s whereas
% other native logs are generally every 1s
if isempty( oWave.cFiles_ShipGPS ) && any(strcmpi(cFldsOut,'LA')) && any(strcmpi(cFldsOut,'LO'))
    oWave.AddLog( cwave.LogOK, cwave.sLog_ShipGPS, ['MET Added: ' sOutFile] );
    oWave.cFiles_ShipGPS{1,1} = sOutFile;
end
if isempty( oWave.cFiles_Gyro ) && any(strcmpi(cFldsOut,'GY'))
    oWave.AddLog( cwave.LogOK, cwave.sLog_ShipGyro, ['MET Added: ' sOutFile] );
    oWave.cFiles_Gyro{1,1} = sOutFile;
end
if isempty( oWave.cFiles_Winch ) && any(strcmpi(cFldsOut,'ZO'))
    oWave.AddLog( cwave.LogOK, cwave.sLog_ShipWinch, ['MET Added: ' sOutFile] );
    oWave.cFiles_Winch{1,1} = sOutFile;
end

return;
end % ProcessSIOMETFiles
