%% Choice ball interface script
% Written by Josh Sanders, October 2010
% Edited for publication September 2012

%% Check to make sure old UDP connections are shut down
if exist('udpA')
    fclose(udpA)
    delete(udpA)
    clear
end
global udpA

%% Prepare Output File Name. Files are stored locally.
DataDir = 'C:\BallData\';
% Format the date and time (used in filename)
DatePart = [datestr(now,3) datestr(now,7) '_' datestr(now,10) '_'];
TheTime = fix(clock);
TimePart = [num2str(TheTime(4)) '_' num2str(TheTime(5)) '_' num2str(TheTime(6))];
Extension = '.mat';
FileName = [DataDir DatePart TimePart Extension];

%%
ip = resolveip('HostNameGoesHere'); % Get the ip address of the governing computer using its network hostname
portA = 9090; % The local port on this machine
portB = 9091; % The port on the governing computer

%% Create UDP Object
udpA = udp(ip,portB,'LocalPort',portA, 'InputBufferSize', 100000, 'OutputBufferSize', 100000, 'Timeout', 10);

%% Connect to UDP Object
fopen(udpA)

%% Wait for a UDP handshake from the governing computer
Chkbit = '';
disp('Waiting for governing computer. . .')
while strcmp(Chkbit, '') % While no byte has been received
    Chkbit = fscanf(udpA); % Scan the UDP port for a byte from the governing machine
end

%% Send a confirmation byte
disp('Wake-up Received. Sending Reply.')
fwrite(udpA,1) % Send a byte back to the governing machine

%% Prepare session
flushinput(udpA); % Clear UDP buffer
clear RDist LDist
MaxTrials = fread(udpA, 1, 'int16'); % The number of trials in the session.
RDist = fread(udpA, 1, 'int16'); % Receive right side movement threshold for the session from governing computer (units in pixels)
LDist = fread(udpA, 1, 'int16'); % Receive left side movement threshold from governing computer (units in pixels)
BallMoveDelay = fread(udpA,1, 'uint16'); % Receive the amount of time (in seconds) the ball must be motionless before the next trial can begin
RawBallData = cell(1,MaxTrials); % Create empty vector for ball position data. Each cell contains an 3 x nSamples array. The first row is Xposition, the second row is Yposition and the third row is time.

%% Initialize trackball and logic I/O interface
disp('Trial Data Received. Initializing Trackball.')
set(0,'PointerLocation',[450 450]); % Sets the mouse position to the middle of the screen
clear dio % Clears previous instances of DIO object
dio = digitalio('parallel', 1); % Creates a parallel port object
addline(dio,0:1,'out'); % Initializes pins 0-1 and sets them to output mode.
% The following code indicates events:
%  DIO line 0    DIO line 1    Meaning
%      1             0         Left threshold crossing
%      0             1         Right Threshold crossing
%      1             1         Timeout

% The governing machine scans both lines until one is high. Then, it pauses
% briefly, reads both and interprets the code.

addline(dio, find(strcmp(dio.Line.LineName, 'Pin13')), 'in'); % Initializes pin 13 and sets it to input mode.
InputLine = find(strcmp(dio.Line.LineName, 'Pin13')); % Gets the hardware line number of pin 13 (For more on this, execute "doc addline" at the command prompt)

%% Main loop

for z = 1:MaxTrials
    % Initialize trial data vector for current trial
    TrialRecord = nan(3,10000); % TrialRecord is the 3 x nSamples array to be stored in this trial's position in RawBallData (see line 53). This line preallocates the array to 10000 samples.
    RecordIndex = 1; % The position of the current position/time sample in the array. Initialized to 1.
    TrialRecord(1,RecordIndex) = 0; % Xposition 0 = 0;
    TrialRecord(2,RecordIndex) = 0; % Yposition 0 = 0;
    TrialRecord(3,RecordIndex) = 0; % Time 0 = 0;
    
    % Reset the two output logic lines to 0
    OutputLine1Level = 0;
    OutputLine2Level = 0;
    putvalue(dio.Line(1),OutputLine1Level); % Sets the logic level of output line 1
    putvalue(dio.Line(2),OutputLine2Level); % Sets the logic level of output line 2
    
    % Reset ball position to 0. (Ball position is net movement, starting at
    % 450,450)
    BallXPosition = 0;
    BallYPosition = 0;
    
    % Boundaries are position thresholds for sample acquisition. Each time
    % the mouse cursor moves past these thresholds, a sample is added to
    % TrialRecord (Time, X, Y)
    RightBoundary = 451;
    LeftBoundary = 449;
    TopBoundary = 449;
    BottomBoundary = 451;
    
    
    Terminated = 0; % Terminated stores 0 or 1 depending on whether the governing computer has terminated the trial.
    disp('Waiting for Next Trial Start. . .')
    
    % When the real-time linux state machine begins a new trial, the input line on the ball computer parallel port is driven high.
    LinuxReady = 0; % Status of parallel port input line
    while LinuxReady == 0
        LinuxReady = getvalue(dio.Line(InputLine)); % Read the input line's logic level.
    end
    
    
    Tolerance = 1; % Tolerance is the amount of ball movement (in pixels) that is allowed during the 1 second non-movement period that begins each trial.
    % If the ball moves beyond Tolerance pixels, the non-movement period is
    % started over.
    disp('Waiting for Ball Movement Idle. . .')
    
    % Check to make sure the ball does not move during the non-movement period
    tic % Reset timer to 0
    while toc < (BallMoveDelay) % While timer is less than ball movement period (in seconds)
        k = get(0,'PointerLocation'); % Get the mouse cursor position
        xInd = k(1);yInd = k(2); % Store mouse cursor X and Y in xInd and yInd
        if abs(xInd-450) > Tolerance || abs(yInd-450) > Tolerance % If the mouse has moved beyond Tolerance pixels
            set(0,'PointerLocation',[450 450]); % Reset the mouse position
            tic; % Reset the ball movement period timer
        end
    end
    disp('Ball Idle Confirmed.')
    
    
    % Logic handshake with real-time linux state machine to confirm that the ball idle condition has ended
    putvalue(dio.Line(1),0) % Sets the logic level of output line 1
    putvalue(dio.Line(2),1) % Sets the logic level of output line 2
    LinuxReady = 0;
    while LinuxReady == 0
        LinuxReady = getvalue(dio.Line(InputLine)); % Reads the logic line from the real-time Linux state machine
    end
    putvalue(dio.Line(1),0) % Sets the logic level of output line 1
    putvalue(dio.Line(2),0) % Sets the logic level of output line 2
    
    set(0,'PointerLocation',[450 450]); % Reset the mouse cursor to trial-start position
    tic % Reset the timer to 0
    % Loop until a threshold in either direction is crossed, or the
    % governing computer sends a terminate code over Ethernet
    while Terminated == 0 && (BallXPosition < RDist)  && (BallXPosition > LDist)
        k = get(0,'PointerLocation'); % Get the mouse cursor position
        xInd = k(1);yInd = k(2); % Store mouse cursor X and Y in xInd and yInd
        xtemp = xInd; % Store the x position in a temporary variable
        ytemp = yInd; % Store the y position in a temporary variable
        while xInd == xtemp && yInd == ytemp % While the mouse has not moved
            k = get(0,'PointerLocation'); % Get the mouse cursor position
            xInd = k(1);yInd = k(2); % Store mouse cursor X and Y in xInd and yInd
            if udpA.bytesavailable ~= 0 % If any bytes have been received from the governing computer
                Terminated = 1; % Indicate that the loop was terminated by a timeout
                trash = fscanf(udpA); % Empty remaining bytes from the udp Buffer
                disp('Timeout');
                break
            end
        end
        if Terminated == 1
            break
        end
        BallXPosition = BallXPosition + (xInd - xtemp); % Update the trackball X position with the current difference between the temporary stored position and the new position
        BallYPosition = BallYPosition + (yInd - ytemp); % Update the trackball Y position with the current difference between the temporary stored position and the new position
        RecordIndex = RecordIndex + 1; % Increment the length of the current trial position record
        TrialRecord(1,RecordIndex) = round(BallXPosition); % Store the X position of the trackball at the current time in the trial record
        TrialRecord(2,RecordIndex) = round(BallYPosition); % Store the Y position of the trackball at the current time in the trial record
        TrialRecord(3,RecordIndex) = toc; % Store the current time in the trial record
    end
    
    if Terminated == 0 % If a distance boundary was reached during the permitted time
        OutputLine1Level = 0; OutputLine2Level = 0; % Set the default levels of the output lines to 0
        if BallXPosition > 0 % If the x position crossed the positive (right side) threshold 
            OutputLine2Level = 1; % Set line 2 to high
        else % If the x position crossed the negative (left side) threshold 
            OutputLine1Level = 1; % Set line 1 to high
        end
        % Write the binary threshold code to the logic lines
        putvalue(dio.Line(1),OutputLine1Level) 
        putvalue(dio.Line(2),OutputLine2Level)
    end
    pause(.01) % Wait for the real-time Linux state machine to read the lines
    % Reset the lines to logic low
    putvalue(dio.Line(1),0)
    putvalue(dio.Line(2),0)
    
    % 
    TrialRecord(:,any(isnan(TrialRecord),1)) = []; % Cut out empty cells from the record of positions (was preallocated at 10,000 samples)
    RawBallData{z} = TrialRecord; % Put this trial's position record in the data file.
    save(FileName, 'RawBallData'); % Save the data file
end

