function stData = readBinData( sFile, opts )
% stData = readBinData( sFile, options )
%
% Read an EM binary data file. This code will eventually encapsulate many
% different data types like the old plethora of get...() functions. At the time
% of initial writing, I'm ignoring historical formats (OHM, Qmax, netcdf) as
% well as EMGS formats (they have their own processing platform). 
%
% Params:
%   sFile   - path+file to read
%      --OR-- 
%   stData  - structure returned from an earlier call
%
%   OPTIONAL 'Name', 'value' pairs. Valid options are given below. With no
%       optional values, only the file header is returned and stData.nData will
%       be empty. If you want data then include EITHER DateFrom & DateTo or
%       SkipPts and ReadPts.
%
%       ReadAll - (dflt False) True/False. If T, read & return the entire file.
%               In this case, SkipPts,ReadPts,DateFrom,DateTo values you pass in
%               are ignored and all data are returned.
%
%       SkipPts - # of data points PER CHANNEL to skip before reading
%       ReadPts - # of data points PER CHANNEL to read
%
%       DateFrom - starting date of data to read 
%       DateTo   - ending date
%
%       KeepOpen - (dflt False) True/False to keep file open. You should only
%               hold the file open if you are going to be doing a lot of little
%               reads from it. This isn't recommended. Most files are small
%               enough to be read entirely into memory in one go, which is
%               pretty fast these days.
% Example:
%   AS TWO SEPARATE STEPS - FIRST THE HEADER THEN SOME DATA
%       st = readBinData( 'somefolder\GTF1_V1_72Barramundi.bin' );
%       st = readBinData( st, 'DateFrom', datetime(2022,02,03,16,0,0) ...
%                           , 'DateTo', datetime(2022,02,03,18,0,0) );
%   or ALL THE DATA
%       st = readBinData( 'somefolder\GTF1_V1_72Barramundi.bin', 'ReadAll', true );
%
% Returns:
%   stData  - structure with header info and, if requested, a block of data
%       Example from an SIO file:
%           sType: 'SIO'
%      n1HzPhCorr: 0                    % see note in code about using this
%          nBytes: 469504000            % file size in bytes
%       nCntPerCh: 38055500             % count of data points PER CHANNEL
%          dStart: 24-May-2009 20:59:59 % datetime, NOT the old datenum
%            dEnd: 30-May-2009 12:09:52
%           nFreq: 62.5
%        nChanCnt: 5
%        nCntConv: 3.97364361661968e-07 % SIO units B: nT/cnt; E: V/cnt
%           nData: (# data,# chan)
%            sVer: '1.18U'
%           sDesc: 'MKIIIE 32 SHARK'
%           nBits: 24
%     nSampPerBlk: 166
%             Dir: [32×3 table] (Vars: dStart, nBlkSt, nBlkCnt)      [SIO only]
%             fid: 0
%
%-------------------------------------------------------------------------------
% Ground-up rewrite 2023 by David Myer. Based on the old getsio.m which was
% worked on by Steve Constable, Kerry Key, myself, and hosts of others.
%
% This program is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, version 3. This program is distributed in the hope that it will be
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. To view the GNU General
% Public License see <https://www.gnu.org/licenses/>
%-------------------------------------------------------------------------------
    arguments
        sFile
        opts.ReadAll    (1,1) logical = false
        opts.KeepOpen   (1,1) logical = false
        opts.SkipPts    (1,1) double = NaN
        opts.ReadPts    (1,1) double = NaN
        opts.DateFrom   (1,1) datetime = NaT
        opts.DateTo     (1,1) datetime = NaT
    end
    
    % If a header was NOT passed in, get it from the file
    if isstruct(sFile)
        stData = sFile;
    else
        stData = sub_GetHeader( sFile, opts.KeepOpen );
    end
    
    % If the caller wants the entire file read, set that up
    if opts.ReadAll
        opts.DateFrom   = NaT;
        opts.DateTo     = NaT;
        opts.SkipPts    = 0;
        opts.ReadPts    = stData.nCntPerCh;
    end
    
    % Did the caller request data?
    if ~isnat( opts.DateFrom ) && ~isnat( opts.DateTo )
        % Convert date from/to into SkipPts & ReadPts
        %
        % NB: any fractional sub-sample bit of time will be placed into
        % stData.n1HzPhCorr and should be used by the caller to implement a
        % phase shift in the frequency domain. To do so, multiply n1HzPhCorr
        % by the vector of output frequencies. Then create a complex factor
        % complex(cosd(...),-sind(...)) and multiply the complex frequency
        % domain values by this.
        %
        nSampSkip           = seconds( opts.DateFrom - stData.dStart ) * stData.nFreq;
        opts.SkipPts        = round( nSampSkip );
        opts.ReadPts        = ceil( seconds( opts.DateTo - opts.DateFrom ) * stData.nFreq );
        stData.n1HzPhCorr   = (opts.SkipPts - nSampSkip) / stData.nFreq * 360;
        
    end
    
    if ~isnan( opts.SkipPts ) && ~isnan( opts.ReadPts )
        % Skip & read points MUST be integers. Don't pass 31.25 for example.
        % Fractional data points don't exist.
        opts.SkipPts = floor( opts.SkipPts );
        opts.ReadPts = floor( opts.ReadPts );
        
        % Retrieve the appropriate data
        stData.nData = sub_GetData( stData, opts.KeepOpen, opts.SkipPts, opts.ReadPts );
    end
    
    return;
end % readBinData

%-------------------------------------------------------------------------------
% Which type of file is this?
function sType = sub_GetType( sFile )
    % Type is decided based on the file extension for most files. SIO file
    % extensions are sometimes '.bin' and sometimes empty (sigh; old Mac users)
    [~,~,sExt] = fileparts( sFile );
    switch( lower( sExt ) )
    case {'.h5src', '.h5', '.rx2', 'ant'}
        throw( MException('readBinData:GetType', 'EMGS data file types are not supported.' ) );
    case {'.em'}
        throw( MException('readBinData:GetType', 'QMax data file type is not supported.' ) );
    case {'.nc','.cdf'}
        throw( MException('readBinData:GetType', 'OHM data file types are not supported.' ) );
    case {'.bin',''}
        sType = 'SIO';
%%//%% add other file types here
    otherwise
        throw( MException('readBinData:GetType', ['Unknown binary data file extension ' sExt] ) );
    end
    return;
end % sub_GetType()

%-------------------------------------------------------------------------------
function stData = sub_GetHeader( sFile, bKeepOpen )
    % Do we know this type and can we open it?
    stData.sFile        = sFile;
    stData.sType        = sub_GetType( sFile );
    stData.n1HzPhCorr   = 0;
    [stData.fid,sMsg]   = fopen( stData.sFile, 'r', 'b' );
    if stData.fid < 1
        throw( MException('readBinData:GetHeader',['Error opening file: ' sMsg]) );
    end
    
    % How many bytes in the file (final arbiter of time range)
    fseek( stData.fid, 0, 'eof' );
    stData.nBytes = ftell( stData.fid );
    fseek( stData.fid, 0, 'bof' );
    
    switch( stData.sType )
    case 'SIO'
        sub_SIOHeader();
%%//%% add other file types here
    otherwise
        throw( MException('readBinData:GetHeader',['File type not coded: ' stData.sType]) );
    end
    
    % If the caller doesn't want the file left open, close it now
    if ~bKeepOpen
        fclose( stData.fid );
        stData.fid = 0;
    end
    
    return;
    
    %---------------------------------------------------------------------------
    % Read the header of an SIO file. Condensed & recoded from getsio()
    function sub_SIOHeader
        % NB: In the SIO file, data blocks are 512 bytes long
        
        % NB: fread(...,'*char') is EXCEPTIONALLY SLOW (i.e. 3 seconds to read
        % 80 characters!) Read as uint8 then convert to char. This is very fast.
        %#ok<*FREAD>
        
        fseek( stData.fid, 1024, 'bof' );   % skip first 2 blocks
        fseek( stData.fid, 12, 'cof' );     % skip next 12 bytes (unused?)
        
        n32             = fread( stData.fid, 13, 'int32' );
        nDirStart       = n32(1);           % start of the "time directory"
        nDirCnt         = n32(4);           % number of entries
        fseek( stData.fid, 2, 'cof' );      % skip 2 bytes
        stData.sVer     = char(fread( stData.fid, 5, 'uint8' )).';
        fseek( stData.fid, 5, 'cof' );      % skip 5 bytes
        stData.sDesc    = char(fread( stData.fid, 80, 'uint8' )).';
        n16             = fread( stData.fid, 10, 'int16' );
        stData.nFreq    = n16(1);
        stData.nChanCnt = n16(3);
        stData.nBits    = iif( n16(7) == 0, 16, 24 );
        
        % Strip everything following the first NULL in the description string
        % then trim any spaces
        i1stNull = find( stData.sDesc==0, 1, 'first' );
        if ~isempty( i1stNull )
            stData.sDesc(i1stNull:end) = [];
        end
        stData.sDesc = strtrim( stData.sDesc );
        
        % Sampling frequency is fractional below 125 Hz
        switch( stData.nFreq )
        case {31, 32}
            stData.nFreq = 31.25;
        case {62, 63}
            stData.nFreq = 62.5;
        otherwise
            stData.nFreq = double( stData.nFreq );
        end
        
        % Skip to the start of the time directory & read it in
        fseek( stData.fid, 512 * nDirStart, 'bof' );
        for i=1:nDirCnt
            ms(i,1)       = fread( stData.fid, 1, 'uint16' );
            ss(i,1)       = fread( stData.fid, 1, 'uint8' );
            ss(i,1)       = ss(i,1) + double(ms(i,1)) ./ 1000;
            mm(i,1)       = fread( stData.fid, 1, 'uint8' );
            hh(i,1)       = fread( stData.fid, 1, 'uint8' );
            dd(i,1)       = fread( stData.fid, 1, 'uint8' );
            mo(i,1)       = fread( stData.fid, 1, 'uint8' );
            yr(i,1)       = fread( stData.fid, 1, 'uint8' );
            nBlkSt(i,1)   = fread( stData.fid, 1, 'uint32' );
            fseek( stData.fid, 6, 'cof' );      % skip unused bytes
            nBlkCnt(i,1)  = fread( stData.fid, 1, 'uint16' );
            fseek( stData.fid, 12, 'cof' );     % skip unused bytes
        end
        
        % Note from getsio.m by SCC. I've integrated his fix in this new code.
        % For a more thorough write-up of this, see the comment block at the
        % bottom of this file. This is from a series of emails.
        %----
        % Changes below added by SCC January 2016 to correct start time. The
        % times in the directory are wrong by up to 9 millisec - the instrument
        % DOES start up on the precise wake-up time.  The csemFFT code believes
        % the directory times, so we need to re-set the directory time. I have
        % assumed that the wake-up time has been set on a whole minute.
        %
        % However, there is a residual 0.53 of a sample timing error in the
        % correction for the ADC anti-aliasing filters. (Except for 62.5 Hz -
        % that's way complicated: that frequency has a 62.5 anti-aliasing filter
        % but is actually sampled at 125 Hz and then decimated.  If the 125 Hz
        % samples that land on the half sample are selected, there is a
        % negligible timing error. Fortunately, the millisecond timer allows us
        % to work out if this happens. Don't ask me why.)
        %----
        nDiffSS1 = ss(1);   % for propagating SCC's time corrections to all dir entries
        nDiffMM1 = mm(1);
        
        % If the reported start time is early, increase the minute by one
        if ss(1) > 59.0
            mm(1) = mm(1) + 1;
        end
        
        % Add the 0.53 of a sample interval, except for the 62.5 special case.
        % NB: some vulcans are version 'V1.02' for some reason instead of '1.20'
        if stData.sVer(1) == '8' || stData.sVer(1) == '9'   % Mk II
            ss(1) = 0.0;
            if (stData.nFreq == 62.5) && (ms(1) == 0)
                ss(1) = 60 - 0.008;
                mm(1) = mm(1) - 1;
            end
        elseif stData.sVer(1) == '1' || strncmpi( stData.sVer, 'V1', 2 ) % Mk III & Mk IV
            if (stData.nFreq == 62.5) && (ms(1) < 500)
                ss(1) = 60 - 0.03 / stData.nFreq;
                mm(1) = mm(1) - 1;
            else
                ss(1) = 60 - 0.53 / stData.nFreq;
                mm(1) = mm(1) - 1;
            end
        else                                                % UNKNOWN version
            error( 'Uncoded logger version: %s', stData.sVer );
        end
        
        % Propagate the change in the first directory time to all the rest.
        nDiffSS1  = ss(1) - nDiffSS1;
        nDiffMM1  = mm(1) - nDiffMM1;
        ss(2:end) = ss(2:end) + nDiffSS1;
        mm(2:end) = mm(2:end) + nDiffMM1;
        ssOnly    = floor(ss);              % separate out seconds
        ms        = (ss - ssOnly) * 1000;   % and milliseconds
        %---------- end SCC changes from old getsio.m ----------%
        clear ss
        
        % Change the year from a 2 digit year to a four digit year, correct for
        % 1972 fake times also
        if yr(1)==72        % fix for some jam2000 file with 72 for year
            yr = ones(size(yr))*2000;
        elseif yr(1) == 73  % fix for 2001 Gemini data with '73' for year
            yr(:) = 2001;
        elseif yr(1) > 92   % else is 16 bit logger used during 1992ish to about 2000 or so
            yr = yr+1900;
        elseif yr(1) < 92   % else is 24 bit logger used post 2000 or so
            yr = yr+2000;
        end
        
        % Convert to dates
        dStart = datetime( yr, mo, dd, hh, mm, ssOnly, ms ); % array of starts per dir entry
        clear yr mo dd hh mm ssOnly ms
        
        % The time directory can be wrong compared to the actual file size. If
        % the file is truncated, adjust the final time directory. If the file is
        % too long, ignore that. It happens sometimes when the file is
        % transferred from the on-ship work computer.
        nBlkTot = stData.nBytes / 512;
        nBlkDir = nBlkSt(end) + nBlkCnt(end);   % block #s are 0-based in SIO
        if nBlkTot < nBlkDir
            % Drop any full rows that are beyond the file end
            bDrop = nBlkSt > nBlkTot;
            dStart(bDrop) = [];
            nBlkSt(bDrop) = [];
            nBlkCnt(bDrop) = [];
            nBlkCnt(end) = nBlkTot - nBlkSt(end);
            
            % There should be an integer # of blocks per channel
            nBlkCnt(end) = floor( nBlkCnt(end) / stData.nChanCnt ) * stData.nChanCnt;
        end
        
        stData.nSampPerBlk  = iif( stData.nBits == 24, 166, 249 );
        stData.Dir          = table( dStart, nBlkSt, nBlkCnt );
        stData.n1stDataBlk  = nBlkSt(1);
        stData.nCntPerCh    = floor( sum(nBlkCnt) * stData.nSampPerBlk / stData.nChanCnt );
        stData.dStart       = dStart(1);
        nLastSampCnt        = nBlkCnt(end) * stData.nSampPerBlk / stData.nChanCnt;
        stData.dEnd         = dStart(end) + seconds( nLastSampCnt / stData.nFreq );
        if stData.sVer(1) == '8' || stData.sVer(1) == '9'   % Mk II
            stData.nCntConv     = 9 / (5242879+5242880);
        else                                                % Mk III & IV
            stData.nCntConv     = 2.5 / 6291455;
        end
        
        return;
    end % sub_SIOHeader
end % sub_GetHeader

%-------------------------------------------------------------------------------
% Retrieve the the requested # of samples per channel starting AFTER a given pt
function nData = sub_GetData( stData, bKeepOpen, nSkipPts, nReadPts )
    % If the file isn't open, open it
    if stData.fid == 0
        [stData.fid,sMsg]   = fopen( stData.sFile, 'r', 'b' );
        if stData.fid < 1
            throw( MException('readBinData:GetHeader',['Error opening file: ' sMsg]) );
        end
    end
    
    % Read the data. This is filetype dependent
    nData = [];
    switch( stData.sType )
    case 'SIO'
        sub_SIO();
%%//%% add other file types here
    otherwise
        throw( MException('readBinData:GetData',['File type not coded: ' stData.sType]) );
    end
    
    % If the caller doesn't want the file left open, close it now
    if ~bKeepOpen
        fclose( stData.fid );
        stData.fid = 0;
    end
    
    return;
    
    %---------------------------------------------------------------------------
    function sub_SIO()
        % SIO data files are written in data blocks of 512 bytes. Each block
        % starts with a 14 byte (112 bits) header which is always ignored. Then
        % there are either 249 of 166 data depending on 16 or 24 bit logger
        
        % Break up the "# pts to skip" into number of blocks to skip and number
        % of points in the next block. This is all PER CHANNEL right now.
        nBlkSkip = floor( nSkipPts / stData.nSampPerBlk );
        nPtSkip  = nSkipPts - (nBlkSkip * stData.nSampPerBlk);
        
        % Start reading at which block?
        nStartBlk = stData.n1stDataBlk + (nBlkSkip * stData.nChanCnt);
        
        % Read how many blocks (per channel)?
        nBlkPerCh = ceil( (nReadPts + nPtSkip) / stData.nSampPerBlk );
        nReadBlks = nBlkPerCh * stData.nChanCnt;
        
        % Read those data blocks
        % NB: block numbers are 0-based in these files
        fseek( stData.fid, nStartBlk * 512, 'bof' );
        fseek( stData.fid, 14, 'cof' ); % skip the block header
        if stData.nBits == 24
            % fread() instruction: read 166 24bit numbers, then skip 112 bits
            % (which is the 14 byte header of the next block)
            [nIn,nCntRead] = fread( stData.fid, [166 nReadBlks] ...
                , '166*bit24', 112 );
        else
            [nIn,nCntRead] = fread( stData.fid, [249 nReadBlks] ...
                , '249*bit16', 112 );
        end
        % NB: The check below only fails when files are on external drives on
        % Macs and the mac OS causes the file to close behind the scenes. MatLab
        % tries to recover by pretending it read all the data but not giving the
        % full count.
        assert( nCntRead == stData.nSampPerBlk * nReadBlks, 'readBinData:sio failed to read appropriate data' );
        
        % Reformat the data into (# data,#chan)
        nData = zeros(numel(nIn)/stData.nChanCnt, stData.nChanCnt);
        for iCh = 1:stData.nChanCnt
            nData(:,iCh) = reshape( nIn(:,iCh:stData.nChanCnt:end), [], 1 );
        end
        
        % Drop the skip points at the front of the first block
        if nPtSkip > 0
            nData(1:nPtSkip,:) = [];
        end
        
        % Drop extra points at the end
        if size(nData,1) > nReadPts
            nData(nReadPts+1:end,:) = [];
        end
        
        return;
    end % sub_SIO
end % sub_GetData


%{
Regarding the SIO logger's timing problem:
--------------------------------------------------------------------------------
Back in 2015 we implemented a timing pulse from SUESI to Vulcans and uncovered
a timing error in the SIO data logging system. The email thread below documents
the discussion about this that I had with colleagues far and wide. I fixed the
problem by embedding a correction in getsio.m, version 3.5a, dated Jan 2015 in
the code (but it was actually 2016 I was living in the past at the beginning of
the new year.)

S.C. March 26, 2021
--------------------------------------------------------------------------------
From: Steven Constable 
Sent: Thursday, October 15, 2015 1:59 PM 
To: Kerry Key; Samer Naif; KarenWeitemeyer; Peter Kannberg; Dallas Sherman;
    David Myer; Brent Wheelock
Cc: Jacques Lemire; John Souders; Peter Kowalczyk (OFG)

Subject: CSEM timing errors

Dear fellow CSEMers,

In May 2013 Samer found some bugs in the CSEM processing code (csemFFT.m) that
dealt with sample timing and thus affected CSEM phase calculations. When fixing
these bugs, David also modified the code to use the time recorded in the header
for the first sample point. This time is typically around 5 milliseconds before
or after the requested wakeup time. I think that Allen Nance was consulted on
this and affirmed that the time recorded in the header was correct. At least,
this was Allen’s opinion when I asked him last week. So what David did was
reasonable given the information we had.

The modifications to the Vulcan and Porpoise systems to feed GPS time into the
loggers raised various issues with regard to sample timing. The MkIV loggers in
the Vulcans have a random offset time on startup as a result of a firmware bug.
Allen can fix this when the instruments come back from Japan/Canada. The MkIII
(Porpoise) loggers seem to behave much more systematically, and as part of
trying to understand this I fed GPS clock square waves into the loggers on the
bench. The most accurate way to estimate time shifts is to process up the square
wave signals as CSEM data and look at the phases of the square wave harmonics,
which is what I did.

The results were puzzling. I finally noticed that the timing shifts of the
square wave signals were similar to the timing offsets recorded in the header
time. I zeroed out the timing correction in the processing code and got a much
smaller timing error that amounted to 0.55 of a sample. This actually makes
sense the antialiasing filters in the ADC put a 39point delay in the data, which
Allen corrects for. It appears that this is really 39.55 points. I reported this
to Allen and asked him if it was possible that the times in the header were
wrong. He worked on this for a couple of days and this morning told me that this
was indeed the case. Turns out that the software real time clock is only updated
every 10 ms to save power, so when an interrupt from the ADC comes in to say
that a sample is ready, he reads the clock, which may be as much as 9 ms slow.

This isn’t a problem for 25 Hz sampling because the 40 ms sample rate falls onto
the 10 ms updates, and the header time should be 00:000 seconds. But, 25 Hz
still suffers from the 0.55 sample shift I described above, as does 125, 250,
500, and 1000 Hz after the start time is rounded to whole seconds.

62.5 Hz is special. This frequency is generated purely to provide compatibility
with the MkII instruments, and requires a special antialiasing filter to be
loaded into the ADC. For some reason this can result in a positive time being
reported in the header (00.006) but also 59.996, based on looking at some
SERPENT headers. Anyway, if you round these to whole seconds, then the residual
timing error is 0.7 ms or 0.04 samples (but only for 62.5 Hz). I would have to
test a bunch of instruments to see if this is systematic, but this is barely
more than a degree at 5 Hz, so probably can be ignored.

So the end of the story is this: For the Mk III instruments, we need to modify
the processing code to round the clock time to whole seconds, and correct the
phase by a time equal to 0.55 the sample interval, except for 62.5 Hz. Dave I
can do this easily enough, but donÕt know if there are other places in the code
that used the start time. For example, if we want millisecond timing in lcPlot
we might need corrections there. Probably the cleanest thing is to have the
getSIO routine round out the start time as soon as the data are read. That
should fix everything, no?

The good news is that we should be able to fit amplitude and phase together more
easily from now on, and since the problem is systematic, we can reprocess all
the old data sets. Incidentally, the Porpoise/Vulcan timing signals suggest that
the Seascan clock drift is close to linear.

Cheers to all,

Steve.
--------------------------------------------------------------------------------
On Oct 26, 2015, at 11:07 AM, David Myer <dmyer@bluegreengeophysics.com> wrote:

Steve,

Yes and no.

The right place to fix the clock zero time is in getsio.m. The processing code
works with multiple file types (e.g. emgs, ohm) so it should always believe the
clock times. If the clock times are wrong, then the appropriate get... routine
should fix that.

    That makes sense to me.

This will take care of the clock fractional start seconds, but not the 0.55
sample shift you mention. What is this shift in real time?

    Since it is a fraction of a sample, it depends on the sample rate. In real
    time it is 0.55/ f seconds where f is the sample rate.

You mention a 39point delay. Is that at whatever sampling frequency is selected
or is this from some backend clock that always runs at one frequency? You also
mention a 10 ms clock update which may be 09 ms off, so I’m a little confused.
If you’re talking about the specific case of 25 Hz (i.e. 40 ms between samples,
thus the 39 "point" delay), then 09 ms of delay in the clock is up to a quarter
sample, not half.

    These are two different issues. The 10 ms clock update is for a software
    real time clock that Allen updates less often than he should to save power.
    So when the data starts, at the time you have asked it to give or take the
    0.55 sample shift (almost always on the hour), he reads the clock which
    might not have been updated in the last 09 ms.

    The 39 point delay (which might not be 39 points, but that doesn’t matter)
    is simply the delay associated with the digital antialiasing filters. We
    found this early on and Allen shifts the data to compensate for this, but
    since this was done while developing the OBS LCHEAPO, and seismologists are
    not interested in phase, just time, nobody ever thought to get this to
    better than a whole sample.

Note that from what you describe about the clock updates, the 0 to 9 ms of delay
defines a minimum phase error for the data. This would be a systematic phase
error for one site, but random across a collection of sites. Probably not too
random, since all the instruments are behaving the same.

This error grows linearly with the frequency being measured ( dPhase = f * 0.009
* 360 ). At 1 Hz, it 3.24 degrees. At 10 Hz, it’s 32.4 degrees. That’s pretty
big.

    Yes! Hence the problem.

Does the clock update only every 10 ms for all sampling frequencies or is it
different 62.5, 125, 250, etc...? It seems odd to me to update the clock only
every few samples in the case of the higher frequencies.

    My understanding is that the real time clock is not controlling the sampling
    it is just there to time stamp things. And yes, this is quite a bug. It is
    frequency independent.

Since this sounds like an unknowable delay, then the correct handling for this
is to put it in the error budget for phase. That means we need to know what the
maximum slop is for the clock time stamps for each sampling frequency. (Maybe
it’s always 9ms regardless of sampling freq?)

    Not unknowable. It is probably always the same amount for each frequency,
    but the best thing is to round to the whole second in getSIO, as you say.
    The 0.55 sample shift could be rolled into the transmitter time tag or put
    into the FFT code as a sample frequency dependent time shift.

d

PS. The clock start time problem will also affect the MT processing, but at the
frequencies we’re normally working with, it should be negligible.

    Yes, and if you are not doing site to site transfer functions, it doesn’t
    matter since it is the same for the E and B instruments. The EMI MT24 system
    had a huge bug of this nature that nobody cared about until Agip had me run
    my system side by side with the MT24. Of course, everyone assumed the error
    was mine, until I showed that the MT24 was off by about 30 seconds.

    Cheers,

    Steve.
%}
