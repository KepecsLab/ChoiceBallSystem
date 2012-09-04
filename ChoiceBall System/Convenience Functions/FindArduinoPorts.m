function Ports = FindArduinoPorts(ComPortString)

% This function takes the command line output of compiled program
% "listComPorts" (in BpodSystemFiles/CompiledModules) and extracts all ports
% registered to Arduinos.

Words = ParseCOMString(ComPortString);

Ports = cell(1,1);
nPortsDetected = 0;
for x = 1:length(Words)
    Candidate = Words{x};
    Candidate = upper(Candidate);
    if length(Candidate) > 3
        if sum(Candidate(1:3) == 'COM') == 3
            PortType = Words{x+2};
            PortType = upper(PortType);
            if length(PortType) == 7
                if strcmp(PortType, 'ARDUINO')
                    nPortsDetected = nPortsDetected+1;
                    Ports{nPortsDetected} = Candidate;
                end
            end
        end
    end
end
