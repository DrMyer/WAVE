function b = testMET_EMAGE( s )
% Quick function used by WAVE (via ListFmts_GPS.m) to test whether a given
% single line from a file indicates that the file is a ship's MET file in
% the format found on the EMAGE cruise (R/V Sikuliaq)
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
% See also ListFmts_MET, readMET_EMAGE

try
    % This is the format from R/V Sikuliaq in 2019 EMAGE cruise
    %
    % <LDS Logger ID><tab><LDS time stamp><tab><data>
    % <LDS Logger ID> = 'winch_rapp'
    % <LDS time stamp> = 'yyyy-mm-ddThh:mm:ss.mmmmZ'
    % <data> = hnnnnnnn P=nnnnnn.n hPa   T=nnn.n 'C RH=nnn.n %RH
    %{
		h<n> = -- status
        P= -- pressure in hPa (== millibars)
        T= -- temp in C
        RH= -- relative humidity (%)
    %}
    %
    c = strsplit( s, char(9) ); % tab delimited
    b = strncmpi( c{1}, 'met_ptu', 7 );
    
catch
    b = false;
end

return;
end % testMET_EMAGE
