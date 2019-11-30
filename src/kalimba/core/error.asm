// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef ERROR_INCLUDED
#define ERROR_INCLUDED

// *****************************************************************************
// MODULE:
//    $error.error
//
// DESCRIPTION:
//    Error handler for the Kalimba DSP.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    none
//
// NOTES
//    It's very simple at the moment!  Once in $error you can look at rLink to
// see where the error came from.
//
// *****************************************************************************
.MODULE $M.error;
   .CODESEGMENT ERROR_PM;
   .DATASEGMENT DM;

#define INCLUDE_EXTERNAL_HANDLER
#ifdef INCLUDE_EXTERNAL_HANDLER
   .VAR $error.handler = 0;
#endif

   $error:
   rFlags = rFlags AND $NOT_UM_FLAG;   // block interrupts quickly by coming
                                       // out of user mode
#ifdef INCLUDE_EXTERNAL_HANDLER
   // is there a handler
   r9 = M[$error.handler];
   if NZ jump r9;
#endif

   error_loop:
      // if xIDE is attached let it hit a breakpoint so that
      // the user knows we've gone into error
      break;
   jump error_loop;
.ENDMODULE;

#endif
