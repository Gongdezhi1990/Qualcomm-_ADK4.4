// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_q_div_table_flash
//
// DESCRIPTION:
//    - Packed up q_div table that will go into flash
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
// *****************************************************************************

// If entry fits into 15 bits then it is stored as is
// Otherwise it is shifted down by 9 bits and the MSB (bit 16 in flash) is set
// eg  0x002468   ->   0x2468
//     0x2468ac   ->   0x1234 + 0x8000 = 0x9234
//
// To extract correct value:
//    read word from flash
//    if it is negative (ie MSB set) LOGICAL shift left 9 bits



.BLOCK/DMCONST_WINDOWED16 sbr_q_div_table_rows;

   .VAR sbr_q_div_tab_row_1[] =
      0x81F0, 0x80FC, 0x807F, 0x7F79, 0x3FDC, 0x1FF6, 0x0FFD, 0x07FF, 0x0400, 0x0200, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000;

   .VAR sbr_q_div_tab_row_2[] =
      0x871B, 0x83C3, 0x81F0, 0x80FC, 0x807F, 0x7F61, 0x3FD0, 0x1FF0, 0x0FFA, 0x07FE, 0x03FF, 0x01FF, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000;

   .VAR sbr_q_div_tab_row_3[] =
      0x9547, 0x8CC3, 0x8716, 0x83C0, 0x81EF, 0x80FB, 0x807F, 0x7F02, 0x3FA1, 0x1FD8, 0x0FEE, 0x07F8, 0x03FC, 0x01FE, 0x00FF, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000;

   .VAR sbr_q_div_tab_row_4[] =
      0xAA72, 0x9FC0, 0x951D, 0x8CA4, 0x8704, 0x83B6, 0x81E9, 0x80F8, 0x807D, 0x7D8C, 0x3EE5, 0x1F7A, 0x0FBF, 0x07E0, 0x03F0, 0x01F8, 0x00FC, 0x007E, 0x003F, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000;

   .VAR sbr_q_div_tab_row_5[] =
      0xB87F, 0xB291, 0xA9CC, 0x9F08, 0x947B, 0x8C31, 0x86BD, 0x838E, 0x81D4, 0x80ED, 0x8078, 0x7807, 0x3C20, 0x1E17, 0x0F0D, 0x0787, 0x03C4, 0x01E2, 0x00F1, 0x0078, 0x003C, 0x001E, 0x000F, 0x0008, 0x0004, 0x0002, 0x0001, 0x0000, 0x0000, 0x0000, 0x0000;

   .VAR sbr_q_div_tab_row_6[] =
      0xBD98, 0xBB5D, 0xB75A, 0xB0C3, 0xA762, 0x9C72, 0x9249, 0x8AAB, 0x85D1, 0x830C, 0x8190, 0x80CA, 0x8066, 0x6615, 0x331F, 0x1994, 0x0CCC, 0x0666, 0x0333, 0x019A, 0x00CD, 0x0066, 0x0033, 0x001A, 0x000D, 0x0006, 0x0003, 0x0002, 0x0001, 0x0000, 0x0000;

   .VAR sbr_q_div_tab_row_7[] =
      0xBF04, 0xBE10, 0xBC3C, 0xB8E4, 0xB333, 0xAAAB, 0xA000, 0x9555, 0x8CCD, 0x871C, 0x83C4, 0x81F0, 0x80FC, 0x807F, 0x7F80, 0x3FE0, 0x1FF8, 0x0FFE, 0x07FF, 0x0400, 0x0200, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001, 0x0000;

   .VAR sbr_q_div_tab_row_8[] =
      0xBF62, 0xBEC6, 0xBD98, 0xBB5D, 0xB75A, 0xB0C3, 0xA762, 0x9C72, 0x9249, 0x8AAB, 0x85D1, 0x830C, 0x8190, 0x80CA, 0x8066, 0x6615, 0x331F, 0x1994, 0x0CCC, 0x0666, 0x0333, 0x019A, 0x00CD, 0x0066, 0x0033, 0x001A, 0x000D, 0x0006, 0x0003, 0x0002, 0x0001;

   .VAR sbr_q_div_tab_row_9[] =
      0xBF79, 0xBEF4, 0xBDF1, 0xBC04, 0xB87F, 0xB291, 0xA9CC, 0x9F08, 0x947B, 0x8C31, 0x86BD, 0x838E, 0x81D4, 0x80ED, 0x8078, 0x7807, 0x3C20, 0x1E17, 0x0F0D, 0x0787, 0x03C4, 0x01E2, 0x00F1, 0x0078, 0x003C, 0x001E, 0x000F, 0x0008, 0x0004, 0x0002, 0x0001;

   .VAR sbr_q_div_tab_row_10[] =
      0xBF7F, 0xBF00, 0xBE08, 0xBC2E, 0xB8CA, 0xB30A, 0xAA72, 0x9FC0, 0x951D, 0x8CA4, 0x8704, 0x83B6, 0x81E9, 0x80F8, 0x807D, 0x7D8C, 0x3EE5, 0x1F7A, 0x0FBF, 0x07E0, 0x03F0, 0x01F8, 0x00FC, 0x007E, 0x003F, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001;

   .VAR sbr_q_div_tab_row_11[] =
      0xBF81, 0xBF03, 0xBE0E, 0xBC39, 0xB8DD, 0xB329, 0xAA9C, 0x9FF0, 0x9547, 0x8CC3, 0x8716, 0x83C0, 0x81EF, 0x80FB, 0x807F, 0x7F02, 0x3FA1, 0x1FD8, 0x0FEE, 0x07F8, 0x03FC, 0x01FE, 0x00FF, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001;

   .VAR sbr_q_div_tab_row_12[] =
      0xBF81, 0xBF04, 0xBE0F, 0xBC3B, 0xB8E2, 0xB331, 0xAAA7, 0x9FFC, 0x9552, 0x8CCA, 0x871B, 0x83C3, 0x81F0, 0x80FC, 0x807F, 0x7F61, 0x3FD0, 0x1FF0, 0x0FFA, 0x07FE, 0x03FF, 0x01FF, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001;

   .VAR sbr_q_div_tab_row_13[] =
      0xBF81, 0xBF04, 0xBE0F, 0xBC3C, 0xB8E3, 0xB333, 0xAAAA, 0x9FFF, 0x9554, 0x8CCC, 0x871C, 0x83C4, 0x81F0, 0x80FC, 0x807F, 0x7F79, 0x3FDC, 0x1FF6, 0x0FFD, 0x07FF, 0x0400, 0x0200, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001;

.ENDBLOCK;

#endif
