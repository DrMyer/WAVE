classdef ( ConstructOnLoad = true, Sealed = true ) cwave < handle
    % cwave
    %
    % Workbench for Analysis and Visualization of Electromagnetic data
    % Designed & written by David Myer
    %
    % NB: derived from 'handle' so that the object persists for as long as the
    % UI objects it creates. This keeps the caller having to keep an actual copy
    % of the object itself.
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% PROPERTIES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    %---------------------------------------------------------------------------
    % The properties below define the data a wave instance is keeping track of.
    % These get saved to a .mat file.
    %---------------------------------------------------------------------------
    %
    % NB: EVERY PROPERTY HERE **MUST** HAVE A DEFAULT VALUE. This isn't a MatLab
    % requirement, it's a cwave code requirement. Defaults are expected
    % throughout the code and accessed with cwave.GetDfltFor().
    %
    %---------------------------------------------------------------------------
    %
    % These next properties canNOT have listeners
    properties( Access = public, AbortSet )
        % Miscellaneous control variables
        nVer     double = 1.0;
        cLog            = cell(0,5);    % Change log. See colLog below for column defs
        % NB: the cLog is NOT a table object because cell arrays are far more
        % memory efficient as they get large. Tables must have a single
        % contiguous chunk of memory for each column. Cell arrays are small
        % arrays of pointers to disparate chunks of memory.
        
        sMiscNotes string = [
            "Enter miscellaneous notes about the cruise / phase here."
            "Some common items are listed below."
            "Edit to your heart's content."
            "____________________________________________________________"
            "Vessel: R/V Boaty McBoatface"
            "-- ?,? :(m) offset from GPS to deployed A-frame sheave"
            "-- ?,? :(m) offset from GPS to Benthos pinger [nodal RX nav]"
            "(NB: Point ship north. You'll need both E-W and N-S offsets)"
            "____________________________________________________________"
            "SUESI & streamer configuration"
            "-- ? :(m) antenna dipole length"
            "-- ? :(m) offset from SUESI to antenna midpoint"
            "-- ? :(m) offset from SUESI to CTET"
            "-- ? :(kHz) CTET listened on frequency"
            "-- ? :(#) CTET reported depth to SUESI on w=[nn]"
            "-- ... ditto for Vulcans, Porpoises, etc ..."
            "____________________________________________________________"
            "iLBL Barracuda configuration"
            "NAV #  Ducer Z  ListenFq  ReplyFq  ReplyCh"
            "-----  -------  --------  -------  -------"
            "  ?      0.5 m    12.5       ?        ?"
            "  ?      0.5 m    12.5       ?        ?"
            ];
        tableStamp        = table( 'Size', [0 2] ...  
            , 'VariableNames', {'Time', 'Log'} ...
            , 'VariableTypes', {'datetime', 'string'} ...
            );
        
        % Folder structure for the survey
        sFileName  char = '';           % workbench/survey file name
        sDir_Main  char = '';           % full path to the main output folder
        % These sub-folders are REQUIRED to exist
        sDir_Logs  char = '_Logs';      % SUB-FOLDER for output text dumps
        sDir_Plot  char = '_Plots';     % SUB-FOLDER for plots (USE CONVENIENCE FCN: sPlotDir())
        sDir_Edit  char = '_Editing';   % SUB-FOLDER for w_panelTable's advanced edit features (USE CONVENIENCE FCN: sEditDir())
        sDir_Suesi char = '_SUESI';     % SUB-FOLDER for SUESI processing outputs (SDM, Valeport, SNAP, etc)
        sDir_RxCfg char = '_RxCfg';     % SUB-FOLDER for Rx configuration (*.sp) files
        sDir_CSEM  char = '_CSEM';      % SUB_FOLDER for CSEM processing output
        % These sub-folders are SUGGESTED for organizing survey data
        
        % External reference folders used by many surveys
        sDir_Calib char = '';           % EXT/REF FOLDER with .rsp calibration files
        
        
        %- NOTE ---------------------------------------------------------------%
        % The variables below, which are managed by various w_panelInput UI
        % objects, MUST have entries in the stVarInfo constant structure in this
        % class definition.
        %----------------------------------------------------------------------%
        %-- UTM info; cwave::UTM_VarChg triggered by .set function(s)
        bUTMLock logical        = false;
        nUTMZone double         = 1;
        sUTMHemi string         = "North";
        sEllipsoid string       = "wgs84"; % see cEllList and getEllipsoid.m for valid list
        
        %-- SUESI tab; cwave::SuesiTab_VarChg triggered by w_panelInput
        nTxDipLen   double      = 250;  % (m) TX Dipole length
        nFixSuesiCOG double     = 0;    % (deg) amount to rotate SUESI's COG which can be 180deg off
        sZBins char = '0:10:500 600:100:5000';   % (m) for Valeport depth profiles
        sLimitVVel  char        = '1400 1600';  % (m/s) limits on valid Valeport values
        sLimitVTemp char        = '1 35';       % (deg C)
        sLimitVCond char        = '20 70';      % (Siemens/m)
        %
        % NB: don't trim the SDM time series based on current or altitude. This
        % is unnecessary since I have tableTow which is keeping track of when
        % each actual tow line begins & ends. Keep as much of the SUESI info as
        % possible so that the iLBL navigation can be as accurate as possible.
        %
        % nTxAltMax   double      = Inf;  % (m) Max TX altitude. Don't output above this. (Inf for all)
        % nTxAmpMin   double      = 30;   % (Amp) min Amps to output to SDM file(s) (0 for all)
        
        %-- RX Nav tab; cwave::RxNavTab_VarChg triggered by w_panelInput
        nRxNavMaxTWTT double    = 7;    % (s) max TWTT to consider
        nRxNavMaxRange double   = 7;    % (km) max HORIZONTAL range to consider
        nRxNavTransDelay double = 0;    % (ms) transponder reply delay (ORE uses 12.5ms)
        
        %-- TX iLBL Nav tab: cwave::TxNavLBLTab_VarChg triggered by w_panelInput
        % NB: There are a number of variables below listed at "(int)" but typed
        % as double. This is because the entries they link to in the tables are
        % doubles. int64 (etc) does not support "missing()" (alas).
        nGPStoWireZeroN double  = 0;    % (m) NORTH offset from GPS to Wire-Zero (top of A-frame)
        nGPStoWireZeroE double  = 0;    % (m) EAST offset from GPS to Wire-Zero (top of A-frame)
        nTxCtrOffset double     = 10 + 250/2 + 30.48/2; % (m) offset from SUESI to middle of the antenna
        nBPingLimit double      = 6;    % (s) Max TWTT for barracuda pings
        % Next are for path smoothing
        nMinWireLBL double      = 250;  % Min wire-out before using iLBL. Otherwise just ship-track.
        nMADfactor double       = 2;    % TWTT within +/- <N>*mad of median are kept
        % CTET
        nCNavNo double          = 0;    % (int) w=[nn] number in SUESI logs (the rest are Vulcans)
        nCDist double           = 200;  % (m) distance of CTET behind SUESI transducer
        nCListenFreq double     = 0;    % (Hz) ping frequency it listens on
        
        %-- both CSEM tabs; cwave::CSEMUI_VarChg triggered by w_panelInput
        nWindowLen double       = 4;    % (s) length of CSEM FFT window (usually 1 waveform)
        nStackLen double        = 60;   % (s) length of CSEM stacking window
        
    end % public properties
    
    % These properties CAN have listeners (SetObservable)
    %
    % NB: 'AbortSet' means that the listener will only be called if the property
    % actually changes. Setting to an identical value doesn't call the listener.
    %
    properties( Access = public, SetObservable, AbortSet )
        % Lists of files used in w_panelFile objects
        %-- shipboard data is processed into tableShipTS and tableAtmPres
        cFiles_ShipGPS  = {};           % Ship GPS
        cFiles_Winch    = {};           % Ship winch wire-out
        cFiles_Gyro     = {};           % Ship Gyrocompass
        cFiles_MET      = {};           % MET files (meteorological data for atm pressure)
        cFiles_SIOMET   = {};           % special SIO MET files which also have GPS, wire-out, & gyro
        
        %-- SUESI log-related files
        cFiles_SUESIraw = {};           % Raw SUESI log text capture files
        cFiles_SUESImat = {};           % Parsed SUESI .mat files
        cFiles_SNAP     = {};           % Waveform SNAPSHOT files made from SUESI logs
        
        %-- RX Nav files
        cFiles_RxBenthos= {};           % Benthos pinger files for RxNav
        
        %-- TX iLBL Nav files
        cFiles_TxBLogs  = {};           % Barracuda raw GPS log files
        
        %-- CSEM files
        cFiles_Bin      = {};           % input binary data files BOTH NODAL AND TOWED!
        cFiles_NodalCSEM= {};           % Stacked, nav-merged nodal CSEM
        cFiles_TowedCSEM= {};           % Stacked, nav-merged towed CSEM
        
        %-- Tables holding processed data of various stages
        % Ship data time series
        tableShipTS     = table( 'Size', [0 8] ...  
            , 'VariableNames', {'Time', 'Latitude', 'Longitude', 'East', 'North', 'Wire_Out', 'COG', 'Gyro'} ...
            , 'VariableTypes', {'datetime', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
            );
            % NB:  COG is the direction the ship is MOVING. 
            %     GYRO is the direction the ship is POINTING.
            % The distinction is important when working with the offset of the
            % ship's GPS mast from other ship equipment (e.g. transducer,
            % A-frame, etc) where the GYRO is required.
            
        % Avg atmo pressure (for Valeport TARE)
        tableAtmPres    = table( 'Size', [0 3] ...  
            , 'VariableNames', {'Date',    'Mean',  'Std'} ...
            , 'VariableTypes', {'datetime','double','double'} ...
            );
        
        % Sync datetimes for SUESI S= markers
        tableSUESISync  = table( 'Size', [0 8] ...  
            , 'VariableNames', {'File',  'SyncNo','DataLines', 'S_From', 'S_To',   'S_Sync', 'SyncTime', 'Path'} ...
            , 'VariableTypes', {'string','double','double',    'double', 'double', 'double', 'datetime','string'} ...
            );
        
        % Median SNAP-derived waveform
        tableWaveSNAP   = table( 'Size', [0 2] ...  
            , 'VariableNames', {'Time', 'Amplitude'} ...
            , 'VariableTypes', {'double', 'double'} ...
            );
        % Idealized waveform
        tableWaveIdeal  = table( 'Size', [0 2] ...  
            , 'VariableNames', {'Time', 'Amplitude'} ...
            , 'VariableTypes', {'double', 'double'} ...
            );
        % Normalizing harmonics from either SNAP or ideal waveform
        tableHarmonics  = table( 'Size', [0 4] ...  
            , 'VariableNames', {'Harmonic', 'Frequency', 'Amplitude', 'Phase'} ...
            , 'VariableTypes', {'double', 'double', 'double', 'double'} ...
            );
        
        % SUESI source-dipole-moment time series
        tableSDM        = table( 'Size', [0 13] ... 
            , 'VariableNames', { 'Time', 'SDM' ...
                               , 'Ship_Lon', 'Ship_Lat', 'Ship_East', 'Ship_North' ...
                               , 'Ship_COG', 'Ship_Gyro', 'Wire_Out' ...
                               , 'Altitude', 'Depth', 'COG', 'Dip' ... NB: SUESI, not Tx midpt
                               } ...
            , 'VariableTypes', [{'datetime'} repmat({'double'},1,12)] ...
            );
        
        % Benthos pings to barracudas from SUESI log
        %
        % NB: 'PingNo' keeps track of all the replies from a single ping.
        % Depending on water conditions, there can be a lot of multi-path
        % replies from bounces off the seafloor and sea surface. Having them
        % grouped allows for easier elimination of multiples.
        tableBenthos    = table( 'Size', [0 6] ... 
            , 'VariableNames', {'Time','PingNo','PingFreq','ReplyFreq','ReplyCh','ReplyTWTT'} ...
            , 'VariableTypes', {'datetime','double','double','double','double','double'} ...
            );
        
        % Towed device (e.g. TETs and Vulcans) depth table from SUESI log
        tableVulcan     = table( 'Size', [0 6] ...
            , 'VariableNames', {'Time', 'DeviceNo', 'Heading', 'Pitch', 'Roll', 'Depth'} ...
            , 'VariableTypes', {'datetime','double','double','double','double','double'} ...
            );
        
        % Tow info: start/stop times, number, lags, phase shift, etc...
        %
        % NB: phase shift allows for waveform polarity reversal (180 degree
        % shift) which happens on some cruises where the SUESI leads are
        % connected backwards (e.g. Scarborough)
        %
        % NB: table's missing() does NOT support 'logical' type
        tableTow        = table( 'Size', [0 9] ...
            , 'VariableNames', {'TowNo', 'DirEofN', 'Lag','WireOutTare','IgnoreNav', 'SmoothSec', 'PhaseShift', 'DateFrom', 'DateTo'} ...
            , 'VariableTypes', {'double', 'double','double','double',    'double',    'double',     'double',  'datetime','datetime'} ...
            );
        
        % Barracuda configuration. This can change every time they are recovered
        % for battery swaps. So some cruises have exactly 2 configurations but
        % others have more
        tableCudaCfg    = table( 'Size', [0 7] ...
            , 'VariableNames', {'DeviceNo', 'DucerDepth', 'ListenFreq', 'ReplyFreq', 'ReplyCh', 'DateFrom', 'DateTo'} ...
            , 'VariableTypes', {'double',   'double',     'double',     'double',    'double', 'datetime','datetime'} ...
            );
        
        % Barracuda GPS time series for iLBL nav
        tableCudaGPS    = table( 'Size', [0 7] ...
            , 'VariableNames', {'Time', 'DeviceNo', 'Longitude', 'Latitude', 'East', 'North', 'FileLine'} ...
            , 'VariableTypes', {'datetime','double','double',    'double', 'double','double', 'double'} ...
            );
        
        % TX nav for the antenna midpoint. From either iLBL or USBL
        tableTxNav      = table( 'Size', [0 20] ... 
            , 'VariableNames', { 'Time', 'TowNo' ...
                               , 'Altitude', 'Depth', 'COG', 'Dip' ...        antenna midpoint (SOLUTION)
                               , 'Longitude', 'Latitude', 'East', 'North' ... antenna midpoint (SOLUTION)
                               , 'Wire0_E', 'Wire0_N' ... wire0 location under a-frame behind ship where wire-out is zeroed
                               , 'Suesi_Z' ... depth from tableSDM - SUESI's Valeport depth
                               , 'ShipTrack_E', 'ShipTrack_N' ... SUESI's location back in the shiptrack from wire-out & depth & ship crabbing
                               , 'Ping_E', 'Ping_N' ... SUESI's location from pings (2 barracudas or 1 barracuda & wire-out.depth triangle)
                               , 'Smooth_E', 'Smooth_N' ... SUESI's location smoothed from shiptrack & ping info
                               , 'Forced' ... 1= SUESI affixed to shiptrack by settings
                               } ...
            , 'VariableTypes', [{'datetime'} repmat({'double'},1,19)] ...
            );
        
        % CTET navigated time series (may not exist if CTET failed)
        %  NB: this table is used for the antenna midpoint in tableTxNav above
        %      and ALSO it is used in navigating the Vulcans in the tow string.
        %      We assume they are in a line running through SUESI and CTET for
        %      [e,n]. If the vulcans have w=[] data, it is used for depth. If
        %      not then the SUESI-through-CTET line is used for depth
        tableCTET       = table( 'Size', [0 10] ... 
            , 'VariableNames', { 'Time', 'TowNo', 'East', 'North', 'Depth' ...
                               , 'ShipTrack_E', 'ShipTrack_N', 'Ping_E', 'Ping_N' ...
                               , 'Forced' ... 1= SUESI affixed to shiptrack by settings
                               } ...
            , 'VariableTypes', [{'datetime'} repmat({'double'},1,9)] ...
            );
        
        % Valeport-derived depth profiles
        tableValeport   = table( 'Size', [0 10] ...  
            , 'VariableNames', {'Depth','Velocity','Temp','Conductivity','Vmin','Vmax','Tmin','Tmax','Cmin','Cmax'} ...
            , 'VariableTypes', repmat({'double'},1,10) ...
            );
        
        % GPS-to-Transducer offset table (for RX Nav)
        tableGPS2Ducer  = table( 'Size', [0 7] ...
            , 'VariableNames', {'Name','North_Offset','East_Offset','Depth_Below_Sea','DateFrom','DateTo','Desc'} ...
            , 'VariableTypes', {'string', 'double',     'double',   'double',       'datetime', 'datetime', 'string'} ...
            );
        
        % RX Drop location & pinger frequency list
        tableRxDrop     = table( 'Size', [0 5] ...
            , 'VariableNames', {'RxName','Latitude','Longitude','Depth','DucerFreq'} ...
            , 'VariableTypes', {'string', 'double', 'double','double','double'} ...
            );
        
        % Table of velocity profiles over time (for multiple ships or long
        % deployments). This table keeps the name & dates. The cell array
        % below keeps the actual velocity profile tables. Trying to keep the
        % cell array INSIDE the table requires too much manipulation of
        % standardized codes like UITableEdit/Plot() as well as screwing with my
        % use of missing() to intialize tables [cell doesn't support missing()].
        tableVProfile = table( 'Size', [0 3] ...
            , 'VariableNames', {'Name',  'DateFrom','DateTo'} ...
            , 'VariableTypes', {'string','datetime','datetime'} ...
            );
        cVProfile = cell(0,0);  % each cell = TABLE with cols: Depth, Velocity
        
        % Navigated seafloor receiver locations
        tableRxNav      = table( 'Size', [0 26] ...
            , 'VariableNames', {'RxName','DucerFreq','Latitude','Longitude' ...
                                , 'East','North','Depth' ...
                                , 'East_Std','North_Std','Depth_Std','RMS','PingCnt' ...
                                , 'XY_Phi', 'XY_Major', 'XY_Minor' ...      % error ellipses
                                , 'XZ_Phi', 'XZ_Major', 'XZ_Minor' ...      % error ellipses
                                , 'YZ_Phi', 'YZ_Major', 'YZ_Minor' ...      % error ellipses
                                , 'Drop_Lat','Drop_Lon','Drop_East','Drop_North','Drop_Depth'} ...
            , 'VariableTypes', [{'string'}, repmat({'double'},1,25)] ...
            );
        
        % OBEM Rx configuration
        %
        % NB: Rather than embedding the channel table in the Rx table and
        % greatly complicating things, I keep them separate and key them on the
        % RxName field
        tableRxCfg = table( 'Size', [0 16] ...
            , 'VariableNames', { 'RxName', 'Compass', 'Pitch', 'Roll' ...
                               , 'SyncTime', 'SyncTag', 'ShiftTime', 'ShiftTag' ...
                               , 'DriftRate' ... 
                               , 'Latitude', 'Longitude', 'Depth', 'East', 'North' ...
                               , 'BinFile', 'BinPath' ... 
                               } ...
            , 'VariableTypes', [{'string','double','double','double' ...
                                ,'datetime','double','datetime','double'} ...
                                , repmat({'double'},1,6) ...
                                , {'string', 'string'}] ...
            );
        tableRxCh = table( 'Size', [0 9] ...   do NOT put listeners on this table
            , 'VariableNames', { 'RxName', 'ChanNo', 'Type' ...
                               , 'Orient', 'Tilt' ... % NB: CountConv comes from readBinFile.m
                               , 'DipLen', 'Gain', 'MTOutputOrder' ...
                               , 'CalibFile' ...
                               } ...
            , 'VariableTypes', [{'string','double','string'}, repmat({'double'},1,5), {'string'}] ...
            );
        
        % Towed Rx configuration
        tableTowRxCfg = table( 'Size', [0 10] ...
            , 'VariableNames', { 'RxName', 'DeviceNo', 'TrailingDist' ...
                               , 'SyncTime', 'SyncTag', 'ShiftTime', 'ShiftTag' ...
                               , 'DriftRate', 'BinFile', 'BinPath' ... 
                               } ...
            , 'VariableTypes', { 'string', 'double', 'double' ...
                               , 'datetime','double','datetime','double' ...
                               , 'double', 'string', 'string' } ...
            );
        tableTowRxCh = table( 'Size', [0 8] ...   do NOT put listeners on this table
            , 'VariableNames', { 'RxName', 'ChanNo', 'Type' ...
                               , 'Orient', 'Tilt' ... % NB: CountConv comes from readBinFile.m
                               , 'DipLen', 'Gain' ...
                               , 'CalibFile' ...
                               } ...
            , 'VariableTypes', [{'string','double','string'}, repmat({'double'},1,4), {'string'}] ...
            );
        
    end
    
    % SET methods for the above properties which ensure that changes get
    % cascaded through other related properties.
    methods     % "set." method section cannot have any modifiers
        function set.tableTow( oWave, tbl )
            oWave.tableTow = sortrows( tbl, 'TowNo' );
            oWave.Invalidate_TxNav();
            oWave.Invalidate_CSEMOutput();
            return;
        end
        function set.tableSDM( oWave, tbl )
            oWave.tableSDM = tbl;
            oWave.Invalidate_TxNav();
            oWave.Invalidate_CSEMOutput();
            return;
        end
        function set.tableHarmonics( oWave, tbl )
            oWave.tableHarmonics = tbl;
            oWave.Invalidate_CSEMOutput();
            return;
        end
        function set.tableTxNav( oWave, tbl )
            oWave.tableTxNav = tbl;
            oWave.Invalidate_CSEMOutput();
            return;
        end
        function set.tableRxNav( oWave, tbl )
            oWave.tableRxNav = tbl;
            oWave.Update_RxCfg_from_RxNav();
            return;
        end
        function set.tableGPS2Ducer( oWave, tbl )
            oWave.tableGPS2Ducer = tbl;
            oWave.Invalidate_RxNav();
            return;
        end
        function set.tableRxDrop( oWave, tbl )
            oWave.tableRxDrop = tbl;
            oWave.Invalidate_RxNav();
            return;
        end
        function set.tableVProfile( oWave, tbl )
            oWave.tableVProfile = tbl;
            oWave.Invalidate_RxNav();
            oWave.Invalidate_TxNav();
            return;
        end
        function set.tableShipTS( oWave, tbl )
            oWave.tableShipTS = tbl;
            oWave.Invalidate_RxNav();
            oWave.Invalidate_TxNav();
            oWave.Invalidate_SuesiOutput();
            return;
        end
        function set.tableSUESISync( oWave, tbl )
            oWave.tableSUESISync = tbl;
            oWave.Invalidate_SuesiOutput();
            oWave.Invalidate_TxNav();
        end
        function set.tableAtmPres( oWave, tbl )
            oWave.tableAtmPres = tbl;
            oWave.Invalidate_SuesiOutput();
            oWave.Invalidate_TxNav();
        end
        function set.tableCudaGPS( oWave, tbl )
            oWave.tableCudaGPS = sortrows( tbl, 'Time' );
            oWave.Invalidate_TxNav();
            oWave.Update_CudaCfg_from_CudaGPS();
        end
        function set.tableWaveSNAP( oWave, tbl )
            oWave.tableWaveSNAP = tbl;
            oWave.Update_WaveHarmonics();
        end
        function set.tableWaveIdeal( oWave, tbl )
            oWave.tableWaveIdeal = tbl;
            oWave.Update_WaveHarmonics();
        end
        function set.tableBenthos( oWave, tbl )
            oWave.tableBenthos = tbl;
            oWave.Invalidate_TxNav();
        end
        
        function set.cFiles_RxBenthos( oWave, cList )
            oWave.cFiles_RxBenthos = cList;
            oWave.Invalidate_RxNav();
        end
        function set.cFiles_SUESIraw( oWave, cList )
            oWave.cFiles_SUESIraw = cList;
            oWave.Update_SuesiRaw();
        end
        function set.cFiles_SUESImat( oWave, cList )
            oWave.cFiles_SUESImat = cList;
            oWave.Update_SuesiMAT();
        end
        function set.cFiles_MET( oWave, cList )
            oWave.cFiles_MET = cList;
            oWave.Invalidate_MET();
        end
        function set.cFiles_SIOMET( oWave, cList )
            oWave.cFiles_SIOMET = cList;
            oWave.Invalidate_SIOMET();
        end
        function set.cFiles_ShipGPS( oWave, cList )
            oWave.cFiles_ShipGPS = cList;
            oWave.Invalidate_ShipTS();
        end
        function set.cFiles_Winch( oWave, cList )
            oWave.cFiles_Winch = cList;
            oWave.Invalidate_ShipTS();
        end
        function set.cFiles_Gyro( oWave, cList )
            oWave.cFiles_Gyro = cList;
            oWave.Invalidate_ShipTS();
        end
        function set.cFiles_TxBLogs( oWave, cList )
            oWave.cFiles_TxBLogs = cList;
            oWave.Invalidate_CudaGPS();
            oWave.Invalidate_TxNav();
        end
        function set.cFiles_SNAP( oWave, cList )
            oWave.cFiles_SNAP = cList;
            oWave.Invalidate_SnapWave();
        end
        function set.cFiles_Bin( oWave, cList )
            oWave.cFiles_Bin = sort( cList );
            oWave.Update_RxCfg();
        end
        
    end % "set." functions for cascading changes, clearing log entries, etc...
    
    % These are "event" type methods for clearing log entries & variable(s) for
    % certain downstream dependent data when the upstream data have changes
    methods( Access = protected )
        function Invalidate_CSEMOutput( oWave )     % Clear CSEM output list
            if oWave.bLoading; return; end
            oWave.ClearLogOfType( cwave.sLog_Nodal_CSEM );
            oWave.cFiles_NodalCSEM = cwave.GetDfltFor('cFiles_NodalCSEM');
            oWave.cFiles_TowedCSEM = cwave.GetDfltFor('cFiles_TowedCSEM');
        end
        
        function Invalidate_RxNav( oWave )          % Clear Rx Nav
            if oWave.bLoading; return; end
            oWave.ClearLogOfType( cwave.sLog_RxNavAction );
            oWave.tableRxNav = cwave.GetDfltFor( 'tableRxNav' );
        end
        
        function Invalidate_SuesiOutput( oWave )    % Clear SUESI outputs
            if oWave.bLoading; return; end
            oWave.ClearLogOfType( cwave.sLog_S_SDM );
            oWave.ClearLogOfType( cwave.sLog_S_Benthos );
            oWave.ClearLogOfType( cwave.sLog_S_Vulcan );
            oWave.ClearLogOfType( cwave.sLog_S_ValeP );
            oWave.tableSDM      = cwave.GetDfltFor( 'tableSDM' );
            oWave.tableBenthos  = cwave.GetDfltFor( 'tableBenthos' );
            oWave.tableVulcan   = cwave.GetDfltFor( 'tableVulcan' );
            oWave.tableValeport = cwave.GetDfltFor( 'tableValeport' );
        end
        
        function Invalidate_MET( oWave )            % MET file list edited
            if oWave.bLoading; return; end
            % NB: Clear the Atmospheric pressure table but NOT the shipTS
            % because the MET processing doesn't hit it directly
            oWave.ClearLogOfType( cwave.sLog_ProcMET );
            oWave.ClearLogOfType( cwave.sLog_AtmPres );
            oWave.tableAtmPres = cwave.GetDfltFor( 'tableAtmPres' );
        end
        
        function Invalidate_SIOMET( oWave )         % SIO-MET file list edited
            if oWave.bLoading; return; end
            % NB: Clear the Atmospheric pressure table but NOT the shipTS
            % because the MET processing doesn't hit it directly
            oWave.ClearLogOfType( cwave.sLog_ProcSIOMET );
            oWave.ClearLogOfType( cwave.sLog_AtmPres );
            oWave.tableAtmPres = cwave.GetDfltFor( 'tableAtmPres' );
        end
        
        function Invalidate_ShipTS( oWave )         % Clear Ship time series
            if oWave.bLoading; return; end
            oWave.ClearLogOfType( cwave.sLog_ShipData );
            oWave.tableShipTS = cwave.GetDfltFor( 'tableShipTS' );
        end
        
        function Invalidate_CudaGPS( oWave )        % Clear barracuda GPS time series
            if oWave.bLoading; return; end
            oWave.ClearLogOfType( cwave.sLog_TxN_BParse );
            oWave.tableCudaGPS  = cwave.GetDfltFor( 'tableCudaGPS' );
        end
        
        function Invalidate_TxNav( oWave )          % Clear Tx Nav outputs
            if oWave.bLoading; return; end
            oWave.ClearLogOfType( cwave.sLog_TxNavAction );
            oWave.tableTxNav  = cwave.GetDfltFor( 'tableTxNav' );
            oWave.tableCTET   = cwave.GetDfltFor( 'tableCTET' );
        end
        
        function Invalidate_SnapWave( oWave )       % Clear snap waveform
            if oWave.bLoading; return; end
            oWave.ClearLogOfType( cwave.sLog_Wave_SNAP );
            oWave.tableWaveSNAP = cwave.GetDfltFor( 'tableWaveSNAP' );
        end 
        
        % When RxNav changes, ripple changes back to RxCfg and cFiles_NodalCSEM
        function Update_RxCfg_from_RxNav( oWave )
            if oWave.bLoading; return; end
            % Walk through tableRxCfg and update the nav data from tableRxNav.
            % Also remove any already-processed CSEM files from the valid list
            % so that these can be re-run with "Run New"
            % 
            % NB: Don't change the table row by row, this will fire off
            % listeners. Change the table all at once
            tCfg    = oWave.tableRxCfg;
            tNav    = oWave.tableRxNav;
            cLst    = oWave.cFiles_NodalCSEM;
            cFldCmp = {'Latitude', 'Longitude', 'Depth', 'East', 'North'};
            sRxChgd = '';
            for iRxTo = 1:height(tCfg)
                % Find the site in the nav table
                iRxFrom = find( strcmpi( tNav.RxName, tCfg.RxName{iRxTo} ), 1 );
                if isempty( iRxFrom )
                    continue;
                end
                
                % Are any of the nav data actually changed?
                if ~isequal( tCfg(iRxTo,cFldCmp), tNav(iRxFrom,cFldCmp) )
                    % Update the nav
                    sRxChgd = [sRxChgd ' ' char(tCfg.RxName(iRxTo))];
                    tCfg(iRxTo,cFldCmp) = tNav(iRxFrom,cFldCmp);
                    
                    % Pull out of the processed CSEM list
                    bDrop = contains( cLst, ['_' char(tCfg.RxName(iRxTo)) '.csem.mat'] );
                    cLst(bDrop) = [];
                end
            end
            
            % If anything changed, update the table & log it
            if ~isempty( sRxChgd )
                oWave.AddLog( cwave.LogOK, cwave.sLog_Nodal_RxCfg ...
                    , ['Update nav info & remove processed CSEM for RXs:' sRxChgd] );
                oWave.tableRxCfg       = tCfg;
                oWave.cFiles_NodalCSEM = cLst;
            end
            return;
        end % Update_RxCfg_from_RxNav
        
        % Change to the list of raw SUESI data files
        function Update_SuesiRaw( oWave )
            if oWave.bLoading; return; end
            % If the list has been reset, cascade this down through everything.
            if isempty( oWave.cFiles_SUESIraw )
                % Clear the log of downstream entries
                oWave.ClearLogOfType( cwave.sLog_S_Decode );
                oWave.ClearLogOfType( cwave.sLog_S_Mat );
                oWave.ClearLogOfType( cwave.sLog_S_STime );
                oWave.ClearLogOfType( cwave.sLog_S_Sync );
                
                % Below will cascade to all the other SUESI & Waveform stuff
                oWave.cFiles_SUESImat = cwave.GetDfltFor( 'cFiles_SUESImat' );
                oWave.cFiles_SNAP     = cwave.GetDfltFor( 'cFiles_SNAP' );
                return;
            end
            
            % Look for files no longer in the raw file list but still in the
            % parsed or SNAP lists and remove them (NB: the sync table will
            % auto-update when I update the parsed-file list)
            
            %-- extract just filenames removing path & extension
            cFilesLeft = cell( size(oWave.cFiles_SUESIraw) );
            for i = 1:numel( oWave.cFiles_SUESIraw )
                [~,cFilesLeft{i}] = fileparts( oWave.cFiles_SUESIraw{i} );
            end
            
            %-- Remove extras from the .mat file list
            bDel = false( size(oWave.cFiles_SUESImat) );
            for i = 1:numel( oWave.cFiles_SUESImat )
                [~,f] = fileparts( oWave.cFiles_SUESImat{i} );
                bDel(i) = ~any( strcmpi( f, cFilesLeft ) );
            end
            if any( bDel )
                oWave.cFiles_SUESImat(bDel) = [];
            end
            
            %-- Remove extras from the SNAP list
            bDel = false( size(oWave.cFiles_SNAP) );
            for i = 1:numel( oWave.cFiles_SNAP )
                [~,f] = fileparts( oWave.cFiles_SNAP{i} );
                f = strrep( f, '_SNAP', '' ); % remove suffix
                bDel(i) = ~any( strcmpi( f, cFilesLeft ) );
            end
            if any( bDel )
                oWave.cFiles_SNAP(bDel) = [];
            end
            return;
        end % Update_SuesiRaw
        
        % User manual change to the list of processed SUESI files (.mat files).
        % Update the sync table and the ideal waveform
        function Update_SuesiMAT( oWave )
            if oWave.bLoading; return; end
            % Recombine the separated path & file in the existing table for
            % comparison with the mat file+path list so we can save any sync
            % date/time entries the user has already made.
            tblOld      = oWave.tableSUESISync;
            cFileOld    = fullfile( tblOld.Path, tblOld.File );
            
            % Create a brand-new table with empty sync times
            tblNew      = cwave.GetDfltFor( 'tableSUESISync' );
            iNext       = 1;
            cList       = oWave.cFiles_SUESImat;
            cList( ~isFile_SUESIMat( cList ) ) = [];    % remove invalid files from the src list
            tblWave     = [];
            
            for iFile = 1:numel(cList)
                % For each .mat file, retrieve the number of sync events and the
                % number of output lines in the file that are tied to that
                % GPS-sync'd session. NOTE: sometimes at the start of towing,
                % there can be multiple really short sync sessions when SUESI is
                % being set-up.
                m           = matfile( cList{iFile} );
                col         = m.col;
                nSyncEvtCnt = size( m.nSyncRange, 1 );
                nLineCnts   = diff( m.nSyncRange, [], 2 ) + 1;   % how many lines in each sync to-from pair
                
                % Get the waveform timing table (gleaned from commands entered
                % by the user and kept in the log)
                if isempty( tblWave )
                    tblWave = m.tblWaveForm;
                else
                    tblWave = [tblWave; m.tblWaveForm];
                end
                
                % Create an entry in the timing table for each Sync event
                [sPath, sFile, sExt] = fileparts( cList{iFile} );
                sFile = [sFile sExt];
                for iSyncNo = 1:nSyncEvtCnt
                    tblNew{iNext,:}         = missing();    % add a new row to the table
                    tblNew.Path(iNext)      = sPath;
                    tblNew.File(iNext)      = sFile;
                    tblNew.SyncNo(iNext)    = iSyncNo;
                    tblNew.DataLines(iNext) = nLineCnts(iSyncNo);
                    
                    % pull date & S= numbers from the mat file (if date ~NaN)
                    nDataLine               = m.nData(m.nSyncRange(iSyncNo,2),:);
                    tblNew.S_To(iNext)      = nDataLine(1,col.SuesiSec);
                    nDataLine               = m.nData(m.nSyncRange(iSyncNo,1),:);
                    tblNew.S_From(iNext)    = nDataLine(1,col.SuesiSec);
                    if ~isnan( nDataLine(1,col.Yr) )
                        tblNew.S_Sync(iNext)    = nDataLine(1,col.SuesiSec);
                        tblNew.SyncTime(iNext)  = datetime( nDataLine(1,col.Yr:col.Sec) );
                    else
                        % Find this file & sync # in the old table & move its time
                        % over, if it's there
                        iAt = find( strcmpi( cList{iFile}, cFileOld ) ...
                                  & tblOld.SyncNo == iSyncNo, 1, 'first' );
                        if isempty( iAt )
                            tblNew.S_Sync(iNext)    = tblNew.S_From(iNext);
                            tblNew.SyncTime(iNext)  = NaT;
                        else
                            % NB: user may have changed which S= they have a
                            % timestamp for - not always the first in the sync
                            % set, just whatever someone writes in the log book
                            tblNew.S_Sync(iNext)    = tblOld.S_Sync(iAt);
                            tblNew.SyncTime(iNext)  = tblOld.SyncTime(iAt);
                        end
                    end
                    
                    iNext = iNext + 1;
                end % loop through sync events from one parsed SUESI file
            end % loop through list of .mat files
            
            % Replace the sync table all at once - trigger listeners one time
            oWave.tableSUESISync = tblNew;
            
            % In the transmitter timing table, find the entry that was in play
            % for the longest time (as measured by S= entries). Decode that and
            % pop it into the idealized waveform table.
            %
            % NB: decodeSUESI.m pops a final empty line into the table for each
            % individual SUESI log so that I can diff S= numbers simply without
            % having to account for the final real timing entry not being
            % followed by others.
            tbl = cwave.GetDfltFor( 'tableWaveIdeal' );
            if ~isempty( tblWave )
                [~,iAt]     = max( diff( tblWave.SuesiSec ) );
                [nSamp,nA]  = decodeSUESITXTiming( tblWave.Timing(iAt), 'Brief' );
                
                tbl{1:numel(nSamp),:}   = missing();
                tbl.Time(:)             = nSamp / 400;  % cvt SUESI sample at 400Hz to time
                tbl.Amplitude(:)        = nA;
            end
            oWave.tableWaveIdeal = tbl; % Only trigger the listener ONCE
            
            return;
        end % Update_SuesiMAT
        
        % Change to Cuda GPS TS can affect the Cuda config table. Update
        % backwards from the TS to the config (time ranges specifically)
        function Update_CudaCfg_from_CudaGPS( oWave )
            if oWave.bLoading; return; end
            % Changes to the destination table should be made all at once, not
            % piecemeal
            tCCfg = oWave.tableCudaCfg;
            
            % Remove NAVx entries from tableCudaCfg if they aren't in the GPS
            % time series anymore
            nDevList    = unique( oWave.tableCudaGPS.DeviceNo );
            bDel        = ~ismember( tCCfg.DeviceNo, nDevList );
            if any(bDel)
                oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_CudaCfg ...
                    , ['Barracuda GPS change caused deletion of NAV:' ...
                       num2str( onerow( unique( tCCfg.DeviceNo(bDel) ) ) )] );
                tCCfg(bDel,:)   = [];
            end
            
            % Add entries for NAVx that are in GPS but not in the config
            bAdd = ~ismember( nDevList, unique( tCCfg.DeviceNo ) );
            if any( bAdd )
                nAddList    = onerow( nDevList(bAdd) );
                for nDevNo  = nAddList
                    tCCfg{end+1,:}          = missing();
                    tCCfg.DeviceNo(end)     = nDevNo;
                    tCCfg.ListenFreq(end)   = 12.5;   % typical configuration
                    
                    % Get the date range of GPS data
                    b = (oWave.tableCudaGPS.DeviceNo == nDevNo);
                    tCCfg.DateFrom(end)     = oWave.tableCudaGPS.Time(find(b,1,'first'));
                    tCCfg.DateTo(end)       = oWave.tableCudaGPS.Time(find(b,1,'last'));
                end
                oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_CudaCfg ...
                    , ['Auto-added NAV from GPS time series: ' num2str( nAddList )] );
            end
            
            % Update the table
            oWave.tableCudaCfg = sortrows( tCCfg, 'DeviceNo' );
            
            return;
        end % Update_CudaCfg_from_CudaGPS
        
        % If both the ideal & snap waveform tables are cleared, then the
        % harmonics should also be cleared
        function Update_WaveHarmonics( oWave )
            if oWave.bLoading; return; end
            if isempty( oWave.tableWaveIdeal ) && isempty( oWave.tableWaveSNAP )
                oWave.ClearLogOfType( cwave.sLog_Wave_Harmonics );
                oWave.tableHarmonics = cwave.GetDfltFor( 'tableHarmonics' );
            end
        end % Update_WaveHarmonics
        
        % When the list of binaries changes, update the RxCfg - removing
        % binaries from Rx Cfgs which are no longer in the the file list. Do for
        % both nodal & towed receivers
        function Update_RxCfg( oWave )
            if oWave.bLoading; return; end
            
            % Nodal RXs
            cBinList = fullfile( oWave.tableRxCfg.BinPath, oWave.tableRxCfg.BinFile );
            bDrop = strlength(cBinList) > 0 & ~ismember( lower( cBinList ), lower( oWave.cFiles_Bin ) );
            if any( bDrop )
                tRx = oWave.tableRxCfg;
                tRx.BinFile(bDrop) = missing();
                tRx.BinPath(bDrop) = missing();
                oWave.tableRxCfg = tRx; % drop changes all at once
                
                % Log the changes
                for iRx = onerow(find(bDrop))
                    oWave.AddLog( cwave.LogOK, cwave.sLog_Nodal_RxCfg ...
                        , [char(tRx.RxName(iRx)) ':: binary no longer in file list. Dropped'] );
                end
            end
            
            % Towed RXs
            cBinList = fullfile( oWave.tableTowRxCfg.BinPath, oWave.tableTowRxCfg.BinFile );
            bDrop = strlength(cBinList) > 0 & ~ismember( lower( cBinList ), lower( oWave.cFiles_Bin ) );
            if any( bDrop )
                tRx = oWave.tableTowRxCfg;
                tRx.BinFile(bDrop) = missing();
                tRx.BinPath(bDrop) = missing();
                oWave.tableTowRxCfg = tRx; % drop changes all at once
                
                % Log the changes
                for iRx = onerow(find(bDrop))
                    oWave.AddLog( cwave.LogOK, cwave.sLog_Towed_RxCfg ...
                        , [char(tRx.RxName(iRx)) ':: binary no longer in file list. Dropped'] );
                end
            end
        end % Update_RxCfg
    end % invalidate/update functions used by the "set." methods
    
    %---------------------------------------------------------------------------
    % All properties below are for internal running of the UI and are therefore
    % set 'Transient' so that they do NOT get saved to a .mat file. They will be
    % reconstructed from scratch every time an object is loaded.
    %---------------------------------------------------------------------------
    properties( Transient, Access = public )
        hFig                    % main UI window
        bChgd logical = false   % do the data need to be saved?
        hTree                   % tree control for tabs & their panels (excluding w_tabConfig, where it lives)
    end 
    
    properties( Transient, Access = protected )
        bLoading logical = true;% are we currently loading an object's data?
        hMenuFile               % 'File' menu (kept for MRU list)
        hMRU                    % list of MRU (Most-Recently-Used) menu handles
        
        % Workbench tabs
        otabgrp                 % UITabGroup containing all the tabs
        otabConfig              % config tab for Survey settings like folders, etc...
        otabShipData            % Misc processing of ship logs (MET, lat/lon, etc...)
        otabSUESI               % SUESI processing tab
        otabWaveform            % Waveform handling
        otabRxNav               % RX Benthos Nav
        otabiLBL                % Inverted long-baseline Nav (e.g. barracuda Nav)
        otabCSEM                % Nodal CSEM
        otabTowed               % Towed CSEM
    end % protected properties (accessible by the class & any subclasses)
    %
    % NB: The above properties *should* be immutable - they get set one time and
    % should never change. However because of the way MatLab's loadobj() works,
    % I had to separate out the creation of the UI from the constructor. MatLab
    % calls the constructor, attempts to load the data, then calls loadobj. If
    % the UI occurs during the constructor, things take a long time and get
    % really messy because all the listeners will be active.
    %
    
    %---------------------------------------------------------------------------
    % Dependent (i.e. virtual) properties don't actually exist. They are created
    % by function call at the time of use
    %---------------------------------------------------------------------------
    properties( Dependent )
        sSaveFile       % fullfile( sDir_Main, [sFileName '.wave.mat'])
        sLogDir         % fullfile( sDir_Main, sDir_Logs )
        sPlotDir        % fullfile( sDir_Main, sDir_Plot )
        sEditDir        % fullfile( sDir_Main, sDir_Edit )
        sSuesiDir       % fullfile( sDir_Main, sDir_Suesi )
        sSPDir          % fullfile( sDir_Main, sDir_RxCfg )
        sCSEMDir        % fullfile( sDir_Main, sDir_CSEM )
        
        sPlotSubtitle   % project name for putting as sub-title on plots
        
        bSHemi          % turns sUTMHemi into flag for UTM2LonLat, etc...
        cUTMHemi        % returns sUTMHemi as a char(1) ('N' or 'S') not string
        sUTMZoneDisp    % returns 'Zone NNC' (e.g. 'Zone 49S') for plot displays
        sUTMZoneFile    % like above but with '_' instead of ' '
        
        % suggested folders for holding source data. See get. methods below
        sSubBin
        sSubCuda
        sSubBPings
        sSubSuesi
        sSubShipGPS
        sSubShipGyro
        sSubShipMET
        sSubShipWinch
        sSubSoundV
    end
    
    %---------------------------------------------------------------------------
    % Dependent property get/set methods
    %
    % NB: MatLab requires get/set methods to be in a methods block which has no
    % stated properties. That's why these are here by themselves.
    methods
        % The sSaveFile property is virtual. It is composed of a path & filename
        % which are kept separately for various config-related reasons.
        function s = get.sSaveFile(oWave)
            if isempty( oWave.sFileName )   % don't add the extensions if no filename
                s = fullfile( oWave.sDir_Main, '' );
            else
                s = fullfile( oWave.sDir_Main, [oWave.sFileName '.wave.mat'] );
            end
            s = ChkSlash( s );
            return;
        end 
        function     set.sSaveFile( oWave, sPathFile )
            if isempty( sPathFile )
                oWave.sDir_Main = '';   % NB: '' is preferred over [] for some functions
                oWave.sFileName = '';
            else
                [oWave.sDir_Main, oWave.sFileName] = fileparts( ChkSlash( sPathFile ) );
                oWave.sFileName = strrep( oWave.sFileName, '.wave', '' );
            end
            return;
        end
        function s = get.sLogDir(oWave)
            s = fullfile( oWave.sDir_Main, oWave.sDir_Logs );
            return;
        end
        function s = get.sPlotDir(oWave)
            s = fullfile( oWave.sDir_Main, oWave.sDir_Plot );
            return;
        end
        function s = get.sEditDir(oWave)
            s = fullfile( oWave.sDir_Main, oWave.sDir_Edit );
            return;
        end
        function s = get.sSuesiDir(oWave)
            s = fullfile( oWave.sDir_Main, oWave.sDir_Suesi );
            return;
        end
        function s = get.sSPDir(oWave)
            s = fullfile( oWave.sDir_Main, oWave.sDir_RxCfg );
            return;
        end
        function s = get.sCSEMDir(oWave)
            s = fullfile( oWave.sDir_Main, oWave.sDir_CSEM );
            return;
        end
        
        function s = get.sPlotSubtitle(oWave)
            s = ['Survey: "' oWave.sFileName '"'];
            return;
        end 
        
        function b = get.bSHemi(oWave)
            b = strncmpi( oWave.sUTMHemi, 'S', 1 );
            return;
        end
        function c = get.cUTMHemi(oWave)
            c = char(oWave.sUTMHemi);
            c(2:end) = [];
            return;
        end
        function sZone = get.sUTMZoneDisp(oWave)
            sZone   = sprintf( 'Zone %d%c', oWave.nUTMZone, oWave.cUTMHemi );
        end
        function sZone = get.sUTMZoneFile(oWave)
            sZone = strrep( oWave.sUTMZoneDisp, ' ', '_' );
        end
        
        function s = get.sSubBin(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{1,1} );
        end
        function s = get.sSubCuda(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{3,1} );
        end
        function s = get.sSubBPings(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{4,1} );
        end
        function s = get.sSubSuesi(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{7,1} );
        end
        function s = get.sSubShipGPS(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{9,1} );
        end
        function s = get.sSubShipGyro(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{10,1} );
        end
        function s = get.sSubShipMET(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{11,1} );
        end
        function s = get.sSubShipWinch(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{12,1} );
        end
        function s = get.sSubSoundV(oWave)
            s = fullfile( oWave.sDir_Main, cwave.sSuggSub, cwave.cSuggDir{13,1} );
        end
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% EVENTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    events
        % These events are triggered by w_panelInput when one or more config
        % vars change values due to user editing. See the public properties
        % section above for comments on which variables trigger each event
        UTM_VarChg
        SuesiTab_VarChg
        RxNavTab_VarChg
        TxNavLBLTab_VarChg
        CSEMUI_VarChg           % on both nodal & towed CSEM tabs
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% CONSTANTS related to various data elements %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    properties( Constant )
        % Name for the valeport's entry in tableVProfile ("velocity profiles
        % over time"). Useful for when there are multiple ships involved or very
        % long cruises where storms change water conditions
        sVProfile_Valeport = 'Valeport';
        
        % Columns of the cLog cell array
        colLog      = colstruct( 'Status', 'Type', 'Date', 'User', 'Desc' );
        
        % Status of log entry
        LogOK       = 0;
        LogWarn     = 1;
        LogError    = 2;
        
        % Miscellaneous settings
        MaxRxCh     = 8;    % max # of receiver channels supported
        
        % List of ellipsoids supported by getEllipsoid, UTM2LonLat, LonLat2UTM
        cEllList    = ["wgs84","intl24","ed50","nad27","grs80","nad83","grs67","wgs72","wgs66","wgs60","clrk66","clrk80","intl67","agd66"];
        
        % Suggested "store your data here" folders & descriptions
        sSuggSub    = 'Data';   % sub-dir under main. All suggesteds are below this
        cSuggDir    = {
            'Bin', 'RX binaries (OBEM & Vulcan)'
            'Docs_RxDrop_Checkout_Etc', 'Checkout sheets, list of drop locations, etc...'
            'Logs_Barracuda', 'Text log files of GPS data from the barracudas'
            'Logs_BenthosPings', 'Text log files from the benthos pinging the barracudas'
            'Logs_RxNodal', 'Startup, end, & compass dump logs'
            'Logs_RxTowed_TET', 'Startup, end, compass for Vulcans and TETs'
            'Logs_SUESI', 'SUESI output stream text files'
            'Reports', 'Ship report on geometry & offsets, PDF logbook, other valuable docs'
            'Ship_GPS', 'GPS files for the ship location during the survey'
            'Ship_Gyro', 'Gyroscope (direction ship''s hull is pointing)'
            'Ship_MET', 'Meteorological info (air pressure for Valeport tare)'
            'Ship_Winch', 'Ship wire-out log for the deep-tow winch'
            'SoundVelocity', 'XBT casts & other sound-velocity-in-water logs'
            };
        
        %-----------%
        % Log types %
        %-----------%
        %-- Misc
        sLog_Cfg        = 'Config';
        
        %-- Various Ship log file lists
        sLog_ShipGPS    = 'SHIP_GPS';
        sLog_ShipGyro   = 'SHIP_Gyro';
        sLog_ShipWinch  = 'SHIP_Winch';
        sLog_ShipMET    = 'SHIP_MET';
        sLog_ShipSIOMET = 'SHIP_SIOMET';
        
        %-- Ship data processing
        sLog_ShipData   = 'SHIP_Data';    % actions on tableShipTS
        sLog_ProcMET    = 'SHIP_METProc'; % processing of MET file
        sLog_AtmPres    = 'SHIP_AtmPres'; % actions on tableAtmPres
        sLog_ProcSIOMET = 'SHIP_SIOMETProc'; % processing of SIO all-in-one MET files
        
        %-- SUESI log processing
        sLog_SUESI      = 'SUESI';      % prefix for use with GetLogOfType() & ShowLogForType()
        sLog_S_UI       = 'SUESI_UserInput';
        sLog_S_Files    = 'SUESI_Logs';
        sLog_S_Decode   = 'SUESI_Decode';
        sLog_S_Mat      = 'SUESI_MatFiles';
        sLog_S_STime    = 'SUESI_EditSync';
        sLog_S_Sync     = 'SUESI_Sync';     % this is the sync action
        sLog_S_SDM      = 'SUESI_SDM';
        sLog_S_Benthos  = 'SUESI_Benthos';
        sLog_S_Vulcan   = 'SUESI_Vulcan';
        sLog_S_ValeP    = 'SUESI_Valeport';
        
        %-- Tow timing belongs to several tabs but is an offshoot of SUESI
        sLog_TowTime    = 'SUESI_TowTime';
        
        %-- Waveform
        sLog_Wave           = 'Waveform';
        sLog_Wave_Files     = 'Waveform_SNAP_Files';
        sLog_Wave_SNAP      = 'Waveform_SNAP2Wave';
        sLog_Wave_Ideal     = 'Waveform_Ideal2Wave';
        sLog_Wave_Harmonics = 'Waveform_Harmonics';
        
        %-- RX Nav
        sLog_GPS2Ducer      = 'RXNav_GPS2Ducer';
        sLog_RxN_UI         = 'RXNav_UserInput';
        sLog_RxDrop         = 'RXNav_DropList';
        sLog_RxPings        = 'RXNav_BenthosFiles';
        sLog_RxVProfile     = 'RXNav_VelProfile';
        sLog_RxNavAction    = 'RXNav_Navigate';
        sLog_RxTable        = 'RXNav_Table';
        
        %-- USBL & iLBL (Barracuda Nav)
        sLog_TxNav          = 'TXNav';
        sLog_TxN_BLogs      = 'TXNav_BarracudaLogs';
        sLog_TxN_BParse     = 'TXNav_ParseBarracudaLogs';
        sLog_TxN_CudaTS     = 'TXNav_BarracudaTS';
        sLog_TxN_CudaCfg    = 'TXNav_BarracudaCfg';
        sLog_TxN_UI         = 'TxNav_UserInput';
        sLog_TxNavAction    = 'TxNav_Navigate';
        sLog_TxN_Table      = 'TxNav_Table';
        sLog_TxN_CTET       = 'TXNav_CTET';
        
        %-- Both Nodal & Towed CSEM
        sLog_CSEM_Bin       = 'CSEM_BinFiles';
        sLog_CSEM_UI        = 'CSEM_UserInput';
        
        %-- Nodal CSEM
        sLog_Nodal          = 'Nodal';
        sLog_Nodal_RxCfg    = 'Nodal_RxCfg';
        sLog_Nodal_MakeSP   = 'Nodal_MakeSPFiles';
        sLog_Nodal_CSEM     = 'Nodal_CSEM';
        sLog_Nodal_Output   = 'Nodal_OutputFiles';
        sLog_Nodal_DM       = 'Nodal_ExportToDataMan';
        
        %-- Towed CSEM
        sLog_Towed          = 'Towed';
        sLog_Towed_RxCfg    = 'Towed_RxCfg';
        sLog_Towed_CSEM     = 'Towed_CSEM';
        sLog_Towed_Output   = 'Towed_OutputFiles';
        sLog_Towed_Export   = 'Towed_Export2MARE';
        
    end % constants for data elements
    
    %---------------------------------------------------------------------------
    % Info about each editable variable for use in w_panelInput and UIEditVars
    %---------------------------------------------------------------------------
    properties( Constant )
        % NB: fcnValid must throw an error to indicate invalid data
        % NB: fcnValid will ONLY be given the one variable with no context. If
        %     you need to cross-check a value against others, then you need to
        %     pass a contextual validation function to w_panelInput and it will
        %     take care of the rest. For an example, follow 'nWindowLen'.
        stVarInfo = struct( ...
        ... SUESI tab ----------------------------------------------------------
            'nTxDipLen', struct( ...
                  'sDesc', 'TX dipole length (m)' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter the length of SUESI''s dipole for this ' ...
                            'survey. If you used multiple dipole lengths ' ...
                            'then you must create multiple WAVE projects, ' ...
                            'one for each dipole length.' ...
                           ] ...
                ) ...
            , 'nFixSuesiCOG', struct( ...
                  'sDesc', 'SUESI COG correction (deg)' ...
                , 'fcnValid', @(n)(mustBeInRange(n,-180,180)) ...
                , 'sSpecialBtn', 'Btn:0:None' ...
                , 'sHelp', ['Enter a correction value to make SUESI''s ' ...
                            '"course over ground" (COG) match the ship''s COG. ' ...
                            'This is only necessary if SUESI''s internal compass ' ...
                            'is not mounted correctly.' ...
                           ] ...
                ) ...
            , 'sZBins', struct( ...
                  'sDesc', 'Depth Profile bins (m)' ...
                , 'fcnValid', @cwave.ChkDepthBins ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter a MATLAB expression for a set of depth bins ' ...
                            'to use when creating the sound velocity, temperature, ' ...
                            'and conductivity vs depth profiles from SUESI''s ' ...
                            'Valeport data. (Ex: 0:10:200 300:100:5000) ' ...
                            'The set values must be UNIQUE and increasing.' ...
                           ] ...
                ) ...
            , 'sLimitVVel', struct( ...
                  'sDesc', 'Valeport Velocity [min max] (m/s)' ...
                , 'fcnValid', @(s)cwave.ChkMinMax(s,'Velocity') ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter min and max values for the Valeport-derived ' ...
                            'velocities. ' ...
                            'The two values must be UNIQUE and increasing.' ...
                           ] ...
                ) ...
            , 'sLimitVTemp', struct( ...
                  'sDesc', 'Valeport Temp [min max] (C)' ...
                , 'fcnValid', @(s)cwave.ChkMinMax(s,'Temp') ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter min and max values for the Valeport-derived ' ...
                            'temperatures. ' ...
                            'The two values must be UNIQUE and increasing.' ...
                           ] ...
                ) ...
            , 'sLimitVCond', struct( ...
                  'sDesc', 'Valeport Conductivity [min max] (S/m)' ...
                , 'fcnValid', @(s)cwave.ChkMinMax(s,'Conductivity') ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter min and max values for the Valeport-derived ' ...
                            'conductivities. ' ...
                            'The two values must be UNIQUE and increasing.' ...
                           ] ...
                ) ...
        ... RX Nav tab ---------------------------------------------------------
            , 'nRxNavMaxTWTT', struct( ...
                  'sDesc', 'Max TWTT to consider (s)' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter the upper limit on Two-way-travel-time ' ...
                            'to consider when doing Benthos-based RX navigation.' ...
                           ] ...
                ) ...
            , 'nRxNavMaxRange', struct( ...
                  'sDesc', 'Max Range to consider (km)' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter the upper limit on benthos-to-RX range (km) ' ...
                            'to consider when doing Benthos-based RX navigation.' ...
                           ] ...
                ) ...
            , 'nRxNavTransDelay', struct( ...
                  'sDesc', 'Transponder reply delay (ms)' ...
                , 'fcnValid', @mustBeNonnegative ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Some transponders have a short delay before sending ' ...
                            'the reply ping. For ORE this is 12.5 ms. For the ones''s' ...
                            'we''ve been using at SIO forever, this is 0 ms.' ...
                           ] ...
                ) ...
        ... Nodal & Towed CSEM tabs --------------------------------------------
            , 'nWindowLen', struct( ...
                  'sDesc', 'CSEM FFT window length (s)' ...
                , 'fcnValid', @mustBePositive ... % NB: also uses Chk_nWindowLen()
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['The length of the CSEM FFT window. This should ' ...
                            'normally be set to one waveform length.' ...
                           ] ...
                ) ...
            , 'nStackLen', struct( ...
                  'sDesc', 'CSEM stacking window length (s)' ...
                , 'fcnValid', @mustBePositive ... % NB: also uses Chk_nStackLen()
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['The length of the CSEM stacking window. This should ' ...
                            'be at least a few FFT window lengths and is usually ' ...
                            'set to 60 seconds, which roughly corresponds to ' ...
                            '40-50 meters along a typical tow path.' ...
                           ] ...
                ) ...
        ... TX iLBL Nav tab ----------------------------------------------------
            , 'nGPStoWireZeroN', struct( ...
                  'sDesc', 'NORTH offset from GPS to Wire-Zero (m)' ...
                , 'fcnValid', @mustBeNonpositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['The offset from the ship''s GPS mast to the ' ...
                            'top of the deep-tow A-frame when the ship is ' ...
                            'pointed due north. Negative numbers indicate ' ...
                            'south. This number should always be negative. ' ...
                            'We specify the A-frame because that''s usually ' ...
                            'a good proxy for where SUESI is in the water ' ...
                            'when zeroing the winch wire - which is what ' ...
                            'we actually need here.' ...
                           ] ...
                ) ...
            , 'nGPStoWireZeroE', struct( ...
                  'sDesc', 'EAST offset from GPS to Wire-Zero (m)' ...
                , 'fcnValid', @mustBeNonNan ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', 'Similar to the North offset. See help above.' ...
                ) ...
            , 'nTxCtrOffset', struct( ...
                  'sDesc', 'Range: SUESI to the antenna midpoint (m)' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['The offset between SUESI''s tranducer and the middle ' ...
                            'of the antenna. The formula is: <distance ' ...
                            'to near electrode> + (<dist to far> - <dist near>)/2 ' ...
                            '+ <length of copper> / 2. For deep tow this is usually ' ...
                            '10 + (260 - 10)/2 + 30.48/2.' ...
                           ] ...
                ) ...
            , 'nMinWireLBL', struct( ...
                  'sDesc', 'Use ship-track for SUESI when wire-out < N (meters):' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['When the wire-out is less than this value ' ...
                            'the iLBL navigation will ignore barracuda ' ...
                            'data and position SUESI directly in the ' ...
                            'ship-track behind the wire-0 point. Keep ' ...
                            'in mind that the force required to push ' ...
                            'SUESI out of track grows *slowly* with sin() of the ' ...
                            'angle of deflection while the force of the ' ...
                            'water flowing over SUESI from the direction ' ...
                            'of motion decreases slowly by cos(). So a 15 ' ...
                            'degree deflection requires 4x the side-force ' ...
                            'as the forward friction.     NOTE: If you want ' ...
                            'to ignore barracuda nav, make this value larger ' ...
                            'than the max wire-out and SUESI will be fixed ' ...
                            'to the ship-track trailing the ship.' ...
                           ] ...
                ) ...
            , 'nMADfactor', struct( ...
                  'sDesc', 'Drop TWTT outside median +/- MAD * this factor:' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['In order to control the copious number of spurious ' ...
                            'points generated by the Benthos system, only pings ' ...
                            'whose TWTT is within +/- N*MAD of the median are ' ...
                            'kept. This field is the factor <N>. 2 is good.'
                           ] ...
                ) ...
            , 'nBPingLimit', struct( ...
                  'sDesc', 'Max TWTT for Barracudas (s)' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Ignore all Benthos direct barracuda pings where ' ...
                            'the TWTT is greater than this limit.' ...
                           ] ...
                ) ...
            , 'nCNavNo', struct( ...
                  'sDesc', 'CTET''s w=[nn] number in SUESI logs' ...
                , 'fcnValid', @mustBeInteger ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['Enter the device number the CTET used to report ' ...
                            'it''s depth through the SUESI logs. This is ' ...
                            'usually 2.' ...
                           ] ...
                ) ...
            , 'nCDist', struct( ...
                  'sDesc', 'Distance of the CTET behind SUESI (m)' ...
                , 'fcnValid', @mustBePositive ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['How far behind SUESI''s transducer was the CTET ' ...
                            'attached to the tow train?' ...
                           ] ...
                ) ...
            , 'nCListenFreq', struct( ...
                  'sDesc', 'Frequency the CTET listened on (Hz)' ...
                , 'fcnValid', @(n)cwave.ChkPingFreq(n,false) ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['What frequency did the CTET listen to? ' ...
                            'Valid frequencies start at 8.0 and go up in ' ...
                            'steps of 0.5 to 15.0.' ...
                           ] ...
                ) ...
            );
        
    end % constants for w_panelInput & UIEditVars
    
    %---------------------------------------------------------------------------
    % Constants related to UI consistency
    %---------------------------------------------------------------------------
    properties( Constant )
        % Colors for log statuses, etc...
        nClrBkgd    = get( groot(), 'DefaultFigureColor' ) % MatLab's standard fig/tab/panel background color
        nClrOK      = [0    0.63 0   ];     % darker green
        nClrWarn    = [0.84 0.72 0.14];     % more gold than yellow
        nClrError   = [1    0    0   ];
        
        % General control settings
        FontSize    double = 13;    % default fontsize everywhere
        
        BtnHt       double =  30;   % uipushbutton height
        BtnWd       double = 100;   % uipushbutton width
        LblHt       double =  25;   % uilabel & uieditfield height
        
        % Useful characters
        CharChk     char   = char(hex2dec('2714')); % UNICODE check mark character (2714 is heavier version)
        CharCross   char   = char(hex2dec('2718')); % UNICODE "X" cross-off char (2718 is heavier version)
        Char3Line   char   = char(hex2dec('2630')); % UNICODE tri-gram menu (hamburger button)
        
    end % constants for UI
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% STATIC METHODS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods( Static )
        
        %-----------------------------------------------------------------------
        % Load the MRU (most recently used) menu items, if any.
        function [cMRU,sMRU] = GetMRUList()
            % Make the name of the mat file that holds the MRU
            [sPath, sFile] = fileparts( mfilename('fullpath') );
            sMRU = fullfile( sPath, [sFile '.mru'] );
            
            % If it exists, load it
            if isfile( sMRU )
                load( sMRU, '-mat', 'cMRU' );
            else
                cMRU = {};
            end
            return;
        end % GetMRUList
        
        %-----------------------------------------------------------------------
        % Return the class default value for the given variable.
        function var = GetDfltFor( sVar, nEmptyRows )
            mc = ?cwave;        % get the meta.class object for the class
            iProp = find( strcmpi( {mc.PropertyList.Name}, sVar ) ); % Find the property
            if isempty( iProp )
                error( 'Class cwave does not contain property %s', sVar );
            end
            if ~mc.PropertyList(iProp).HasDefault
                error( 'Property cwave.%s has no default value', sVar );
            end
            var = mc.PropertyList(iProp).DefaultValue;
            
            % If a table has been requested, a number of empty rows can also be
            % requested
            if istable( var ) && exist( 'nEmptyRows', 'var' ) && ~isempty( nEmptyRows )
                var{1:nEmptyRows,:} = missing();
            end
            
            return;
        end % GetDfltFor
        
        %-----------------------------------------------------------------------
        % Validation function for sZBins
        function ChkDepthBins( s )
            mustBeNonempty( s );
            n = str2num( s );
            mustBeVector( n );
            mustBeNonNan( n );
            mustBeNonnegative( n );
            if any( diff( n ) <= 0 )
                error( 'Value must be unique and ascending in value.' );
            end
            return;
        end % ChkDepthBins
        
        %-----------------------------------------------------------------------
        % Validation function for [min max] which must be entered as text
        function ChkMinMax( s, sName )
            n = str2num( s );
            assert( numel(n) == 2, ['Valeport ' sName ' Min Max must evaluate to exactly two numbers'] );
            assert( n(1) < n(2), ['Valeport ' sName ' Min must be less than Max'] );
            return;
        end % ChkMinMax
        
        %-----------------------------------------------------------------------
        function mustBePositiveInteger( n )
            mustBePositive( n );
            mustBeInteger( n );
            return;
        end % mustBePositiveInteger
        
        %-----------------------------------------------------------------------
        % Validation for various pinger-frequency related fields. Can optionally
        % allow zero
        function ChkPingFreq( n, bZeroOK )
            if bZeroOK
                mustBeMember( n, [0 8:0.5:15] );
            else
                mustBeMember( n, 8:0.5:15 );
            end
            return;
        end % ChkPingFreq
        
        %-----------------------------------------------------------------------
        % Check that a list of RX names are valid. No spaces, or invalid
        % characters like slashes, question marks, etc... Need to be filename
        % suitable.
        function bOK = ChkRxName( cName )
            persistent pat
            if isempty( pat )
                pat = asManyOfPattern( alphanumericsPattern() | characterListPattern("-_.") );
            end
            bOK = matches( cName, pat );
            return;
        end % ChkRxName
        
        %-----------------------------------------------------------------------
        % Check a list of Rx Names for duplicates & flag them as ~bOK.
        function bOK = FlagDupRxNames( cRxName )
            if ~iscell(cRxName)     % only one name passed
                bOK = true;
                return;
            end
            [c,~,ic] = unique(upper(cRxName));
            if numel(c) ~= numel(cRxName)
                % Flag the copies
                nCnt    = accumarray( ic, ones(size(ic)) );
                bOK     = (nCnt(ic) == 1);
            else
                bOK = true(numel(cRxName),1);
            end
            return;
        end % FlagDupRxNames
        
        %-----------------------------------------------------------------------
        % Return the index (or NaN) of the entry in tbl for each datetime 'dt'
        % between tbl.DateFrom and tbl.DateTo
        function idx = IndexIntoTimeTable( tbl, dt )
            if height( tbl ) == 1  % one entry always covers all time
                idx = ones( numel(dt), 1 );
            else
                idx = NaN( numel(dt), 1 );
                for i = 1:height(tbl)
                    % NB: datetime class has it's own between() function which
                    % overrides mine. Sigh.
                    idx( dt >= tbl.DateFrom(i) & dt <= tbl.DateTo(i) ) = i;
                end
            end
            return;
        end % IndexIntoTimeTable
        
        %-----------------------------------------------------------------------
        % loadobj is called by MatLab's load() whenever a class instance is
        % loaded from a .mat file. If everything is OK, the param is a class
        % instance. If something failed, it is a struct and I have to copy the
        % field values over manually. This latter case occurs when attempting to
        % load older versions of the class into a newer version. It is
        % explicitly for backwards compatibility support.
        function oWave = loadobj( oWave )
            if isstruct( oWave )
                disp( 'Old version being loaded. Attempting to upgrade...' );
                
                % Load failed - likely an older version that doesn't quite fit
                % into the new structure. Try to copy as many of the properties
                % as possible
                stLoad = oWave;
                oWave = cwave();
                
                % Loop over the properties in the object and copy as appropriate
                % from the load structure
                mc = ?cwave;        % get the meta.class object for the class
                cVars = {mc.PropertyList.Name};
                cVin  = fieldnames( stLoad );
                for iVar = 1:numel(cVars)
                    sVar = cVars{iVar};
                    if ~ismember( sVar, cVin )  % new variables not in the old obj
                        continue;
                    end
                    if istable( oWave.(sVar) )
                        % Do tables one column at a time so eliminated columns
                        % are not copied and columns with changed attributes
                        % that no longer fit validation get skipped.
                        tIn = stLoad.(sVar);
                        tOut = cwave.GetDfltFor( sVar, height(tIn) );
                        cColList = tOut.Properties.VariableNames;
                        cColIn = tIn.Properties.VariableNames;
                        for iCol = 1:numel(cColList)
                            sCol = cColList{iCol};
                            if ismember( sCol, cColIn )
                                try
                                    tOut(:,sCol) = tIn(:,sCol);
                                catch Me
                                    fprintf( '... Failed on %s(%s)::%s\n', sVar, sCol, Me.Message );
                                end
                            end
                        end
                        oWave.(sVar) = tOut;
                        
                        clear tIn tOut cColList cColIn iCol sCol
                    else
                        % Standard variable
                        try
                            oWave.(sVar) = stLoad.(sVar);
                        catch Me
                            fprintf( '... Failed on %s::%s\n', sVar, Me.Message );
                        end
                    end
                end
                disp( '... Done upgrading.' );
                
                % Save memory
                clear stLoad mc cVars cVin iVar sVar 
            end
            
            % Now create the UI - this can take time
            oWave.MakeUI();
            
            return;
        end % loadobj
        
    end % static methods (i.e. don't require a class instance to run)
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% PUBLIC PROTOTYPE METHODS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % NB: These methods are found in external .m files in the @cwave folder
    methods( Static, Access = public )
        % Validation functions for various tables. Fit for use with
        % w_panelTable.m, UITableEdit.m, UITableImport.m, etc...
        [bOK,cErrMsg] = ValidateAtmPTable(  tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateSyncTable(  tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateGPS2Ducer(  tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateRxDrop(     tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateVelProfile( tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateRxNav(      tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateTowTimes(   tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateRxCfg( tRx, tRxCh, sCalibDir )      % exception. Wrappered in w_tabNodalCSEM.m
        [bOK,cErrMsg] = ValidateTowRxCfg( tRx, tRxCh, sCalibDir )   % exception. Wrappered in w_tabTowedCSEM.m
        [bOK,cErrMsg] = ValidateTxNav(      tData, hUIFig, bQuery )
        [bOK,cErrMsg] = ValidateCudaCfg(    tData, hUIFig, bQuery )
    end
    
    methods( Access = public )
        MergeShipData( o )              % PROCESS: merge ship GPS, COG, wire-out into ship time series table
        ProcessMETFiles( o )            % PROCESS: simple pressure files --> avg atm pressure table
        ProcessSIOMETFiles( o )         % PROCESS: SIO all-in-one MET files --> avg atm pressure table, ship time series
        ParseSUESILogs( o, sScope )     % PROCESS: parse SUESI log files
        SNAP2Waveform( o )              % PROCESS: create normalized waveform from SNAPs
        SelectHarmonics( o )            % PROCESS: slct waveform harmonics from SNAP or idealized waveforms
        SyncSUESILogs( o )              % PROCESS: sync SUESI logs with real time & ship data
        RxNav( o )                      % PROCESS: Navigate Receivers using Benthos pings
        MakeSP( o )                     % PROCESS: make .sp files for MT from nodal Rx config info
        TxNav( o )                      % PROCESS: iLBL nav of transmitter
        NodalCSEM( o, sScope )          % PROCESS: Nodal CSEM FFT & stacking
        ExportToDataMan( o )            % PROCESS: Export Nodal CSEM to DataMan
        TowedCSEM( o, sScope )          % PROCESS: Towed CSEM FFT & stacking
        ExportTow2MARE( o )             % PROCESS: Export Towed CSEM to MARE2DEM
        
        ShowLogForType( o, sType )      % UTILITY: show all log entries for a specific type
        AtmPEdit( o )                   % UTILITY: w_panelTable edit function for Atm Pressure table (shared on multiple tabs)
        UIVProfiles( o )                % UTILITY: edit the Velocity Profile list
        UITowTimes( o )                 % UTILITY: edit tableTow (tow times & Tx time lags)
        UIRxCfg( o )                    % UTILITY: edit nodal RX configurations
        UITowRxCfg( o )                 % UTILITY: edit towed RX configurations
        
        % UTILITY: Set the UTM info and notify listeners if there's a change
        SetUTMInfo( oWave, nZone, bSHemi, sEllipsoid, bLock )
        
        % UTILITY: convert lat,lon respecting any forced UTM zone and checking
        % for data that crosses zone boundary (& vice versa)
        [nE,nN] = LonLat2UTM( oWave, sLog, nLon, nLat )
        [nLon,nLat] = UTM2LonLat( oWave, nE, nN );
        
        % UTILITY: read data using user-extensible file/data types from
        % ListFmts_... codes
        [bOK, nData] = GetDataFromUserConfigurableTypes( oWave, cFiles, tbl, sLog, sType )
        
        % NB: Contextual validation functions are used by w_panelInput and
        % UIEditVars to cross-check one value against another in the same UI or
        % against data in some other part of oWave (like waveform length, etc)
        Chk_nWindowLen( o, stVars )     % CONTEXTUAL VALIDATION
        Chk_nStackLen( o, stVars )      % CONTEXTUAL VALIDATION
        
        % NB: some of these plot routines are used on multiple tabs
        PlotAtmPressure( o )            % PLOT: avg atm pressure table
        PlotShipTS( o )                 % PLOT: aggregated ship time series
        PlotWaveSnap( o )               % PLOT: waveform derived from median of SNAPs
        PlotWaveIdeal( o )              % PLOT: idealized waveform designed by user
        PlotWaveHarmonics( o )          % PLOT: harmonics from a waveform, either SNAP or Ideal
        
        PlotValeport( o )               % PLOT: Valeport-derived depth profiles
        PlotVelProfiles( o )            % PLOT: velocity profiles over time
        
        PlotRxDropMaps( o )             % PLOT: Nodal RX drop location map(s)
        PlotRxNavMaps( o )              % PLOT: Nodal RX navigation map(s)
        PlotRxNavDriftMap( o )          % PLOT: Plot drift of RX from drop to navigated location
        
        PlotSDM( o )                    % PLOT: SDM - source dipole moment
        PlotTowTimeChart( o )           % PLOT: Tow time & tx time lag chart
        
        PlotBenthos( o )                % PLOT: Benthos RX ping info
        PlotCudaGPS( o )                % PLOT: Barracuda GPS generic plotting UI
        PlotCudaGPS_QC( o )             % PLOT: Barracuda GPS QC plot looking for abberations
        PlotCudaCfg( o )                % PLOT: helper info relating Benthos pings & Barracuda GPS locations
        
        PlotTxNav( o )                  % PLOT: Tx Nav
        
        PlotBinaries( o )               % PLOT: Rx binaries (spectrograms!)
        
        PlotTowedCSEM( o, sFile )       % PLOT a single Towed CSEM file
        
    end % public methods 
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% PUBLIC METHODS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods( Access = public )
        %-----------------------------------------------------------------------
        % cwave() object constructor
        %
        % NB: MatLab's order of work:
        %   1. Call cwave constructor to get default values
        %   2. IF loading from a .mat file...
        %       2a. Stuff all the data into the object
        %       2b. Call loadobj()
        %
        % After all this, MakeUI() needs to be called. This way the UI and its
        % bevy of listeners don't exist while the properties of the object are
        % being set.
        %
        function o = cwave()
            
            % Minimum MATLAB version: 2020b
            if verLessThan( 'matlab', '9.9' )
                disp( 'Sorry. MatLab version R2020b or newer is required.' );
                return; % with no UI elements created, the obj will self-delete
            end
            
            %----- Setup MatLab -----%
            % This warning comes from using matfile() and trying to load part of
            % a variable (e.g. a sample number of rows from an array). The code
            % works just fine but MatLab spews a warning about needing to be
            % saved in -v7.3 for partial loading to be actually partial instead
            % of loading the entire variable, then just taking the partial. It's
            % basically a programmer's warning. The user doesn't need to see it.
            warning( 'off', 'MATLAB:MatFile:OlderFormat' );
            
            % Don't let MatLab complain about ambiguous date conversions when
            % it's unsure whether a date is mm/dd or dd/mm (i.e. dd < 13)
            warning( 'off', 'MATLAB:datetime:AmbiguousDateString' );
            
            return;
        end % constructor
        
        %-----------------------------------------------------------------------
        function MakeUI( o, nPos )
            arguments
                o       cwave
                nPos    double = []
            end
            
            %----- Create the main GUI figure and its menu -----%
            % Make this waitbar early so the user knows something is happening
            tm = tic();
            fprintf( 'Creating WAVE UI... ' );  % no \n on purpose
            hWait = figCenter( 0, waitbar( 0, 'MatLab is creating the UI...' ) );
            function emb_Done(tm,hWait)
                delete(hWait);
                toc(tm);
            end
            oMakeDone = onCleanup( @()emb_Done(tm,hWait) );
            drawnow();
            
            % If no position info passed in, create the main UI window, centered
            % on the main monitor with a size just slightly less than a 1080p
            % monitor
            if isempty( nPos )
                nPos = getMonitorPosition();
                if size(nPos,1) > 1                     % multiple monitors
                    nPos = sortrows(nPos,[-3 1]);       % sort by width then left
                    % Take the monitor at position 1,1
                    iAt = find( nPos(:,1) == 1 & nPos(:,2) == 1, 1, 'first' );
                    if isempty(iAt)
                        iAt = 1;        % if none at 1,1 then take widest
                    end
                    nPos = nPos(iAt,:);
                end
                
                % Size it, centered on the monitor
                nWd  = min( 1820, nPos(3)-100 );
                nHt  = min(  980, nPos(4)-100 );
                nPos = [nPos(3)/2+nPos(1)-nWd/2 nPos(4)/2+nPos(2)-nHt/2 nWd nHt];
            end
            
            % Create the main UI figure
            o.hFig = uifigure( 'Position', nPos ...
                , 'Name', ['WAVE - ' o.sFileName], 'Tag', 'figWAVE' ...
                , 'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'on' ...
                , 'Visible', false ...
                );
            o.hFig.CloseRequestFcn = @o.FileClose;
            
            %----- Set up the Menu -----%
            o.hMenuFile = uimenu( o.hFig, 'Label', 'File', 'Tag', 'menuFile' );
            %---
            uimenu( o.hMenuFile, 'Label', 'New WAVE workbench',  'MenuSelectedFcn', @o.FileNew );
            uimenu( o.hMenuFile, 'Label', 'Load ...', 'MenuSelectedFcn', @o.FileLoad );
            uimenu( o.hMenuFile, 'Label', 'Save', 'MenuSelectedFcn', @o.SaveData );
            uimenu( o.hMenuFile, 'Label', 'Save as...', 'MenuSelectedFcn', @(~,~)o.SaveAs );
            %---
            uimenu( o.hMenuFile, 'Label', 'Exit', 'MenuSelectedFcn', @o.FileClose, 'Separator', 'on' );
            if ~isempty( o.sSaveFile )  % if a path+file were given, put them on the top of the MRU list
                o.UpdateMRU( o.sSaveFile );
            else
                o.ShowMRU();
            end
            
            %----- Create the workbench tabs -----%
            o.otabgrp = uitabgroup( 'Parent', o.hFig, 'TabLocation', 'top' ...
                , 'Units', 'normalized', 'Position', [0 0 1 1] ...
                , 'SelectionChangedFcn', @o.LockDownTabs );
            
            o.otabConfig    = w_tabConfig( o, o.otabgrp );      % configuration settings
            o.otabShipData  = w_tabShipData( o, o.otabgrp );    % Ship-data logs
            o.otabSUESI     = w_tabSUESI( o, o.otabgrp );       % SUESI Logs
            o.otabWaveform  = w_tabWaveform( o, o.otabgrp );    % Waveform handling
            o.otabRxNav     = w_tabRxBenthosNav( o, o.otabgrp );% RX Benthos Nav
            %%//%% uitab( 'Parent', o.otabgrp, 'Title', '  USBL Nav  ' );
            o.otabiLBL      = w_tabTxNavILBL( o, o.otabgrp );   % iLBL Tx Nav
            o.otabCSEM      = w_tabNodalCSEM( o, o.otabgrp );   % Nodal CSEM
            o.otabTowed     = w_tabTowedCSEM( o, o.otabgrp );   % Towed CSEM
            
            %----- Finalize -----%
            % Trigger a load event so that all panel states are set correctly.
            o.LoadUI();
            
            % Show the figure
            % NB: 85% of "create" time occurs during the drawnow below. 
            drawnow();  % force all rendering while invisible (it's faster)
            o.hFig.Visible = true;
            
            % Set flags
            o.bChgd = false;
            o.bLoading = false;
            
            %----- Listeners for when the UI changes certain vars -----%
            addlistener( o, 'SuesiTab_VarChg',     @(~,~)o.Invalidate_SuesiOutput() );
            addlistener( o, 'RxNavTab_VarChg',     @(~,~)o.Invalidate_RxNav() );
            addlistener( o, 'TxNavLBLTab_VarChg',  @(~,~)o.Invalidate_TxNav() );
            addlistener( o, 'CSEMUI_VarChg',       @(~,~)o.Invalidate_CSEMOutput() );
            
            return;
        end % MakeUI
        
        %-----------------------------------------------------------------------
        % Causes all UI elements to update from the data store
        %
        % NB: This could be embedded in MakeUI but I leave it exposed as a
        % public method so that if there's trouble a user can cause the UI to
        % update manually from the command line (e.g. ">> o.LoadUI();")
        function LoadUI( o )
            % Update the figure's Name
            if isempty( o.sFileName )
                o.hFig.Name = 'WAVE';
            else
                o.hFig.Name = ['WAVE - ' o.sFileName ];
            end
            
            % Get each workbench tab to update itself
            o.otabConfig.LoadUI();
            o.otabShipData.LoadUI();
            o.otabSUESI.LoadUI();
            o.otabWaveform.LoadUI();
            o.otabRxNav.LoadUI();
            o.otabiLBL.LoadUI();
            o.otabCSEM.LoadUI();
            o.otabTowed.LoadUI();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % Menu: File / Close
        function FileClose( o, ~, ~ )
            % If the current workbench has changed, ask about saving
            if ~o.QuerySave()
                return;
            end
            
            % Delete the main figure. This should cascade-delete all the child
            % UI objects. Once that happens, the main object itself will
            % self-delete so long as the user hasn't saved a variable somewhere.
            delete( o.hFig ); 
                % NB: use delete() instead of close() to force the issue in case
                % a bug has crippled the UI.
            return;
        end % FileClose
        
        %-----------------------------------------------------------------------
        % Add a new log entry & set the "changed" flag true
        function AddLog( o, nStatus, sType, sDesc )
            o.cLog{end+1,o.colLog.Status}   = nStatus; % cwave.LogOK .LogWarn .LogError
            o.cLog{end,o.colLog.Type}       = sType;
            o.cLog{end,o.colLog.Date}       = datetime( 'now' );
            o.cLog{end,o.colLog.User}       = dm_User();
            o.cLog{end,o.colLog.Desc}       = char(sDesc); % strings require more memory than char arrays
            o.bChgd = true;
            
            % If an error has occurred, dump it to the command window for the
            % user's convenience.
            if nStatus == cwave.LogError
                disp( [sType ' :: ' char(sDesc)] );
            end
            return; 
        end % AddLog
        
        %-----------------------------------------------------------------------
        % Retrieve all log entrys of a specific type
        function cLog = GetLogOfType( o, sType )
            cLog = o.cLog(strncmpi( sType, o.cLog(:,o.colLog.Type), numel(sType) ),:);
            return;
        end % GetLogOfType
        
        %-----------------------------------------------------------------------
        % Clear all log entrys of a specific type
        function ClearLogOfType( o, sType )
            o.cLog(strncmpi( sType, o.cLog(:,o.colLog.Type), numel(sType) ),:) = [];
            o.bChgd = true;
            return;
        end % ClearLogOfType
        
        %-----------------------------------------------------------------------
        % Switch the current tab to the one whose text is given
        function GoToTab( o, sTab, sBlinkPanel )
            oTab = [];
            for iTab = 1:numel(o.otabgrp.Children)
                if strcmpi( sTab, strtrim( o.otabgrp.Children(iTab).Title ) )
                    oTab = o.otabgrp.Children(iTab);
                    break;
                end
            end
            if ~isempty( oTab )
                o.otabgrp.SelectedTab = oTab;
                oTab.UserData.SelectTab();  % oTab.UserData = the w_tab... owner object
                
                % If a "blink this panel" text was given, find that panel and
                % flash it's background color a few times
                if exist( 'sBlinkPanel', 'var' ) && ~isempty( sBlinkPanel )
                    oPnlList = findobj( oTab, 'Type', 'uipanel' );
                    if ~isempty( oPnlList )
                        iPnl = find( contains( {oPnlList.Title}, sBlinkPanel, 'IgnoreCase', true ), 1, 'first' );
                        if ~isempty( iPnl )
                            drawnow(); % let tab resolve first
                            nPause  = 0.5;
                            oPnl    = oPnlList(iPnl);
                            nPos    = oPnl.Position;
                            hAnnot  = annotation( oTab, 'rectangle' ...
                                , 'LineWidth', w_tab.nConnWd*5 ...
                                , 'Units', 'pixels', 'Position', nPos ...
                                );
                            for iBlinks = 1:3
                                hAnnot.Color = [0 0 0]; pause(nPause);
                                hAnnot.Color = [1 1 1]; pause(nPause);
                            end
                            delete( hAnnot );
                        end
                    end
                end
            end
            
            return;
        end % GoToTab
        
        %-----------------------------------------------------------------------
        % Ensure all tabs have been created
        function MakeAllTabs( o )
            for oTab = onerow( o.otabgrp.Children )
                try %#ok<TRYNC>
                    oTab.UserData.SelectTab();  % oTab.UserData = the w_tab... owner object
                end
            end
            return;
        end % MakeAllTabs
        
    end % public methods
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% PROTECTED METHODS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        % Utility function to query if the current workbench should be saved
        % before something destructive happens. Return T if it's OK to proceed.
        % F if user cancels.
        function bDone = QuerySave( o )
            % If the current workbench has changed, ask about saving
            if ~o.bChgd
                bDone = true;
                return;
            end
            switch( uiconfirm( o.hFig, 'Save changes to the current workbench?' ...
                    , 'WAVE:Save Changes', 'Options', {'Yes', 'No', 'Cancel'} ...
                    , 'DefaultOption', 1, 'CancelOption', 3 ) )
            case 'Yes'
                o.SaveData();
                bDone = ~o.bChgd;   % NB: T = user cancel, so don't continue
            case 'No'               % Don't save. Discard changes
                bDone = true;
            otherwise               % everything else is cancel
                bDone = false;
            end
            return;
        end % QuerySave
        
        %-----------------------------------------------------------------------
        % Menu: File / Save As
        function bOK = SaveAs( o )
            bOK = false;
            
            % sSaveFile is virtual, composed of sDir_Main & sFileName. If either
            % of those components is empty, fill it with some default. But do
            % them separately.
            if isempty( o.sDir_Main )
                o.sDir_Main = pwd();
            end
            if isempty( o.sFileName )
                o.sFileName = 'SurveyName';
            end
            
            % Always ask where to save the workbench so the user doesn't
            % accidentally overwrite with "save" when what they might actually
            % want is "save as"
            [sF,sP] = uiputfile( {
                '*.wave.mat', 'WAVE workbench file'
                '*', 'All Files'
                }, 'Specify a WAVE workbench file' ...
                , o.sSaveFile );
            if ~ischar(sF)  % user cancel
                return;
            end
            
            % Force the file extension to be '.wave.mat' by stripping the
            % extension off and stashing the path & file separately. The method
            % get.sSaveFile() will assemble appropriately.
            o.sDir_Main = sP;
            o.sFileName = strtok( sF, '.' );
            
            % Signal success
            bOK = true;
            
            return;
        end % SaveAs
        
        %-----------------------------------------------------------------------
        % Menu: File / Save
        function SaveData( o, ~, ~ )
            % If this is the very first save, then get a path & name
            if (isempty( o.sDir_Main ) || isempty( o.sFileName )) ...
            && ~o.SaveAs()  % false = user cancel
                return;
            end
            
            oProg = uiprogressdlg( o.hFig, 'Title', 'Save', 'Message', 'Saving ...', 'Indeterminate', 'on' );
            
            % Save the structure to the file
            save( o.sSaveFile, 'o', '-v7.3' );
            
            % Reset the changed flag (it's transient so doesn't get saved in the
            % file. Only update it for this instance of the UI)
            o.bChgd = false;
            
            % The user may have updated / changed the name of the .wave.mat file
            % Update the main figure's name accordingly.
            o.hFig.Name = ['WAVE - ' o.sFileName];
            
            % Move this file to the top of the MRU list
            o.UpdateMRU( o.sSaveFile );
            
            close(oProg);
            
            return;
        end % SaveData
        
        %-----------------------------------------------------------------------
        % Menu: File / New WAVE workbench...
        function FileNew( o, ~, ~ )
            % If the current workbench has changes, ask about saving
            if ~o.QuerySave()
                return;
            end
            
            % Position at the same location but slightly offset
            nPos = o.hFig.Position + [20 -20 0 0];
            
            % create a new cwave object
            oNew = cwave();
            oNew.MakeUI( nPos );
            
            return;
        end % FileNew
        
        %-----------------------------------------------------------------------
        % Menu: File / Load WAVE workbench...
        % NB: varargin{1} = (opt) path+file (from MRU) to open
        function FileLoad( o, ~, ~, varargin )
            % If the current workbench has changes, ask about saving
            if ~o.QuerySave()
                return;
            end
            
            % If we've been asked to load something from the MRU list, check to
            % see if it exists first. If not, then offer to remove it from the
            % MRU list but don't go any further. Do NOT clear the workbench.
            if numel(varargin) >= 1
                sFileOpen = varargin{1};
                if ~isfile( sFileOpen )
                    sBtn = uiconfirm( o.hFig, {
                        sprintf( 'File %s does not exist.', sFileOpen )
                        'Remove it from the "File" menu?'
                        }, 'Failed MRU Load', 'Options', {'Yes', 'No', 'Cancel'} ...
                        , 'DefaultOption', 1, 'CancelOption', 3 );
                    if strcmpi( sBtn, 'yes' )
                        % Delete from the list
                        [cMRU,sMRUFile] = o.GetMRUList();
                        iAt = find( strcmpi( cMRU, sFileOpen ), 1, 'first' );
                        if ~isempty( iAt )
                            cMRU(iAt) = [];
                        end
                        
                        % Save the updated list
                        save( sMRUFile, 'cMRU' );
                        
                        % Update the menu
                        o.ShowMRU( cMRU );
                        
                    end
                    
                    % Nothing to load, so just return
                    return;
                end
            else
                % Get the file to load
                if isempty( o.sSaveFile )
                    sFileOpen = fullfile( pwd(), '*.wave.mat' );
                else
                    sFileOpen = o.sSaveFile;
                end
                [sF,sP] = uigetfile( {
                    '*.wave.mat', 'WAVE workbench file'; '*','All Files'
                    }, 'Pick a WAVE workbench file', sFileOpen );
                if ~ischar(sF)
                    return
                end
                sFileOpen = fullfile( sP, sF );
            end
            
            % Update the MRU list
            o.UpdateMRU( sFileOpen );
            
            % Load an entirely new instance of cwave
            oProg = uiprogressdlg( o.hFig, 'Title', 'Loading' ...
                , 'Message', 'MatLab is loading the WAVE object...' ...
                , 'Indeterminate', 'on' );
            stNew = load( sFileOpen ); % the .mat contains a cwave object which will re-create the UI
            close( oProg );
            
            % If it was successful ...
            if ishandle( stNew.o.hFig )
                % Set the path+filename that were actually loaded - if the user
                % moved everything, the root path & filename MUST be updated.
                % Then update the config tab so it can re-validate all the
                % sub-folder entries
                stNew.o.sSaveFile = sFileOpen;
                stNew.o.otabConfig.LoadUI();    % update path+file in UI in case it has changed
                
                % Reset flags
                stNew.o.bChgd = false;
                
                % get rid of this instance (which is what the user expects from
                % a File / Load action).
                stNew.o.hFig.Position = o.hFig.Position;   % put it here
                delete( o.hFig );
            end
            
            return;
        end % FileLoad
        
        %-----------------------------------------------------------------------
        % Add the file to the top of the MRU list, save the list, and updt the menu
        function UpdateMRU( o, sFile )
            % Get the existing list, if any
            [cMRU, sMRUFile] = o.GetMRUList();
            
            % If the current item is already in the list (being loaded again) remove it.
            iAt = find( strcmpi( cMRU, sFile ), 1, 'first' );
            if ~isempty( iAt )
                cMRU(iAt) = [];
            end
            
            % Add to the top of the MRU list
            cMRU(2:end+1)   = cMRU;
            cMRU{1}         = sFile;
            if numel(cMRU) > 9
                cMRU(10:end) = [];
            end
            
            % Save the list
            save( sMRUFile, 'cMRU' );
            
            % Update the menu
            o.ShowMRU( cMRU );
            
            return;
        end % UpdateMRU
        
        %-----------------------------------------------------------------------
        % Update the most-recently-used (MRU) menu
        function ShowMRU( o, cMRU )
            % If the list wasn't passed, read it from disk
            if ~exist('cMRU','var') || isempty(cMRU)
                cMRU = o.GetMRUList();
            end
            
            % Delete current MRU menu items
            if ~isempty( o.hMRU )
                delete( o.hMRU );
                o.hMRU = [];
            end
            
            % The "Exit" item should always go last. Make start pos just above it
            nStart = numel( o.hMenuFile.Children ) - 1;
            
            % Add these items just above the "exit" menu
            for i = 1:numel(cMRU)
                o.hMRU(i) = uimenu( o.hMenuFile, 'Label', sprintf('&%d %s', i, cMRU{i} ) ...
                    , 'Tag', 'MRU', 'Position', nStart + i ...
                    , 'Separator', iif( i==1, 'on', 'off' ) ... % put a line above the first one
                    , 'MenuSelectedFcn', {@o.FileLoad, cMRU{i}} );
            end
            return;
        end % ShowMRU
        
        %-----------------------------------------------------------------------
        % uitabgroup::SelectionChangedFcn handler. 
        % If the config is not completely OK, deny access to all other tabs.
        function LockDownTabs( o, ~, oChgObj )
            if ~o.otabConfig.IsConfigComplete()
                o.otabgrp.SelectedTab = o.otabConfig.hTab;
                uialert( o.hFig, {
                    'The project configuration is not complete or '
                    'fully valid. Please check everything on the'
                    'Configuration tab before trying to select'
                    'other tabs in the workbench.'
                    }, 'WAVE' );
            else
                hTab = oChgObj.NewValue;
                if ~isempty( hTab.UserData )
                    hTab.UserData.SelectTab();  % hTab.UserData = the w_tab... owner object
                end
            end
            return;
        end % LockDownTabs
        
    end % protected methods
    
end % cwave class definition
