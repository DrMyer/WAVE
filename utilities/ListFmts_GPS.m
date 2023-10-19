function tblList = ListFmts_GPS()
% Internal function called by WAVE to list all information about all the
% currently known ship GPS file formats. This code is automatically extended by
% the UI in WAVE, so edit carefully.
%
% Returns:
%   tblList - a table with information about each known format:
%   .Name - displayable name
%   .HeaderLines - number of header lines known to be in the file
%   .fcnTest - b = fcnTest(singleline) tests one line of text & says whether or
%               not it matches the known format for this file
%   .fcnRead - n = fcnRead(cList,hUIFig) processes a cell array list of files
%               displaying progress on the given UIFig and returning a matrix of
%               data values (not a table). 
%                   Cols: datenum longitude latitude <other ignored>
%   .Example - displayable example text to show the user
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

tblList = ListFmts_MASTER( 'GPS' );
        
% BELOW may be rewritten by the WAVE UI when the user defines new formats
%%--%% START
%%--%% END

return;
end % ListFmts_GPS


