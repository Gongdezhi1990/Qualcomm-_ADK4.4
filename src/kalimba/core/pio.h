// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


#ifndef PIO_HEADER_INCLUDED
#define PIO_HEADER_INCLUDED

   #ifdef DEBUG_ON
      #define PIO_DEBUG_ON
   #endif

   // pio event handler structure fields
   .CONST   $pio.NEXT_ADDR_FIELD            0;
   .CONST   $pio.PIO_BITMASK_FIELD          1;
   .CONST   $pio.PIO2_BITMASK_FIELD         2;
   .CONST   $pio.PIO3_BITMASK_FIELD         3;
   .CONST   $pio.HANDLER_ADDR_FIELD         4;
   .CONST   $pio.STRUC_SIZE                 5;

   // set the maximum possible number of handlers - this is only used to detect
   // corruption in the linked list, and so can be quite large
   .CONST   $pio.MAX_HANDLERS               20;

   .CONST   $pio.LAST_ENTRY                 -1;

#endif

