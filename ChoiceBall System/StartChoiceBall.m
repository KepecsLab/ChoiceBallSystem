% Choice ball initialization script.

% This script creates a struct in the base workspace containing a serial
% port object. It attempts to auto-detect the serial port that Arduino is
% connected to, opens the port and conducts a single byte handshake.

% Programmed by Josh Sanders, September 2012
% Correspondence should be addressed to sanders@cshl.edu
warning off % Suppresses warnings about ports that don't respond to the handshake properly
global ChoiceBallSystem
disp('Connecting to ChoiceBall')
if ~isempty(ChoiceBallSystem)
    fclose(ChoiceBallSystem.SerialPort);
end

ChoiceBallPath = which('StartChoiceBall');
ChoiceBallPath = ChoiceBallPath(1:length(ChoiceBallPath)-17);

Ports = cell(1,1); % Ports is a cell array contatining a list of available serial ports 
if ispc % On a PC, the system can auto-find ports using a compliled system script.
    [trash, RegisteredPorts] = system([ChoiceBallPath 'CompiledModules\List COM Ports\listCOMPorts.exe']);
    Ports = FindArduinoPorts(RegisteredPorts);
else % Tested on Mac OSX Snow Leopard.
    [trash, RawSerialPortList] = system('ls /dev/tty.*');
    Ports = ParseCOMString_UNIX(RawSerialPortList);
end
if isempty(Ports)
    try
        fclose(instrfind)
    catch
        error('Could not find a valid Choice Ball module.');
    end
    clear instrfind
end

% Make it search on the last successful port first
ComPortPath = fullfile(ChoiceBallPath, 'Convenience Functions', 'LastComPortUsed.mat');
if exist(ComPortPath) == 2
    load(ComPortPath);
    [InList, pos] = FastWordDetect(LastComPortUsed, Ports);
    if InList,
        Temp = Ports;
        Ports{1} = LastComPortUsed;
        Ports(2:length(Temp)) = Temp(find(1:length(Temp) ~= pos));
    end
end

Found = 0;
x = 0;
while (Found == 0) && (x < length(Ports))
    x = x + 1;
    disp(['Trying port ' Ports{x}])
    TestSer = serial(Ports{x}, 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Timeout', 1, 'DataTerminalReady', 'off');
    fopen(TestSer);
    set(TestSer, 'RequestToSend', 'on')
    if ~strcmp(system_dependent('getos'), 'Microsoft Windows Vista')  
      pause(1);
    end
    fprintf(TestSer, char(60));
    tic
    g = 0;
    try
        g = fread(TestSer, 1);
    catch
        % ok
    end
    if g == '5'
        Found = x;
        fclose(TestSer);
        delete(TestSer)
        clear TestSer 
    end
end
pause(.1);
if Found ~= 0
ChoiceBallSystem.SerialPort = serial(Ports{Found}, 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Timeout', 1, 'DataTerminalReady', 'off');
else
    error('Could not find a valid Choice Ball module.');
end
set(ChoiceBallSystem.SerialPort, 'OutputBufferSize', 8000);
set(ChoiceBallSystem.SerialPort, 'InputBufferSize', 8000);
fopen(ChoiceBallSystem.SerialPort);
set(ChoiceBallSystem.SerialPort, 'RequestToSend', 'on')
fwrite(ChoiceBallSystem.SerialPort, char(60));
tic
    while ChoiceBallSystem.SerialPort.BytesAvailable == 0
        if toc > 1
            break
        end
    end
fread(ChoiceBallSystem.SerialPort, ChoiceBallSystem.SerialPort.BytesAvailable);
set(ChoiceBallSystem.SerialPort, 'RequestToSend', 'off')
disp(['Choice Ball connected on port ' Ports{Found}])
LastComPortUsed = Ports{Found};
save(ComPortPath, 'LastComPortUsed');
clear Found g x Ports serialInfo ComPortPath LastComPortUsed DTR ChoiceBallPath ans InList Temp pos
if ChoiceBallSystem.SerialPort.BytesAvailable > 0
    trash = fread(ChoiceBallSystem.SerialPort, ChoiceBallSystem.SerialPort.BytesAvailable);
end
clear trash RegisteredPorts