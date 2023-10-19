function nDepth = cvtValeportPressureToDepth( nPressure, nLat )
% nDepth = cvtValeportPressureToDepth( nPressure, nLat )
%
% Convert the Valeport SVXtra's dbar pressures into depth.  The important part
% of this function was provided by K.Weitemeyer. Wrapper by D.Myer to account
% for valeport measurements for which we don't have a latitude because of
% various vagaries of the Suesi data logging process.
%
% March 2009
%
% Params:
%   nPressure   - vector of pressure in decibars with TARE pressure at sea
%               surface ALREADY SUBTRACTED!  This is usually 10 deciBars.
%   nLat        - scalar or vector of latitudes in degrees for each
%               pressure. Some of these values may be NaN in which case the
%               non-NaN values will provide a basis for interpolation.
%
% Returns:
%   nDepth      - corrected depth.
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

    % If lat is a scalar, convert to a vector for programming convenience
    if length(nLat) == 1
        nLat = repmat( nLat, size(nPressure) );
    end
    
    % Pre-allocate return (may be LARGE)
    nDepth = NaN( size(nPressure) );
    
    % Only deal with those items for which I have both pressure & lat.
    iUse = ~(isnan(nPressure) | isnan(nLat));
    
    LAT = nLat(iUse);
    P   = nPressure(iUse);
%%%-------------------------------------%%%
%%% Code below provided by K.Weitemeyer %%% by email Jan 28, 2009
%%%-------------------------------------%%%
% depth in meters from pressure in decibars using Sauders and Fofonoff's
% Method. Deep-Sea Res. 1976, 23, 109-111. Formula refitted for 1980
% Equation of state 
% units:
%       Pressure    P       decibars
%       Latitude    LAT     degrees
%       Depth       DEPTH   meters
%  check value: depth = 9712.653 m for P = 10000 decibars, latitude= 30
%  degrees Above for standard ocean T= 0 deg Celsius; S = 35 (PSS-78)
% code is from Unesco technical papers in marine science 44. Algorithms for
% computation of fundamental properties of seawater, by Fofonoff and
% Millard, 1983. pages 25 - 28.
% According to the Valeport Model SVXtra the combined CTD and sound
% velocity profiler this is the Simple UNESCO depth
x = sin(LAT*pi/180);
x = x.*x;
%GR = gravity variation with latitude: Anon (1970) Bulletin Geodesique
GR = 9.780318*(1.0+(5.2788e-3+2.36e-5*x).*x)+1.092e-6*P;
depth = (((-1.82e-15*P+2.279e-10).*P-2.2512e-5).*P+9.72659).*P;
depth = depth./GR;
% THE ABOVE IS THE SAME CORRECTION IN THE VALEPORT MANUAL PAGE 43 SECTION 2
% ONLY DIFFERENCE IS VALEPORT MANUAL USES bars AND SO HAS A MULTIPLE OF 10
% ON THE PRESSURE MEASUREMENT 10 dbar = 1 bar, 0.1 bar = 1 dbar
%%%-------------------------------------%%%
%%% Code above provided by K.Weitemeyer %%%
%%%-------------------------------------%%%
    nDepth(iUse) = depth;
    
    % Interpolate to get values for depths for which there is no latitude
    iFix = find( isnan(nLat) & ~isnan(nPressure) );
    if ~isempty(iFix)
        % For interpolation, need single-valued list. So sort & sum.
        [nP,~,iROrder] = unique( P );
        for i = 1:length(nP)
            nD(i) = mean( depth( iROrder == i ) );
        end
        nD = reshape( nD, size(nP) );
        
        % Interpolate
        nDepth(iFix) = interp1( nP, nD, nPressure(iFix), 'linear', 'extrap' );
    end
    
    return
end
