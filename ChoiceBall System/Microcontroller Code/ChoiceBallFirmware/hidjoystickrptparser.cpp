

#include "hidjoystickrptparser.h"

JoystickReportParser::JoystickReportParser(JoystickEvents *evt) : 
	joyEvents(evt),
	oldHat(0xDE),
	oldButtons(0)
{
	for (uint8_t i=0; i<RPT_GEMEPAD_LEN; i++)
		oldPad[i]	= 0xD; 
}

void JoystickReportParser::Parse(HID *hid, bool is_rpt_id, uint8_t len, uint8_t *buf)
{
	bool match = true;

	// Checking if there are changes in report since the method was last called
	for (uint8_t i=0; i<RPT_GEMEPAD_LEN; i++)
		if (buf[i] != oldPad[i])
		{
			match = false;
			break;
		}

	// Calling Game Pad event handler
	if (!match && joyEvents)
	{
		joyEvents->OnGamePadChanged((const GamePadEventData*)buf);

		for (uint8_t i=0; i<RPT_GEMEPAD_LEN; i++) oldPad[i] = buf[i];
	}
	
}

void JoystickEvents::OnGamePadChanged(const GamePadEventData *evt)
{
        extern int BallPosition;
        int BP = 0;
        BP = evt->Y;
        if (BP > 128) {BP = (256 - BP)*-1;}
        BallPosition = BallPosition + BP;
}

