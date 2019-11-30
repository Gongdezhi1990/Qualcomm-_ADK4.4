// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


#ifndef FWRANDOM_HEADER_INCLUDED
#define FWRANDOM_HEADER_INCLUDED

#include "fwrandom_defines.h"

   #ifdef DEBUG_ON
      #define FWRANDOM_DEBUG_ON
   #endif

   // structure fields
   .CONST   $fwrandom.NEXT_ENTRY_FIELD           0;
   .CONST   $fwrandom.NUM_REQ_FIELD              1;
   .CONST   $fwrandom.NUM_RESP_FIELD             2;
   .CONST   $fwrandom.RESP_BUF_FIELD             3;
   .CONST   $fwrandom.HANDLER_ADDR_FIELD         4;
   .CONST   $fwrandom.STRUC_SIZE                 5;

   // set the maximum possible number of handlers - this is only used to detect
   // corruption in the linked list, and so can be quite large
   .CONST   $fwrandom.MAX_HANDLERS               50;

   .CONST   $fwrandom.LAST_ENTRY                 -1;
   .CONST   $fwrandom.REATTEMPT_TIME_PERIOD      10000;
   .CONST   $fwrandom.MAX_RAND_BITS              512;

   .CONST   $fwrandom.FAILED_READ_LENGTH         FWRANDOM_FAILED_READ_LENGTH;

   .CONST   $fwrandom.READ_FAILED                FWRANDOM_READ_FAILED;
   .CONST   $fwrandom.READ_SUCCEEDED             FWRANDOM_READ_SUCCEEDED;

#endif

