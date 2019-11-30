// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.ps_map_34_parameters_to_20
//
// DESCRIPTION:
//    -
//
// INPUTS:
//    - r4  envelope number
//    - r0  &$aacdec.ps_info + {$aacdec.PS_IID_INDEX||$aacdec.PS_ICC_INDEX}
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - toupdate
//
// *****************************************************************************
.MODULE $M.aacdec.ps_map_34_parameters_to_20;
   .CODESEGMENT AACDEC_PS_MAP_34_PARAMETERS_TO_20_PM;
   .DATASEGMENT DM;



   $aacdec.ps_map_34_parameters_to_20:


   r1 = r4 * $aacdec.PS_MAX_NUM_PARAMETERS (int);
   r0 = r0 + r1;

   // PS_{IID||ICC}_INDEX[env][par_band=0] = floor( ( 2*PS_{IID||ICC}_INDEX[env][par_band=0] + PS_{IID||ICC}_INDEX[env][par_band=1] ) / 3 )
   r1 = M[r0 + 0];
   r1 = r1 * 2 (int);
   r2 = M[r0 + 1];
   r1 = r1 + r2;
   r1 = r1 * (2.0 / 3.0) (frac);
   r1 = r1 ASHIFT -1;
   M[r0 + 0] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=1] = floor( ( 2*PS_{IID||ICC}_INDEX[env][par_band=2] + PS_{IID||ICC}_INDEX[env][par_band=1] ) / 3 )
   r1 = M[r0 + 2];
   r1 = r1 * 2 (int);
   r2 = M[r0 + 1];
   r1 = r1 + r2;
   r1 = r1 * (2.0 / 3.0) (frac);
   r1 = r1 ASHIFT -1;
   M[r0 + 1] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=2] = floor( ( 2*PS_{IID||ICC}_INDEX[env][par_band=3] + PS_{IID||ICC}_INDEX[env][par_band=4] ) / 3 )
   r1 = M[r0 + 3];
   r1 = r1 * 2 (int);
   r2 = M[r0 + 4];
   r1 = r1 + r2;
   r1 = r1 * (2.0 / 3.0) (frac);
   r1 = r1 ASHIFT -1;
   M[r0 + 2] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=3] = floor( ( 2*PS_{IID||ICC}_INDEX[env][par_band=5] + PS_{IID||ICC}_INDEX[env][par_band=4] ) / 3 )
   r1 = M[r0 + 5];
   r1 = r1 * 2 (int);
   r2 = M[r0 + 4];
   r1 = r1 + r2;
   r1 = r1 * (2.0 / 3.0) (frac);
   r1 = r1 ASHIFT -1;
   M[r0 + 3] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=4] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=6] + PS_{IID||ICC}_INDEX[env][par_band=7] ) / 2 )
   r1 = M[r0 + 6];
   r2 = M[r0 + 7];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 4] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=5] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=8] + PS_{IID||ICC}_INDEX[env][par_band=9] ) / 2 )
   r1 = M[r0 + 8];
   r2 = M[r0 + 9];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 5] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=6] =  PS_{IID||ICC}_INDEX[env][par_band=10]
   r1 = M[r0 + 10];
   M[r0 + 6] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=7] =  PS_{IID||ICC}_INDEX[env][par_band=11]
   r1 = M[r0 + 11];
   M[r0 + 7] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=8] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=12] + PS_{IID||ICC}_INDEX[env][par_band=13] ) / 2 )
   r1 = M[r0 + 12];
   r2 = M[r0 + 13];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 8] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=9] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=14] + PS_{IID||ICC}_INDEX[env][par_band=15] ) / 2 )
   r1 = M[r0 + 14];
   r2 = M[r0 + 15];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 9] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=10] =  PS_{IID||ICC}_INDEX[env][par_band=16]
   r1 = M[r0 + 16];
   M[r0 + 10] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=11] =  PS_{IID||ICC}_INDEX[env][par_band=17]
   r1 = M[r0 + 17];
   M[r0 + 11] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=12] =  PS_{IID||ICC}_INDEX[env][par_band=18]
   r1 = M[r0 + 18];
   M[r0 + 12] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=13] =  PS_{IID||ICC}_INDEX[env][par_band=19]
   r1 = M[r0 + 19];
   M[r0 + 13] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=14] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=20] + PS_{IID||ICC}_INDEX[env][par_band=21] ) / 2 )
   r1 = M[r0 + 20];
   r2 = M[r0 + 21];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 14] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=15] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=22] + PS_{IID||ICC}_INDEX[env][par_band=23] ) / 2 )
   r1 = M[r0 + 22];
   r2 = M[r0 + 23];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 15] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=16] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=24] + PS_{IID||ICC}_INDEX[env][par_band=25] ) / 2 )
   r1 = M[r0 + 24];
   r2 = M[r0 + 25];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 16] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=17] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=26] + PS_{IID||ICC}_INDEX[env][par_band=27] ) / 2 )
   r1 = M[r0 + 26];
   r2 = M[r0 + 27];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 17] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=18] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=28] + PS_{IID||ICC}_INDEX[env][par_band=29] + ...
                                                                              // ... PS_{IID||ICC}_INDEX[env][par_band=30] + PS_{IID||ICC}_INDEX[env][par_band=31] ) / 4 )
   r1 = M[r0 + 28];
   r2 = M[r0 + 29];
   r1 = r1 + r2;
   r2 = M[r0 + 30];
   r3 = M[r0 + 31];
   r2 = r2 + r3;
   r1 = r1 + r2;
   r1 = r1 ASHIFT -2;
   M[r0 + 18] = r1;

   // PS_{IID||ICC}_INDEX[env][par_band=19] = floor( ( PS_{IID||ICC}_INDEX[env][par_band=32] + PS_{IID||ICC}_INDEX[env][par_band=33] ) / 2 )
   r1 = M[r0 + 32];
   r2 = M[r0 + 33];
   r1 = r1 + r2;
   r1 = r1 ASHIFT -1;
   M[r0 + 19] = r1;




   rts;




.ENDMODULE;

#endif
