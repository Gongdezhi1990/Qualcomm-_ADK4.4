// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_read_qdiv_tables
//
// DESCRIPTION:
//
//
// INPUTS:
//    - r3 - column number
//    - r4 - row number
//    if tables are in flash ($AACDEC_SBR_Q_DIV_TABLE_IN_FLASH defined) then:
//       - r8 - 9
//       - M3 - address of page mapped onto dm from flash
//
// OUTPUTS:
//    - r0 = value from table
//    - r1 = 1.0 - r0
//
// TRASHED REGISTERS:
//    - none
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_read_qdiv_tables;
   .CODESEGMENT AACDEC_SBR_READ_QDIV_TABLES_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_read_qdiv_tables:

   #ifdef AACDEC_SBR_Q_DIV_TABLE_IN_FLASH
      r0 = r4 * $aacdec.SBR_Q_DIV_TABLES_ROW_LENGTH (int);
      r0 = r0 + M3;
      r0 = M[r0 + r3];
      if NEG r0 = r0 LSHIFT r8;
      r1 = ((1<<23)-1) - r0;
   #else
      r1 = M[&$aacdec.sbr_q_div_tab_tables + r4];
      r1 = M[r1 + r3];
      r0 = ((1<<23)-1) - r1;
   #endif

   rts;

.ENDMODULE;

#endif
