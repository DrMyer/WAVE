function PlotTowedCSEM( oWave, sFile, bKeepOpen )
% Plot data from a single Towed CSEM output file (this is a generic plotting
% routine which only exists because DataMan does not support towed CSEM)
%
% Params:
%   oWave   - the cwave object with all the data
%   sFile   - path+file to the *.towedcsem.mat file produced by WAVE
%   bKeepOpen - (opt; dflt F) t/f if figure should remain open after plotting
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
        sFile char
        bKeepOpen logical = false
    end
    
    % Load the data into a structure
    stRead = load( sFile );
    [~,sFile] = fileparts( sFile );
    sFile   = strrep( sFile, '.towedcsem', '' ); % strip 2nd extension
    iEy     = find( strcmpi( stRead.tCh.Type, 'Ey' ), 1, 'first' );
    iEz     = find( strcmpi( stRead.tCh.Type, 'Ez' ), 1, 'first' );
    
    % Plot Ey and Ez, all frequencies, amp & phase
    hFig = getStackedFig( 'page' );
    hEyA = subplot(4,1,1, 'Parent', hFig );
    hEyP = subplot(4,1,2, 'Parent', hFig );
    hEzA = subplot(4,1,3, 'Parent', hFig );
    hEzP = subplot(4,1,4, 'Parent', hFig );
    nClr = DavesDiscreteColors( size(stRead.nAmp,3) );
    for iFreq = 1:size(stRead.nAmp,3)
        sFreq = sprintf( '%g Hz', stRead.stRx.nFreqList(iFreq) );
        
        semilogy( hEyA, stRead.tNavSuesi.AlongTrack, stRead.nAmp(:,iEy,iFreq), '.' ...
            , 'Color', nClr(iFreq,:), 'LineStyle', 'none', 'DisplayName', sFreq );
        hold( hEyA, 'on' );
        legendoff( semilogy( hEyA, stRead.tNavSuesi.AlongTrack, stRead.nAmpErr(:,iEy,iFreq), '-' ...
            , 'Color', nClr(iFreq,:), 'Marker', 'none' ) );
        
        plot( hEyP, stRead.tNavSuesi.AlongTrack, stRead.nPhs(:,iEy,iFreq), '.' ...
            , 'Color', nClr(iFreq,:), 'LineStyle', 'none', 'DisplayName', sFreq );
        hold( hEyP, 'on' );
        
        semilogy( hEzA, stRead.tNavSuesi.AlongTrack, stRead.nAmp(:,iEz,iFreq), '.' ...
            , 'Color', nClr(iFreq,:), 'LineStyle', 'none', 'DisplayName', sFreq );
        hold( hEzA, 'on' );
        legendoff( semilogy( hEzA, stRead.tNavSuesi.AlongTrack, stRead.nAmpErr(:,iEz,iFreq), '-' ...
            , 'Color', nClr(iFreq,:), 'Marker', 'none' ) );
        
        plot( hEzP, stRead.tNavSuesi.AlongTrack, stRead.nPhs(:,iEz,iFreq), '.' ...
            , 'Color', nClr(iFreq,:), 'LineStyle', 'none', 'DisplayName', sFreq );
        hold( hEzP, 'on' );
        
    end
    
    % Clean up the plots
    hold( hEyA, 'off' );
    hold( hEyP, 'off' );
    hold( hEzA, 'off' );
    hold( hEzP, 'off' );
    title( hEyA, strrep( sFile, '_', ' ' ) );
    subtitle( hEyA, 'Ey Amplitude' );
    title( hEyP, 'Ey Phase' );
    title( hEzA, 'Ez Amplitude' );
    title( hEzP, 'Ez Phase' );
    axisTicksUTM( hEyA, 'x' );
    axisTicksUTM( hEyP, 'x' );
    axisTicksUTM( hEzA, 'x' );
    axisTicksUTM( hEzP, 'x' );
    axisTight( hEyA );
    axisTight( hEyP );
    axisTight( hEzA );
    axisTight( hEzP );
    decadeTick( hEyA, 'y' );
    decadeTick( hEzA, 'y' );
    xlabel( hEzP, 'Along track distance (m)' );
    legend( hEzP, 'location', 'southoutside', 'orientation', 'horizontal' );
    
    % Save the figure
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, sFile ), 'save' );
    
    % If don't want the figure hanging around, close it
    if ~bKeepOpen
        delete( hFig );
    end
    
    return;
end % PlotTowedCSEM
