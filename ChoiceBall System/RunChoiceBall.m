function [Choice, Timestamps, Positions] = RunChoiceBall(ChoiceThreshold, Timeout, IdleTimer)
% Programmed by Josh Sanders, September 2012
% Correspondence should be addressed to sanders@cshl.edu

% Example usage:
% [Choice, Timestamps, Positions] = RunChoiceBall(500, 10); 

% The example runs a single trial until the mouse's raw position reaches 500 or -500, or time exceeds 10 seconds.
% Returns the choice [1 = right 2 = left 3 = timeout] timestamps (in seconds) and position (in pixels)

% The output should look something like:

% Choice =
%
%    1
%
%
% Timestamps =
%
%         0    0.1482    0.1983    0.2485    0.2988    0.3489    0.3990    0.4482    0.4984    0.5487%
%
%
% Positions =
%
%     0     4    27    44    55    69    81    89   100   109

% In addition to the "Choice" function output (1, 2 or 3), the choice will be displayed
% in binary TTL logic on Arduino I/O lines 20 and 21.
% Arduino I/O line 19 will be driven low on trial start, and high when a report on lines 20 and 21 is
% ready to read.

global ChoiceBallSystem % The ChoiceBallSystem global variable was created by StartChoiceBall.m, and is a struct that contains a MATLAB serial port object.

%% Program the threshold and time-out
% Threshold in mouse sensor units (100 = ~5 degrees rotation for a 55mm ball)
% Time-out in seconds
Timeout = Timeout*1000; % Convert to milliseconds
IdleTimer = IdleTimer*1000; % Convert to milliseconds
fwrite(ChoiceBallSystem.SerialPort, char(61)); % Send the programming Op-Code
fwrite(ChoiceBallSystem.SerialPort, ChoiceThreshold, 'uint16'); % Send choice threshold (2 bytes)
fwrite(ChoiceBallSystem.SerialPort, Timeout, 'uint16'); % Send timeout (2 bytes)
fwrite(ChoiceBallSystem.SerialPort, IdleTimer, 'uint16'); % Send Ball idle timer (2 bytes)
Ack = fread(ChoiceBallSystem.SerialPort,1); % Receive an acknowledgement from the microcontroller
if isempty(Ack)
    error('Failed to send parameters to the choice ball');
end

%% Run trial
fwrite(ChoiceBallSystem.SerialPort, char(62)); % Send the trial start Op-Code
TrialFinished = 0; % Logic byte to determine whether a threshold has been crossed or a timeout has occurred
while TrialFinished == 0 % While the ball is still collecting data
    if ChoiceBallSystem.SerialPort.BytesAvailable > 0 % If a new message has arrived on the serial port
        MessageHeader = fread(ChoiceBallSystem.SerialPort,1); % Read the message header. 
        if MessageHeader == 5 % If the header = 5 (To distinguish legitimate data transmissions - otherwise buffer is dumped)
            nSamples = fread(ChoiceBallSystem.SerialPort,1)+1; % Receive the number of position/time samples to expect in this transmission
            for x = 1:nSamples % For each sample
                Positions(x) = str2double(fscanf(ChoiceBallSystem.SerialPort)); % Get the ball position during this sample
            end
            for x = 1:nSamples % For each sample
                Timestamps(x) = str2double(fscanf(ChoiceBallSystem.SerialPort))/1000000; % Get the timestamp during this sample (and convert from us to seconds)
            end
            if abs(Positions(length(Positions))) > ChoiceThreshold % If a choice threshold was crossed
                if Positions(length(Positions)) > 0 % If the last position in the position vector is positive
                    Choice = 1; % The ball crossed the right threhsold. Choice 1.
                else
                    Choice = 2; % The ball crossed the left threhsold. Choice 2.
                end
            else
                Choice = 3; % The ball didn't cross a threshold. Choice 3.
            end
            TrialFinished = 1; % Set the logic byte to 0 to exit the loop and return data
        else
            junk = fread(ChoiceBallSystem.SerialPort, ChoiceBallSystem.SerialPort.BytesAvailable); % Not valid data, dump serial buffer
        end
    end
end
