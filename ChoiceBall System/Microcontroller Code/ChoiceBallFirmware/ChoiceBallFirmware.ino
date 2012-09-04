
// Firmware for the enhanced choice ball setup, based on Arduino
// Programmed by Josh Sanders, September 2012
// Correspondence should be addressed to sanders@cshl.edu

// Parts of this script (and dependent functions) were modified with permission, from joystick HID interface examples included in the 
// Circuits@Home USB Host Shield Library. The Circuits@Home Project is available at Http://www.circuitsathome.com/

// This script assumes you have done the following:
// > Attach a Circuits@Home USB Host Shield rev2.0 to an Arduino Mega 2560 r3
// > Attach an LED to Arduino pin 18 (used to indicate the ball idle period to the animal and to you as the developer)
// > Attach Arduino lines 19, 20 and 21 to a behavior system or other logic monitoring interface. Choice outcomes will be displayed on these lines (and also returned over USB serial)

// Import all libraries
#include <avr/pgmspace.h>
#include <avrpins.h>
#include <max3421e.h>
#include <usbhost.h>
#include <usb_ch9.h>
#include <Usb.h>
#include <usbhub.h>
#include <avr/pgmspace.h>
#include <address.h>
#include <hid.h>
#include <hiduniversal.h>
#include "hidjoystickrptparser.h"
#include <message.h>
#include <hexdump.h>
#include <parsetools.h>

// Declare global variables for trackball interfacing
USB Usb;
USBHub Hub(&Usb);
HIDUniversal Hid(&Usb);
JoystickEvents JoyEvents;
JoystickReportParser Joy(&JoyEvents);

// Declare global variables for timers and timestamps
unsigned long Timeout = 3000000; // This is the amount of time allowed for threshold crossings before the trial times out (in microseconds).
unsigned long BallIdlePeriod = 1000000; // This is the duration for which the ball must remain motionless in order to proceed with the trial (in microseconds).
unsigned long CurrentTime = 0; // This variable is updated in the script with the current time (in microseconds)
unsigned long StartTime = 0; // This variable holds the time of the start-point of interval measurements.
unsigned long ElapsedTime = 0; // This variable holds the interval derived as the difference between current time and start time
unsigned long BallPositionTimes[1000] = {0}; // This array holds the times at which ball position measurements were recorded (in microseconds)

// Declare global variables for ball position and related 
int ChoiceBoundary = 100; // The boundary at which a right-side choice is registered (in sensor units)
int NegativeChoiceBoundary = -100; // The boundary at which a left-side choice is registered (in sensor units)
int BallPosition = 0; // The current position of the trackball
int BallPositionRecord[1000] = {0}; // This array holds the record of trackball position (used with BallPositionTimes to reconstruct trajectory)
int RecordIndex = 0; // The index of the current position/time measurement
int LastPos = 0; // The previous trackball position (used to detect whether the trackball has moved)
int TrialPhase = 0; // This is the current trial phase. 0 = not in trial, 1 = waiting for ball idle, 2 = waiting for threshold crossing.

// Declare global variables used for serial USB communication
byte CommandByte = 0; // This variable stores an operation code. Three operations can be called: Handshake, Program variables and Run trial.
int inByte = 0; int inByte2 = 0; // These store incoming data from the USB serial port.

// I/O lines
int BallIdleLEDLine = 18; // Connect an LED to line 18, to indicate to the animal that it must stop moving the trackball.
int BinaryReportReadyLine = 19; // This line indicates whether a trial outcome code is ready to be read on the binary report lines. Used for interfacing with a real-time behavior system.
int BinaryReportLine1 = 20; // This is line 1 of 2. The outcome of a choice is displayed on these lines in binary. Right = 01 Left = 10 Timeout = 11
int BinaryReportLine2 = 21; // This is line 2 of 2.

void setup()
{
  Serial.begin( 115200 ); // Initialize the USB serial connection with the PC at 115200 baud
  pinMode(BinaryReportReadyLine, OUTPUT); // Set I/O line to logic output mode
  pinMode(BinaryReportLine1, OUTPUT); // Set I/O line to logic output mode
  pinMode(BinaryReportLine2, OUTPUT); // Set I/O line to logic output mode
  pinMode(BallIdleLEDLine, OUTPUT); // Set I/O line to logic output mode
  if (Usb.Init() == -1) { // Try to initialize the USB host
      Serial.println("OSC did not start."); // Dump error message over serial if error
  }
  delay(200); // Wait for the USB host
  if (!Hid.SetReportParser(0, &Joy)) { // Try to set the human interface device report parser
      ErrorMessage<uint8_t>(PSTR("SetReportParser"), 1  ); // Dump error message over serial if error
  }
}

void loop()
{
   if (Serial.available() > 0) { // If bytes are available to be read in the USB Serial port buffer
    CommandByte = Serial.read(); // Read one byte (the operation code)
    switch (CommandByte) { // Determine which op code was read
      case 60: Serial.print(5); break; // If the op code was char(60), this is a handshake. Return handshake with char(5).
      case 61: { // If the op code was char(61), the following bytes are trackball task variables to set.
        while (Serial.available() == 0) {} // Make sure a byte is available in the buffer
        inByte = Serial.read(); // Read the first byte of the choice boundary. Since the boundary can be >256, it is sent as a 2-byte "word" Arduino data type (uint16 in MATLAB)
        while (Serial.available() == 0) {} // Make sure a byte is available in the buffer
        inByte2 = Serial.read(); // Read the second byte of the choice boundary
        ChoiceBoundary = (int)word(inByte2, inByte); // Reconstruct the choice boundary, and cast it to the int datatype
        NegativeChoiceBoundary = ChoiceBoundary*-1; // Set the left-hand choice boundary at the same distance as right (broken out separately for easy hacking if they need to be different)
        while (Serial.available() == 0) {} // Make sure a byte is available in the buffer
        inByte = Serial.read();
        while (Serial.available() == 0) {} // Make sure a byte is available in the buffer
        inByte2 = Serial.read();
        Timeout = (unsigned long)word(inByte2, inByte); // Read the decision timeout interval
        Timeout = Timeout*1000; // Convert from ms to us.
        while (Serial.available() == 0) {} // Make sure a byte is available in the buffer
        inByte = Serial.read();
        while (Serial.available() == 0) {} // Make sure a byte is available in the buffer
        inByte2 = Serial.read();
        BallIdlePeriod = (unsigned long)word(inByte2, inByte); // Read the trackball idle interval (used at the beginning of each trial to ensure trackball is not in motion)
        BallIdlePeriod = BallIdlePeriod*1000; // Convert from ms to us.
        Serial.write(1); // Send acknowledgement byte
      } break;
      case 62: { // If the op code was char(62), start a new trial.
        Usb.Task(); // Run the USB polling script
        delay(1); // Wait for 1 ms
        StartTime = micros(); // Log the start-time of the ball idle period
        BallPosition = 0; // Zero the trackball position
        RecordIndex = 0; // Set the number of position measurements taken to 0
        LastPos = 0; // Set the last position recorded to 0
        digitalWrite(BallIdleLEDLine, HIGH); // Light the "Idle Period" LED to indicate to the animal that it must stop moving the ball
        TrialPhase = 1; // Proceed to trial phase 1: Ball Idle.
      } break;
     }
   }
  if (TrialPhase == 1) { // If the current trial phase is Ball Idle
    Usb.Task(); // Run the USB polling script
    CurrentTime = micros(); // Log the current time
    if (BallPosition != 0) { // If the ball position has moved from 0
      StartTime = CurrentTime; // Reset the Idle start timer to the current time
      BallPosition = 0; // Zero the ball position
    }
    ElapsedTime = CurrentTime - StartTime; // Calculate the time elapsed between the beginning of the idle period and the current time
    if (ElapsedTime > BallIdlePeriod) { // If the elapsed time exceeds the idle period
      TrialPhase = 2; // Proceed to trial phase 2: Wait for threshold crossing
      digitalWrite(BallIdleLEDLine, LOW); // Extinguish the "Idle Period" LED
      StartTime = micros(); // Log the start-time of the choice period
    }
  }    
  else if (TrialPhase == 2) { // If the current trial phase is "Wait for Threshold Crossing"
    Usb.Task(); // Run the USB polling script
    CurrentTime = micros(); // Log the current time
    ElapsedTime = CurrentTime - StartTime; // Calculate the time elapsed between the beginning of the idle period and the current time
    if (BallPosition != LastPos) { // If the ball has moved from its last position (BallPosition is global and is updated in a callback called by the USB polling script, hidjoystickparser.cpp)
        RecordIndex++; // Increment the index of the current position/time measurement
        BallPositionRecord[RecordIndex] = BallPosition; // Log the ball position at the new index.
        BallPositionTimes[RecordIndex] = ElapsedTime; // Log the current time at the new index.
        LastPos = BallPosition; // Update the record of the last ball position measured
        if ((BallPosition > ChoiceBoundary) || (BallPosition < NegativeChoiceBoundary)) { // If a choice boundary (left or right) has been crossed
          Serial.write(5); // Send a message header to indicate that a valid message follows
          Serial.write(RecordIndex); // Send the number of time/position measurements stored
          for (int x = 0; x <= RecordIndex; x++) { // For each position measurement
            Serial.println(BallPositionRecord[x]); // Send the measurement
          }
          for (int x = 0; x <= RecordIndex; x++) { // For each time measurement
            Serial.println(BallPositionTimes[x]); // Send the measurement
          }
          if (BallPositionRecord[RecordIndex] > 0) // If the last position measurement was greater than 0 (and since a threshold was crossed)
          {
            digitalWrite(BinaryReportLine1, HIGH); // The subject chose "Right" - logic 01. Make line 1 high
            digitalWrite(BinaryReportLine2, LOW); // Make line 2 low.
          } else {
            digitalWrite(BinaryReportLine1, LOW); // The subject choise "Left" - logic 10. Make line 1 low
            digitalWrite(BinaryReportLine2, HIGH); // Make line 2 high.
          }
          digitalWrite(BinaryReportReadyLine, HIGH); // Drive the binary report ready line high - indicating that the two report lines are ready to be read by a behavior system.
          delay(1); // Wait 1ms for the behavior system to read the lines
          digitalWrite(BinaryReportReadyLine, LOW); // Reset all lines Low
          digitalWrite(BinaryReportLine1, LOW);
          digitalWrite(BinaryReportLine2, LOW);
          BallPosition = 0; // Reset ball position
          RecordIndex = 0; // Reset index
          LastPos = 0; // Reset last position measured
          TrialPhase = 0; // Reset trial phase indicator
        }
        if (ElapsedTime > Timeout) { // If no decision was made and the decision timeout period has elapsed
              Serial.write(5); // Send a message header to indicate that a valid message follows.
              Serial.write(RecordIndex); // Send the number of time/position measurements stored
              for (int x = 0; x <= RecordIndex; x++) { // For each position measurement
                Serial.println(BallPositionRecord[x]); // Send the measurement
              }
              for (int x = 0; x <= RecordIndex; x++) {  // For each time measurement
                Serial.println(BallPositionTimes[x]); // Send the measurement
              }
              digitalWrite(BinaryReportLine1, HIGH); // The subject timed out - logic 11. Make line 1 high
              digitalWrite(BinaryReportLine2, HIGH); // Make line 2 high.
              digitalWrite(BinaryReportReadyLine, HIGH); // Drive the binary report ready line high - indicating that the two report lines are ready to be read by a behavior system.
              delay(1); // Wait 1ms for the behavior system to read the lines
              digitalWrite(BinaryReportReadyLine, LOW);
              digitalWrite(BinaryReportLine1, LOW);
              digitalWrite(BinaryReportLine2, LOW);
              BallPosition = 0;
              RecordIndex = 0;
              LastPos = 0;
              TrialPhase = 0;
        }
    }
  }
}

