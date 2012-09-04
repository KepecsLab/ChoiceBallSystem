% Programmed by Josh Sanders, September 2012
% Correspondence should be addressed to sanders@cshl.edu
global ChoiceBallSystem
fclose(ChoiceBallSystem.SerialPort); % Close the Serial Port. (Necessary for other programs to access it)
delete(ChoiceBallSystem.SerialPort); % Delete the Serial Port object from memory.
clear global ChoiceBallSystem % Clear the global variable.