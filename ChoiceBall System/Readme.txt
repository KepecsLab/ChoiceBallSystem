Thanks for trying out Choice Ball!

Use of a microcontroller with MATLAB provides more precise responses to mouse position events than are possible with MATLAB code alone, by eliminating jitter introduced by the computer's operating system.

This choice ball client was tested on MATLAB 7.9.0 (R2009b), with PCs running Windows XP and Windows 7.


Correspondence should be addressed to sanders@cshl.edu


Before you begin, you'll need:

> 1 Arduino Mega 2560 R3 (That's the microcontroller)
> 1 Circuits@Home USB Host Shield v2.0 (That's a USB card for the microcontroller)
> 1 USB Trackball (Recommend Kensington Expert Mouse Model K64325) modified with an axial ping pong ball as per Sanders et.al.
> 1 PC running Windows XP or Windows 7. Other platforms and operating systems may require code modification.

************* SETUP - Part 1 (assembling the apparatus)

1. Solder the strip headers into the USB Host Shield, and plug it into Arduino Mega.

2. Attach an LED (and of course, a current limiting resistor in series) to Arduino pin 18. This is the indicator LED that notifies the subject to stop moving the ball. Alternatively, this logic line can inform a behavior system of the ball idle condition.

3. If desired, attach a behavior system or logic monitor to Arduino pins 19, 20 and 21. These lines indicate the subject's choice so that a behavior system can respond in real-time (i.e. by dispensing reward or updating a display)


************* SETUP - Part 2 (Configuring the microcontroller)

1. Download and extract the latest Arduino software from http://arduino.cc/en/Main/Software

2. Copy the ChoiceBallMod library folder from: 
\ChoiceBallSystem\Microcontroller Code\Arduino Library
to the new Arduino directory you unzipped:
\arduino-1.0.1-windows\arduino-1.0.1\libraries\

3. Run Arduino.exe. Then, close Arduino. (This will make a directory in your documents folder called "Arduino".

4. Copy the ChoiceBallFirmware from:
\ChoiceBallSystem\Microcontroller Code\
to the new Arduino directory in your documents folder.

5. Plug the Arduino microcontroller into a USB port on your computer. In Windows, you'll need a driver. When prompted for drivers, point Windows to the /drivers folder in the Arduino directory.

6. Make note of the COM port that is assigned to Arduino (in Windows, this is viewable from the device manager under the "Ports (COM & LPT)" tab.)

7. Run Arduino.exe. Select the correct port from Tools > Serial Port. Select "Arduino Mega 2560" from Tools > Board.

8. Open the "ChoiceBallFirmware" sketch from File > Sketchbook

9. Click the "Upload" button on the program window. (In Arduino 1.0.1 it's a round button with a right-pointing arrow). In a moment, Arduino should indicate "Done Uploading".

10. Unplug the trackball from the USB card, and plug it back in. This will prompt the card to ask the device for ID information, and should only need to be done once so long as Arduino is powered.

************ SETUP - Part 3 (Configuring MATLAB and testing the device)

1. Add the ChoiceBallSystem folder (and all subfolders) to the MATLAB path: 
File > Set Path > Add With Subfolders.
Save the path.

2. At the MATLAB prompt, type "StartChoiceBall"

  The computer should automatically search COM ports until it finds Arduino and connects to it. A struct will be created in your base workspace containing a MATLAB serial port object.

3. At the MATLAB prompt, type "[Choice, Timestamps, Positions] = RunChoiceBall(100, 3, 1)"

RunChoiceBall is the main function you'll use. The format is:
[Choice, Timestamps, Positions] = RunChoiceBall(ChoiceThreshold, Timeout, IdleTimer)
See comments in RunChoiceBall.m for more details.

The Idle Period LED should illuminate, and extinguish after 1 second if you don't move the trackball. Once the LED has extinguished, rotate the ball in one direction until the function returns its outputs. If all is working, you should see something like: 

Choice =

    1


Timestamps =

    0    0.1482    0.1983    0.2485    0.2988    0.3489    0.3990    0.4482    0.4984    0.5487


 Positions =

    0     4    27    44    55    69    81    89   100   109


************ SETUP - Part 4 (Troubleshooting)

This section contains the solutions to actual problems people have received and written to us about. Don't be shy! sanders@cshl.edu

1. Problem: On running "StartChoiceBall", MATLAB returns "Could not find a valid Choice Ball module."
Solution: This is usually due to the Arduino driver not being installed properly. In Windows, check the device manager to make sure the Arduino has been assigned a COM port.

2. Problem: On running "RunChoiceBall", the Idle LED lights and extinguishes, but the system does not respond to trackball movement.
Solution: The trackball's custom-modified LED may have failed. Check to make sure it is illuminated. The trackball may not be properly paired with the USB card. Unplug the trackball from the USB card, and plug it back in. This will prompt the card to ask the device for ID information, and should only need to be done once so long as Arduino is powered.

3. Problem: When uploading the Choice Ball firmware to Arduino (Setup part 2, step 9), you receive an error message: "avrdude stk500_getsync(): not in sync resp=0x00"
   Solution: Make sure you have properly selected the Arduino Mega 2560 board from the "Boards" submenu under "Tools".
