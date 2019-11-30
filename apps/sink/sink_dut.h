/****************************************************************************
Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.

FILE NAME
    sink_dut.h
    
DESCRIPTION
	Place the device into Device Under Test (DUT) mode
    
*/

#ifndef _SINK_DUT_H_
#define _SINK_DUT_H_


#include <csrtypes.h>
#include <message.h>
#include <connection_no_ble.h>

#include "sink_buttonmanager.h"


typedef enum
{
    dut_test_invalid,    
    dut_test_audio,
    dut_test_keys,
    dut_test_service,
    dut_test_tx,
    dut_test_dut
} dut_test_mode;

/****************************************************************************
DESCRIPTION
  	This function is called to place the device into DUT mode
*/
void enterDutMode(void);

/****************************************************************************
DESCRIPTION
  	This function is called to place the device into TX continuous test mode
*/

void enterTxContinuousTestMode ( void ) ;


/****************************************************************************
DESCRIPTION
    This function is called to attempt to put the device into DUT mode 
    depending on the state of the externally driven DUT PIO line. If the
    line is driven, DUT mode is enabled.
*/
bool enterDUTModeIfDUTPIOActive( void );

/****************************************************************************
DESCRIPTION
    This function is called to determine the state of the externally driven
    DUT PIO line.
*/
bool isDUTPIOActive( void );

/****************************************************************************
DESCRIPTION
  	Enter service mode - device changers local name and enters discoverable 
	mode
*/
void enterServiceMode( void ) ;
 
/****************************************************************************
DESCRIPTION
  	handle a local bdaddr request and continue to enter service mode
*/
void DutHandleLocalAddr(const CL_DM_LOCAL_BD_ADDR_CFM_T *cfm) ;



/************************************************************************* 
DESCRIPTION
    Perform the CVC production test routing and nothing else in the given
    boot mode
*/
void cvcProductionTestEnter ( void ) ;

/*************************************************************************
DESCRIPTION
    Handle the response from Kalimba to figure out if the CVC licence key exists    
*/
void cvcProductionTestKalimbaMessage ( Task task, MessageId id, Message message ) ;


/*************************************************************************
DESCRIPTION
    Enter an audio test mode to route mic to speaker
*/
void enterAudioTestMode(void);


/*************************************************************************
DESCRIPTION
    Enter a tone test mode to continuously repeat the tone specified
*/
void enterToneTestMode(void);


/*************************************************************************
DESCRIPTION
    Enter a key test mode to cycle through LED patterns based on pressing the configured keys (PIOs)
*/
void enterKeyTestMode(void);


/*************************************************************************
DESCRIPTION
    A configured key has been pressed, check if this is in key test mode
*/
void checkDUTKeyPress(uint32 lNewState);


/*************************************************************************
DESCRIPTION
    A configured key has been released, check if this is in key test mode
*/
void checkDUTKeyRelease(uint32 lNewState, ButtonsTime_t pTime);



/****************************************************************************
DESCRIPTION
    Gets the currently active DUT mode
*/
dut_test_mode getDUTMode(void);
/*************************************************************************
DESCRIPTION
    Initialise DUT mode
*/
void dutInit(void);

void dutDisconnect(void);

#endif /* _SINK_DUT_H_ */
