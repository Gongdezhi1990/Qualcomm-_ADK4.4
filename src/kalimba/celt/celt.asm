// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_INCLUDED
#define CELT_INCLUDED

#include "celt.h"

// *****************************************************************************
// MODULE:
//    $celt
//
// DESCRIPTION:
//   constants and look up tables used by encoder and decoders routines
// *****************************************************************************
.MODULE $celt;
   .CODESEGMENT CELT_PM;
   .DATASEGMENT DM;

   // -- Transient windows for short blocks 
   .VAR transientWindow[16] =
      0.0085135,  0.0337639,  0.0748914,  0.1304955, 
      0.1986827,  0.2771308,  0.3631685,  0.4538658,
      0.5461342,  0.6368315,  0.7228692,  0.8013173, 
      0.8695045,  0.9251086,  0.9662361,  0.9914865;
                    
   .VAR inv_transientWindow[16] =               
      0.943757258083163, 0.808834216728584, 0.656064747817240, 0.522611163967424,
      0.418273726608512, 0.340145819152087, 0.282312062389837, 0.239402799183713,
      0.207342435196262, 0.183223321470539, 0.165014203432546, 0.151303759530756,
      0.141112757348218, 0.133765660380599, 0.128805349574692, 0.125938152654798;
   // -- List of supported flag combinations
   .VAR flaglist[8] = 
      0  /*00  */ | $celt.FLAG_FOLD,
      1  /*01  */ | $celt.FLAG_PITCH|$celt.FLAG_FOLD,
      8  /*1000*/ | $celt.FLAG_NONE,
      9  /*1001*/ | $celt.FLAG_SHORT|$celt.FLAG_FOLD,
      10 /*1010*/ | $celt.FLAG_PITCH,
      11 /*1011*/ | $celt.FLAG_INTRA,
      6  /*110 */ | $celt.FLAG_INTRA|$celt.FLAG_FOLD,
      7  /*111 */ | $celt.FLAG_INTRA|$celt.FLAG_SHORT|$celt.FLAG_FOLD;
      
   // -- Used in Coarse energy computation 
   .VAR eMeans[25] = 7.5/128, -1.33/128, -2.0/128, -0.42/128, 0.17/128,0 ...;
   
    // -- Tables used in entropy encoding/decoding search
   .VAR maxN[15] = 32767, 32767, 32767, 1476, 283, 109,  60,  40,
                   29,    24,    20,    18,    16,  14,  13;
   .VAR maxK[15] =  32767, 32767, 32767, 32767, 1172, 238,  95,  53,
                    36,    27,    22,    18,    16,   15,   13;  
.ENDMODULE;
#endif
