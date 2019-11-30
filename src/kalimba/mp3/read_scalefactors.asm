// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_READ_SCALEFACTORS_INCLUDED
#define MP3DEC_READ_SCALEFACTORS_INCLUDED

#include "stack.h"
#include "mp3.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.read_scalefactors
//
// DESCRIPTION:
//    Read Scalefactors
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    rMAC, r0-r8, r10, DoLoop, I0, I2, I3, I6, M0, M1,
//
// *****************************************************************************
.MODULE $M.mp3dec.read_scalefactors;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $mp3dec.read_scalefactors:

   // push rLink onto stack
   $push_rLink_macro;


   r3 = M[$mp3dec.current_grch];
   r4 = r3 AND $mp3dec.CHANNEL_MASK;
   r5 = r4 * ($mp3dec.NUM_SHORT_SF_BANDS*3) (int);
   // I2 = scalefac[ch]
   I2 = &$mp3dec.scalefac + r5;

   r5 = M[$mp3dec.scalefac_compress + r3];
   r0 = M[$mp3dec.frame_version];
   if NZ jump mpeg2_or_2p5_scalefactors;
   mpeg1_scalefactors:
      r0 = r4 * 4 (int);
      // I3 = scfsi[ch];
      I3 = &$mp3dec.scfsi + r0;
      r6 = M[$mp3dec.scalefac_compress_slen_lookup + r5];
      r10 = 4;
      I6 = &$mp3dec.slens;
      do loop;
         r0 = r6 AND 15;
         M[I6,1] = r0;
         r6 = r6 LSHIFT -4;
      loop:
      r5 = &$mp3dec.scalefac_nr_of_sfb_lookup + 0; // MPEG1 nr_of_sfb data
      jump done_mpeg_version_differences;

   mpeg2_or_2p5_scalefactors:
      // Taken from the ISO/IEC 13818-3
      //
      // if (!(((mode_extension == '01') || (mode_extension == '11') ) && (ch==1) ) ){
      //    if ( scalefac_compress < 400 ) {
      //       slen1 = (scalefac_compress >> 4) / 5
      //       slen2 = (scalefac_compress >> 4) % 5
      //       slen3 = (scalefac_compress % 16) >>2
      //       slen4 = scalefac_compress % 4
      //       preflag = 0
      //       block_type    mixed_block_flag    nr_of_sfb1    nr_of_sfb2    nr_of_sfb3    nr_of_sfb4
      //       '00','01','11'      x                 6             5             5             5
      //       '10'                0                 9             9             9             9
      //       '10'                1                 6             9             9             9
      //    }
      //    if ( (400 <= scalefac_compress) && (scalefac_compress < 500) ) {
      //       slen1 = ((scalefac_compress-400) >> 2) / 5
      //       slen2 = ((scalefac_compress-400) >> 2) % 5
      //       slen3 = (scalefac_compress-400) % 4
      //       slen4 = 0
      //       preflag = 0
      //       block_type    mixed_block_flag    nr_of_sfb1    nr_of_sfb2    nr_of_sfb3    nr_of_sfb4
      //       '00','01','11'       x                6             5             7             3
      //       '10'                 0                9             9            12             6
      //       '10'                 1                6             9            12             6
      //    }
      //    if ( (500 <= scalefac_compress) && (scalefac_compress < 512) ) {
      //       slen1 = (scalefac_compress-500) / 3
      //       slen2 = (scalefac_compress-500) % 3
      //       slen3 = 0
      //       slen4 = 0
      //       preflag = 1
      //       block_type    mixed_block_flag    nr_of_sfb1    nr_of_sfb2    nr_of_sfb3    nr_of_sfb4
      //       '00','01','11'       x               11            10             0             0
      //       '10'                 0               18            18             0             0
      //       '10'                 1               15            18             0             0
      //    }
      // }
      // if ( ( (mode_extension == '01') || (mode_extension == '11') ) && (ch == 1) ) {
      //    intensity_scale = scalefac_compress % 2
      //    int_scalefac_compress = scalefac_compress >> 1
      //    if (int_scalefac_compress < 180 ) {
      //       slen1 = int_scalefac_compress / 36
      //       slen2 = (int_scalefac_compress % 36) / 6
      //       slen3 = (int_scalefac_compress % 36) % 6
      //       slen4 = 0
      //       preflag = 0
      //       block_type    mixed_block_flag    nr_of_sfb1    nr_of_sfb2    nr_of_sfb3    nr_of_sfb4
      //       '00','01','11'       x                7             7             7             0
      //       '10'                 0               12            12            12             0
      //       '10'                 1                6            15            12             0
      //    }
      //    if ( (180 <= int_scalefac_compress) && (int_scalefac_compress < 244) ) {
      //       slen1 = ((int_scalefac_compress-180) % 64 ) >> 4
      //       slen2 = ((int_scalefac_compress-180) % 16 ) >> 2
      //       slen3 = (int_scalefac_compress-180) % 4
      //       slen4 = 0
      //       preflag = 0
      //       block_type    mixed_block_flag    nr_of_sfb1    nr_of_sfb2    nr_of_sfb3    nr_of_sfb4
      //       '00','01','11'       x                6             6             6             3
      //       '10'                 0               12             9             9             6
      //       '10'                 1                6            12             9             6
      //    }
      //    if ( (244 <= int_scalefac_compress) && (int_scalefac_compress <= 255) ) {
      //       slen1 = (int_scalefac_compress-244) / 3
      //       slen2 = (int_scalefac_compress-244) % 3
      //       slen3 = 0
      //       slen4 = 0
      //       preflag = 0
      //       block_type    mixed_block_flag    nr_of_sfb1    nr_of_sfb2    nr_of_sfb3    nr_of_sfb4
      //       '00','01','11'       x                8             8             5             0
      //       '10'                 0               15            12             9             0
      //       '10'                 1                6            18             9             0
      //    }
      // }
      //
      // In scalefactor bands where slen1, slen2, slen3 or slen4 is zero and the corresponding nr_of_slen1,
      // nr_of_slen2, nr_of_slen3 or nr_of_slen4 is not zero, the scalefactors of these bands must be set to zero,
      // resulting in an intensity position of zero.

      // preflag default is 0
      r6 = 0;
      // initialise the contents of r4 to be zero as it is set to that most of the time
      r4 = 0;

      r0 = M[$mp3dec.mode_extension];
      Null = r0 AND $mp3dec.IS_MASK;
      if Z jump not_intensity_stereo;
      Null = r3;
      if NZ jump intensity_stereo_and_right_chan;
      not_intensity_stereo:


         Null = r5 - 400;
         if POS jump not_lessthan_400;
            r7 = r5 LSHIFT -4;


            r0 = r7 - 2;
            r0 = r0 * (1.0/5.0) (frac); // This is the div result
            r1 = r0 * 5 (int);
            r1 = r7 - r1; // This is the div remainder

            r2 = r5 AND 15;
            r2 = r2 LSHIFT -2;
            r4 = r5 AND 3;
            r5 = &$mp3dec.scalefac_nr_of_sfb_lookup + 3;

            jump scalefac_compress_slen_decoded;

         not_lessthan_400:
         Null = r5 - 500;
         if POS jump not_lessthan_500;
            r5 = r5 - 400;
            r7 = r5 LSHIFT -2;

            // Divide by 5
            r0 = r7 - 2;
            r0 = r0 * (1.0/5.0) (frac); // This is the div result
            r1 = r0 * 5 (int);
            r1 = r7 - r1; // This is the div remainder

            r2 = r5 AND 3;
            r5 = &$mp3dec.scalefac_nr_of_sfb_lookup + 6;

            jump scalefac_compress_slen_decoded;

         not_lessthan_500:
            r7 = r5 - 500;

            // Divide by 3
            r0 = r7 - 1;
            r0 = r0 *  (1.0/3.0) (frac); // This is the div result
            r1 = r0 * 3 (int);
            r1 = r7 - r1; // This is the div remainder

            r2 = 0;
            r6 = 1;
            r5 = &$mp3dec.scalefac_nr_of_sfb_lookup + 9;

            jump scalefac_compress_slen_decoded;

      intensity_stereo_and_right_chan:
         // extract intensity_scale
         r0 = r5 AND 1;
         M[$mp3dec.count1table_select] = r0;
         r5 = r5 LSHIFT -1;
         Null = r5 - 180;
         if POS jump not_lessthan_180;

            // Divide by 36
            r0 = r5 - 4;
            r0 = r0 * (1.0/9.0) (frac); // This is the div result
            r0 = r0 LSHIFT -2;
            r1 = r0 * 36 (int);
            r7 = r5 - r1; // This is the div remainder

            r5 = &$mp3dec.scalefac_nr_of_sfb_lookup + 12;




            // The div remainder is in r7 from above

            // Divide by 6
            r1 = r7 - 1;
            r1 = r1 * (1.0/3.0) (frac); // This is the div result
            r1 = r1 LSHIFT -1;
            r2 = r1 * 6 (int);
            r2 = r7 - r2; // This is the div remainder

            jump scalefac_compress_slen_decoded;

         not_lessthan_180:
         Null = r5 - 244;
         if POS jump not_lessthan_244;

            r5 = r5 - 180;
            r0 = r5 AND 63;
            r0 = r0 LSHIFT -4;
            r1 = r5 AND 15;
            r1 = r1 LSHIFT -2;
            r2 = r5 AND 3;
            r5 = &$mp3dec.scalefac_nr_of_sfb_lookup + 15;
            jump scalefac_compress_slen_decoded;

         not_lessthan_244:

            r5 = r5 - 244;
            // divide by 3
            r0 = r5 - 1;
            r0 = r0 * (1.0/3.0) (frac); // This is the div result
            r2 = r0 * 3 (int);
            r1 = r5 - r2; // This is the div remainder

            r2 = 0;
            r5 = &$mp3dec.scalefac_nr_of_sfb_lookup + 18;


      scalefac_compress_slen_decoded:

      // store preflag
      M[$mp3dec.preflag + r3] = r6;

      // store slens
      M[$mp3dec.slens + 0] = r0;
      M[$mp3dec.slens + 1] = r1;
      M[$mp3dec.slens + 2] = r2;
      M[$mp3dec.slens + 3] = r4;


   done_mpeg_version_differences:
   // decode and store nr_of_sfb's data
   I6 = &$mp3dec.nr_of_sfbs;
   r0 = 1;
   r1 = M[$mp3dec.block_type + r3];
   Null = r1 AND $mp3dec.SHORT_MASK;
   if Z r0 = 0;
   Null = r1 AND $mp3dec.MIXED_MASK;
   if NZ r0 = r0 + r0;
   r10 = 4;

  // This loop is just here to unpack the SFB data that is stored in $mp3dec.scalefac_nr_of_sfb_lookup
   r1 = M[r5 + r0];
   r2 = -5;
   do nr_of_sfb_loop;
      r0 = r1 AND 31;
      r1 = r1 LSHIFT r2,   M[I6,1] = r0;
   nr_of_sfb_loop:


   // read bitres out pointer and mask
#ifdef MP3_USE_EXTERNAL_MEMORY
   L0 = $mp3dec.mem.BITRES_LENGTH;
#else
   L0 = LENGTH($mp3dec.bitres);
#endif
   r0 = M[$mp3dec.bitres_outptr];
   I0 = r0;
   M0 = 1;
   // read current word from bitres
   r1 = M[I0,M0];
   r2 = M[$mp3dec.bitres_outbitmask];
   r4 = SIGNDET r2;
   Null = r2;
   if POS r4 = r4 + M0;
   // r4 = bit position of the set bit

   // work out what value the bitres pointer and the bitmask will be after
   // part2_3_length bits have been read.
   r0 = M[$mp3dec.part2_3_length + r3];
   r4 = r4 + r0;
   r4 = r4 - 11;
   r5 = r4 * (1.0/24.0) (frac);
   M1 = r5;
   r0 = M[I0,M1];         // I0 = I0 + M1  (with ring buffer wrap around)
   r0 = I0;               // store ending bitres pointer value
   M[$mp3dec.bitres_outptr_p23end] = r0;
   M1 = -M1;
   r5 = r5 * 24 (int);
   r4 = r5 - r4,  r0 = M[I0,M1];         // I0 = I0 - M1  (put it back again)
   r4 = r4 + 12;
   r4 = 1 LSHIFT r4;
   M[$mp3dec.bitres_outbitmask_p23end] = r4;



   // set r3 = 0 for short blocks so that scfi bits not used
   r0 = M[$mp3dec.block_type + r3];
   Null = r0 AND $mp3dec.SHORT_MASK;
   if NZ r3 = 0;
   // set r3 = 0(gr=0)  1 (gr=1) for scfi usage to work
   r3 = r3 LSHIFT -1;

   // set I6 to point to last scf + 1
   I6 = I2 + ($mp3dec.NUM_SHORT_SF_BANDS*3);

   r4 = -4;
   r5 = 1 << 23;
   scf_block_loop:
      r0 = M[I3,1];
      Null = r0 AND r3;             // if (scfi[ch][scfi_band]==0) || (gr ==0)
      if Z jump scfi_update;
        // keep the previous granule's scf info
        r0 = M[($mp3dec.nr_of_sfbs+4) + r4];
        I2 = I2 + r0;
        jump scf_read_done;
      scfi_update:
      r7 = M[($mp3dec.nr_of_sfbs+4) + r4];   // for (i=0; i<nr_of_sfbs; i++)
      if Z jump scf_read_done;
      read_scf_loop:                         //    scalefac[gr][ch][sfb++] =  0..5 bits
         r10 = M[($mp3dec.slens+4) + r4];    // slen1
         call $mp3dec.getbitresbits;
         r7 = r7 - M0,
          M[I2,1] = r0;
      if NZ jump read_scf_loop;
      scf_read_done:

      r4 = r4 + 1;
   if NZ jump scf_block_loop;


   r10 = I6 - I2;
   r0 = 0;
   do clear_last_scfs_loop;
      M[I2,1] = r0;          // scalefac_l[gr][ch][...] = 0;
   clear_last_scfs_loop:

   // subtract 1 from I0 with ring buffer wrap around
   r0 = M[I0,-1];
   r0 = I0;
   // store bitres pointer and mask
   M[$mp3dec.bitres_outptr] = r0;
   M[$mp3dec.bitres_outbitmask] = r2;
   // set length register back to 0
   L0 = 0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
