// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// C stubs for "aac" library
// These obey the C compiler calling convention (see documentation)
// Comments show the syntax to call the routine also see matching header file

#include "aac_library.h"

#ifdef BUILD_WITH_C_SUPPORT

.MODULE $M.aac_c_stubs;
   .CODESEGMENT AAC_C_STUBS_PM;

// aac_frame_decode(int *decoder_struc_pointer);
$_aacdec_frame_decode:
   pushm <r4, r5, r6, r7, r9, r10, rLink>;
   pushm <I0, I1, I4, I5, I6, I7, M0, M1, M2, M3, L0, L1, L4, L5>;
   r8 = r0;
   call $aacdec.frame_decode;
   popm <I0, I1, I4, I5, I6, I7, M0, M1, M2, M3, L0, L1, L4, L5>;
   popm <r4, r5, r6, r7, r9, r10, rLink>;
   rts;

.ENDMODULE;

#endif
