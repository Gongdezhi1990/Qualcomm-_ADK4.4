// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_IMDCT_WINDOWING_OVERLAPADD_INCLUDED
#define MP3DEC_IMDCT_WINDOWING_OVERLAPADD_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.imdct_windowing_overlapadd
//
// DESCRIPTION:
//    IMDCT Windowing and Overlap add
//
// INPUTS:
//    r9 = pointer to table of external memory pointers
//    I0 = pointer to $mp3dec.arbuf_left/right
//    I1 = pointer to $mp3dec.oabuf_left/right
//    r1 = channel number (left = 0, right = 1)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    assume everything
//
// NOTES:
//   _________
//   __imdct__
//
//  In the following, n is the number of windowed samples (for short blocks
//  n=12 for long blocks n=36).  In the case of a block of type "short",
//  each of the three short blocks is transformed separately.
//  n/2 values X(k) are transformed to n values x(n).
//  The analytical expression of the IMDCT is:
//
/*               --
//                \
//          x(i) = \  X(k)*cos(pi/2n(2i+1+n/2)(2k+1))  for i=0 to n-1
//                 /
//                /
//                --
*/
//   _____________
//   __WINDOWING__
//
//  Depending on the block_type different shapes of windows are used
//
//    a) block_type = 0 (normal windows)
//
//        z(i) = x(i)*sin(pi/36(i + 0.5))     for i = 0 to 35
//
//
//    b) block_type = 1 (start block)
//
//               / x(i)*sin(pi/36(i + 0.5))        for i = 0 to 17
//        z(i) = | x(i)                            for i = 18 to 23
//               | x(i)*sin(pi/12(i - 18 + 0.5))   for i = 24 to 29
//               \ 0                               for i = 30 to 35
//
//
//    c) block_type = 3 (stop block)
//
//               / 0                               for i = 0 to 5
//               | x(i)*sin(pi/12(i - 6 + 0.5))    for i = 6 to 11
//        z(i) = | x(i)                            for i = 12 to 17
//               \ x(i)*sin(pi/36(i + 0.5))        for i = 18 to 35
//
//
//    d) block_type = 2 (short block)
//
//       Each of the three short bloxks is windowed separately
//
//       y(i,j) = x(i,j)*sin(pi/12(i + 0.5))    for i = 0 to 11, j = 0 to 2
//
//       The windowed short blocks must be overlapped and concatenated
//
//                / 0                              for i = 0 to 5
//               |  y(i-6, 1)                      for i = 6 to 11
//        z(i) =<   y(i-6, 1)  + y(i-12, 2)        for i = 12 to 17
//               |  y(i-12, 2) + y(i-18, 3)        for i = 18 to 23
//               |  y(i-18, 3)                     for i = 24 to 29
//                \ 0                              for i = 30 to 35
//
//   ______________________________________________
//   __OVERLAPPING and ADDING WITH PREVIOUS BLOCK__
//
//  The first half of the block of 36 values is overlapped with the second
//  half of the previous block. The second half of the actual block is
//  stored to be used in the next block:
//
//       result(i) = z(i) + s(i)   for i = 0 to 17
//       s(i) = z(i + 18)          for i = 0 to 17
//
//
//   _______________________
//   __IMPLEMENTATION HERE__
//
//  The IMDCT is implemented as a matrix multiplication.  For long blocks
//  the redundancy in the IMDCT matrix has halfed the computation.  For
//  short blocks the windowing has been combined with IMDCT and any
//  multiplies by zero optimised away.
//
//  For long windows (normal, start and stop blocks) windowing is done
//  separately from the IMDCT operation.  But for short blocks the IMDCT,
//  windowing, and concatination of the 3 short windows is combined
//
//
// *****************************************************************************
.MODULE $M.mp3dec.imdct_windowing_overlapadd;
   .CODESEGMENT MP3DEC_IMDCT_WINDOWING_OVERLAPADD_PM;
   .DATASEGMENT DM;

   $mp3dec.imdct_windowing_overlapadd:

   .VAR rzero_subbands;

   M3 = 17;
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
   I3 = r0;
#else
   I3 = &$mp3dec.genbuf;
#endif

   r0 = M[$mp3dec.current_grch];

   // 32 subbands to do
   r6 = $mp3dec.NUM_SUBBANDS;
   M[rzero_subbands] = Null;

   r0 = M[$mp3dec.block_type + r0];

   // see if mixed_flag set
   Null = r0 AND $mp3dec.MIXED_MASK;
   if Z jump blocktype_notmixed;
      I6 = (&$mp3dec.winfunc_normcoefs + 8);
      jump long_window;
   blocktype_notmixed:


   // see if short windows selected
   Null = r0 AND $mp3dec.SHORT_MASK;
   if Z jump blocktype_notshort;
      I6 = &$mp3dec.imdct_shortcoef;
      jump short_window;
   blocktype_notshort:

   // reduce the number sub-band based on rzero
   r2 = M[$mp3dec.rzerolength + r1];
   r3 = M[$mp3dec.rzerolength_previous + r1];
   Null = r2 - r3;
   if GT r2 = r3;
   r2 = r2 * 0.22222220897675 (frac);
   r2 = r2 ASHIFT -2;      // r2 = floor(r2 / 18)
   r2 = r2 - 1;            // one extra sub-band could have non-zero ...
   if NEG r2 = 0;          // ... values due to alias reduction.


   // default of normal window
   I6 = (&$mp3dec.winfunc_normcoefs + 8);

   // start block if needed
   Null = r0 AND $mp3dec.START_MASK;
   if Z jump imdct_notstartblock;
      I6 = (&$mp3dec.winfunc_startcoefs + 8);
   imdct_notstartblock:

   // end block if needed
   Null = r0 AND $mp3dec.END_MASK;
   if Z jump imdct_notendblock;
      I6 = (&$mp3dec.winfunc_endcoefs + 8);
      r2 = 0;
   imdct_notendblock:

   r6 = r6 - r2;
   if LE jump zero_subbands;
   M[rzero_subbands] = r2;



   // ----------------------------- Long window -------------------------------

   long_window:

   // Initial values:
   //    I0 = $mp3dec.arbuf[0];
   //    I1 = $mp3dec.oabuf[8]             point to start of row A/C
   I1 = I1 + 8;
   //    I2 = $mp3dec.oabuf[9]             point to start of row B/D
   I2 = I1 + 1;
   //    I3 = $mp3dec.genbuf[8]            point to start of row A/C
   I3 = I3 + 8;
   //    I4 = $mp3dec.genbuf[9]            point to start of row B/D
   I4 = I3 + 1;
   //    I5 = $mp3dec.imdct_longcoef[0]
   I5 = &$mp3dec.imdct_longcoef;
   //    I6 = $mp3dec.winfunc_coefs[8]     point to start of row A/C
   //    I7 = $mp3dec.winfunc_coefs[9]     point to start of row B/D
   I7 = I6 + 1;


   // Order of IMDCT Long Matrix calculation:
   //
   //             --        IMDCT Long Matrix        --
   //       A9   |  ............. row 0 .............  |
   //       A8   |  ............. row 1 .............  |
   //       A7   |  ............. row 2 .............  |
   //       A6   |  ............. row 3 .............  |
   //       A5   |  ............. row 4 .............  |
   //       A4   |  ............. row 5 .............  |
   //       A3   |  ............. row 6 .............  |
   //       A2   |  ............. row 7 .............  |
   //       A1   |  ............. row 8 .............  |
   //       B1   |  ............. row 9 .............  |
   //       B2   |  ............. row 10 ............  |
   //       B3   |  ............. row 11 ............  |
   //       B4   |  ............. row 12 ............  |
   //       B5   |  ............. row 13 ............  |
   //       B6   |  ............. row 14 ............  |
   //       B7   |  ............. row 15 ............  |
   //       B8   |  ............. row 16 ............  |
   //       B9   |  ............. row 17 ............  |
   //       D1   |  ............. row 18 ............  |
   //       D2   |  ............. row 19 ............  |
   //       D3   |  ............. row 20 ............  |
   //       D4   |  ............. row 21 ............  |
   //       D5   |  ............. row 22 ............  |
   //       D6   |  ............. row 23 ............  |
   //       D7   |  ............. row 24 ............  |
   //       D8   |  ............. row 25 ............  |
   //       D9   |  ............. row 26 ............  |
   //       C9   |  ............. row 27 ............  |
   //       C8   |  ............. row 28 ............  |
   //       C7   |  ............. row 29 ............  |
   //       C6   |  ............. row 30 ............  |
   //       C5   |  ............. row 31 ............  |
   //       C4   |  ............. row 32 ............  |
   //       C3   |  ............. row 33 ............  |
   //       C2   |  ............. row 34 ............  |
   //       C1   |  ............. row 35 ............  |
   //             --                                 --

   M0 = -17;
   M1 = 1;
   M2 = -1;
   r8 = 15;                    // pre-store 15 as it's used often below


   long_window_outer_loop:
      r0 = M[I0,1],               // get 1st Col alias reduction sample
       r1 = M[I5,1];              // get 1st Col IMDCT coef

      // -------------------- IMDCT Long   Loop 1 -------------------------------
      r10 = 0;
      r7 = 9;
      long_window_main_loop1:
         // -- Calculate rows A & B of the IMDCT Top Half--

         r10 = r10 + r8,             // setup loop counter
          r2 = M[I6,M2],             // get window function coef - row A
          r3 = M[I1,M2];             // get overlap-add sample - row A

         rMAC = r0 * r1,             // do first multiply
          r0 = M[I0,1],              // get 2nd Col alias reduction sample
          r1 = M[I5,1];              // get 2nd Col IMDCT coef

         do long_window_inner_loop1;
            rMAC = rMAC + r0 * r1,      // do 15 multiply-adds
             r0 = M[I0,1],              // get next Col alias reduction sample
             r1 = M[I5,1];              // get next Col IMDCT coef
         long_window_inner_loop1:

         rMAC = rMAC + r0 * r1,      // do 17th multiply-add
          r0 = M[I0,M0],             // get last Col alias reduction sample
          r1 = M[I5,M1];             // get last Col IMDCT coef

         rMAC = rMAC + r0 * r1,      // do last multiply-add
          r0 = M[I0,1],              // get 1st Col alias reduction sample again
          r1 = M[I5,1];              // get 1st Col, next row, of IMDCT coef

         r2 = r2 * rMAC (frac),      // apply window function - row A
          r4 = M[I2,1],              // get overlap-add sample - row B
          r5 = M[I7,1];              // get window function coef - row B

         r3 = r3 - r2;               // do overlap-add - row A

         r5 = r5 * rMAC (frac),      // apply window function - row B
          M[I3,-1] = r3;             // write new sample - row A

         r4 = r4 + r5;               // do overlap-add - row B

         r7 = r7 + M2,
          M[I4,1] = r4;              // write new sample - row B
      if NZ jump long_window_main_loop1;


      I1 = I1 + 1;                // update index registers for bottom half of
      I2 = I2 - 1;                // IMDCT matrix - ie. rows C & D
      I6 = I6 + 36;


      // -------------------- IMDCT Long   Loop 2 -------------------------------
      r7 = 9;
      long_window_main_loop2:
         // -- Calculate rows C & D of the IMDCT Bottom Half--

         r10 = r10 + r8,             // setup loop counter
          r2 = M[I6,M2];             // get window function coef - row C

         rMAC = r0 * r1,             // do first multiply
          r0 = M[I0,1],              // get 2nd Col alias reduction sample
          r1 = M[I5,1];              // get 2nd Col IMDCT coef

         do long_window_inner_loop2;
            rMAC = rMAC + r0 * r1,      // do the other 15 multiply-adds
             r0 = M[I0,1],              // get next Col alias reduction sample
             r1 = M[I5,1];              // get next Col IMDCT coef
         long_window_inner_loop2:

         rMAC = rMAC + r0 * r1,      // do 17th multiply-add
          r0 = M[I0,M0],             // get last Col alias reduction sample
          r1 = M[I5,M1];             // get last Col IMDCT coef

         rMAC = rMAC + r0 * r1,      // do last multiply-add
          r0 = M[I0,1],              // get 1st Col alias reduction sample again
          r1 = M[I5,1];              // get 1st Col, next row, of IMDCT coef

         r2 = r2 * rMAC (frac),      // apply window function - row C
          r5 = M[I7,1];              // get window function coef - row D

         r5 = r5 * rMAC (frac),      // apply window function - row D
          M[I2,-1] = r2;             // write new overlap-add sample - row C

         r7 = r7 + M2,
          M[I1,1] = r5;              // write new overlap-add sample - row D
      if NZ jump long_window_main_loop2;


      Null = r6 - 31;                // if mixedflag is set, deal with switching
      if NZ jump no_block_switch;    // to the appropriate block type after 2nd subband
         r0 = M[$mp3dec.current_grch];
         r0 = M[$mp3dec.block_type + r0];
         Null = r0 AND $mp3dec.MIXED_MASK;
         if Z jump no_block_switch;

         Null = r0 AND $mp3dec.SHORT_MASK;
         if NZ jump mixed_short_window;

         I6 = (&$mp3dec.winfunc_startcoefs + 26);   // Start block
         I7 = I6 + 1;

         Null = r0 AND $mp3dec.START_MASK;
         if NZ jump no_block_switch;

         I6 = (&$mp3dec.winfunc_endcoefs + 26);     // End block
         I7 = I6 + 1;
      no_block_switch:

      I1 = I1 + 17;               // tweak pointers for next time around loop
      r0 = M[I0, M3];             // dummy read, M3 = 17
      I2 = I2 + 19;
      I3 = I3 + 27;
      I4 = I4 + 9;
      I5 = I5 - 325;
      I6 = I6 - 18;
      I7 = I7 - 18;
      r6 = r6 - 1;                // decrement number of subbands to process
   if NZ jump long_window_outer_loop;

   // start zeroing the rzero region
   r2 = M[rzero_subbands];
   I3 = I3 - 8;           // start zeroing genbuf from here
   I1 = I1 - 8;           // start zeroing oabuf from here
   zero_subbands:
   r10 = r2 * 18 (int);
   I4 = I3;
   r0 = 0;
   do zero_the_rest_loop;
      M[I1, 1] = r0,
       M[I4, 1] = r0;
   zero_the_rest_loop:

   rts;



   mixed_short_window:
   r0 = M[I0, M3];                // dummy read, M3 = 17
   I1 = I1 + 9;
   I3 = I3 + 19;
   r6 = r6 - 1;
   I6 = &$mp3dec.imdct_shortcoef; // Short block


   // ----------------------------- Short window -------------------------------

   short_window:

   M3 = 5;

   // Initial values:
   //    I0 = $mp3dec.ar_buf[0];
   //    I1 = $mp3dec.oa_buf[0];
   //    I3 = $mp3dec.genbuf[0];
   //    I6 = $mp3dec.imdct_shortcoef[0];
   //    I7 = $mp3dec.imdct_shortcoef[0];
   I7 = I6;

   // Order of IMDCT Short Matrix calculation:
   //
   //        --                            IMDCT Short Matrix                       --
   // Loop1 |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   // Loop2 | A1  A2  A3  A4  A5  A6   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   | B1  B2  B3  B4  B5  B6   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   | C1  C2  C3  C4  C5  C6   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   | D1  D2  D3  D4  D5  D6   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   | E1  E2  E3  E4  E5  E6   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   | F1  F2  F3  F4  F5  F6   0   0   0   0   0   0   0   0   0   0   0   0  |
   // Loop3 | G1  G2  G3  G4  G5  G6  A1  A2  A3  A4  A5  A6   0   0   0   0   0   0  |
   //   "   | H1  H2  H3  H4  H5  H6  B1  B2  B3  B4  B5  B6   0   0   0   0   0   0  |
   //   "   | I1  I2  I3  I4  I5  I6  C1  C2  C3  C4  C5  C6   0   0   0   0   0   0  |
   //   "   | J1  J2  J3  J4  J5  J6  D1  D2  D3  D4  D5  D6   0   0   0   0   0   0  |
   //   "   | K1  K2  K3  K4  K5  K6  E1  E2  E3  E4  E5  E6   0   0   0   0   0   0  |
   //   "   | L1  L2  L3  L4  L5  L6  F1  F2  F3  F4  F5  F6   0   0   0   0   0   0  |
   // Loop4 |  0   0   0   0   0   0  G1  G2  G3  G4  G5  G6  A1  A2  A3  A4  A5  A6  |
   //   "   |  0   0   0   0   0   0  H1  H2  H3  H4  H5  H6  B1  B2  B3  B4  B5  B6  |
   //   "   |  0   0   0   0   0   0  I1  I2  I3  I4  I5  I6  C1  C2  C3  C4  C5  C6  |
   //   "   |  0   0   0   0   0   0  J1  J2  J3  J4  J5  J6  D1  D2  D3  D4  D5  D6  |
   //   "   |  0   0   0   0   0   0  K1  K2  K3  K4  K5  K6  E1  E2  E3  E4  E5  E6  |
   //   "   |  0   0   0   0   0   0  L1  L2  L3  L4  L5  L6  F1  F2  F3  F4  F5  F6  |
   // Loop5 |  0   0   0   0   0   0   0   0   0   0   0   0  G1  G2  G3  G4  G5  G6  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0  H1  H2  H3  H4  H5  H6  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0  I1  I2  I3  I4  I5  I6  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0  J1  J2  J3  J4  J5  J6  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0  K1  K2  K3  K4  K5  K6  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0  L1  L2  L3  L4  L5  L6  |
   // Loop6 |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //   "   |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
   //        --                                                                     --
   M0 = -5;
   M1 = 1;
   r2 = 6;
   r10 = r2;
   M2 = -11;

   short_window_outer_loop:

      // -------------------- IMDCT Short   Loop 1 -------------------------------
      do short_window_loop1;
         r3 = M[I1,1];            // copy across the first 6 samples from the
         M[I3,1] = r3;            // oa_Buf to the genbuf
      short_window_loop1:


      // -------------------- IMDCT Short   Loop 2 -------------------------------
      r10 = 6;

      r0 = M[I0,1],               // get 1st Col alias reduction sample
       r1 = M[I6,1];              // get 1st Col IMDCT coef

      do short_window_loop2;
         rMAC = r0 * r1,             // do first multiply
          r0 = M[I0,1],              // get 2nd Col alias reduction sample
          r1 = M[I6,1];              // get 2nd Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 3rd Col alias reduction sample
          r1 = M[I6,1];              // get 3rd Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 4th Col alias reduction sample
          r1 = M[I6,1];              // get 4th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 5th Col alias reduction sample
          r1 = M[I6,1];              // get 5th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],             // get 6th Col alias reduction sample
          r1 = M[I6,M1];             // get 6th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r3 = M[I1,1],              // get oa_Buf sample
          r1 = M[I6,1];              // get 1st Col, next row, of IMDCT coef

         r3 = r3 + rMAC,             // do overlap add
          r0 = M[I0,1];              // get 1st Col alias reduction sample again
         M[I3,1] = r3;               // write new sample to genbuf
      short_window_loop2:



      // -------------------- IMDCT Short   Loop 3 -------------------------------
      r10 = 6;
      do short_window_loop3;
         rMAC = r0 * r1,             // do first multiply
          r0 = M[I0,1],              // get 2nd Col alias reduction sample
          r1 = M[I6,1];              // get 2nd Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 3rd Col alias reduction sample
          r1 = M[I6,1];              // get 3rd Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 4th Col alias reduction sample
          r1 = M[I6,1];              // get 4th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 5th Col alias reduction sample
          r1 = M[I6,1];              // get 5th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 6th Col alias reduction sample
          r1 = M[I6,1];              // get 6th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 7th Col alias reduction sample
          r1 = M[I7,1];              // get 1st Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 8th Col alias reduction sample
          r1 = M[I7,1];              // get 2nd Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 9th Col alias reduction sample
          r1 = M[I7,1];              // get 3rd Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 10th Col alias reduction sample
          r1 = M[I7,1];              // get 4th Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 11th Col alias reduction sample
          r1 = M[I7,1];              // get 5th Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M2],             // get 12th Col alias reduction sample
          r1 = M[I7,M1];             // get 6th Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r3 = M[I1,1],              // get oa_Buf sample
          r1 = M[I6,1];              // get 1st Col, row - 6, of IMDCT coef

         r3 = r3 + rMAC,             // do overlap add
          r0 = M[I0,1];              // get 1st Col alias reduction sample
         M[I3,1] = r3;               // write new sample to genbuf
      short_window_loop3:


      // -------------------- IMDCT Short   Loop 4 -------------------------------
      r10 = r2,                   // r2 = 6
       r0 = M[I0, M3];            // set ar_Buf pointer to 7th col (dummy read, M3 = 5)
      I6 = I6 - 73;               // move to start of IMDCT coefs
      r0 = M[I0,1],               // get 7th Col alias reduction sample
       r1 = M[I7,1];              // get IMDCT coef


      I1 = I1 - 18;               // set oa_Buf pointer to start of subband

      do short_window_loop4;
         rMAC = r0 * r1,             // do first multiply
          r0 = M[I0,1],              // get 8th Col alias reduction sample
          r1 = M[I7,1];              // get 2nd Col, next row, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 9th Col alias reduction sample
          r1 = M[I7,1];              // get 3rd Col, next row, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 10th Col alias reduction sample
          r1 = M[I7,1];              // get 4th Col, next row, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 11th Col alias reduction sample
          r1 = M[I7,1];              // get 5th Col, next row, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 12th Col alias reduction sample
          r1 = M[I7,1];              // get 6th Col, next row, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 13th Col alias reduction sample
          r1 = M[I6,1];              // get 1st Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 14th Col alias reduction sample
          r1 = M[I6,1];              // get 2nd Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 15th Col alias reduction sample
          r1 = M[I6,1];              // get 3rd Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 16th Col alias reduction sample
          r1 = M[I6,1];              // get 4th Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 17th Col alias reduction sample
          r1 = M[I6,1];              // get 5th Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M2],             // get 18th Col alias reduction sample
          r1 = M[I6,M1];             // get 6th Col, row - 6, of IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 7th Col alias reduction sample
          r1 = M[I7,1];              // get 7th Col, next row of IMDCT coef

         M[I1,1] = rMAC;             // write new sample to 0A_Buf
      short_window_loop4:


      // -------------------- IMDCT Short   Loop 5 -------------------------------
      r10 = r2,                      // r2 = 6
       r0 = M[I0, M3];               // set ar_Buf pointer to 13th col (dummy read, M3 = 5)
      r0 = M[I0,1],                  // get 13th Col alias reduction sample
       r1 = M[I6,1];                 // get IMDCT coef

      do short_window_loop5;
         rMAC = r0 * r1,             // do first multiply
          r0 = M[I0,1],              // get 14th Col alias reduction sample
          r1 = M[I6,1];              // get 2nd Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 15th Col alias reduction sample
          r1 = M[I6,1];              // get 3rd Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 16th Col alias reduction sample
          r1 = M[I6,1];              // get 4th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 17th Col alias reduction sample
          r1 = M[I6,1];              // get 5th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],             // get 18th Col alias reduction sample
          r1 = M[I6,M1];             // get 6th Col IMDCT coef
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,1],              // get 13th Col alias reduction sample again
          r1 = M[I6,1];              // get 1st Col, next row, of IMDCT coef

         M[I1,1] = rMAC;             // write new sample to 0A_Buf
      short_window_loop5:


      // -------------------- IMDCT Short   Loop 6 -------------------------------
      r10 = 6;
      r3 = 0;
      do short_window_loop6;
         M[I1,1] = r3;               // write new sample to 0A_Buf of zero
      short_window_loop6:


      r10 = r2,                      // r2 = 6
       r0 = M[I0, M3];               // tweak pointers for next time around loop (dummy read, M3 = 5)
      I6 = I6 - 73;
      I7 = I7 - 73;
      r6 = r6 - 1;                   // decrement number of subbands to process
   if NZ jump short_window_outer_loop;
   rts;

.ENDMODULE;

#endif
