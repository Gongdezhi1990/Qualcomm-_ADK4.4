// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_MACROS_KALASM2_HEADER_INCLUDED
#define CELT_MACROS_KALASM2_HEADER_INCLUDED

 //TODO: optimizig macros for both number of cycles and register usage
/* ----------------------------------------------------------
   macro: $celt.EC_ILOG32
   input, 32-bit unsigned in RI1:RI0
   output, 24-bit RO
   register trashed: rMAC
   result:
      RO = ceil(log2(RI))
-----------------------------------------------------------*/
#define $celt.EC_ILOG32(RI0, RI1, RO) \
        rMAC = RI1;\
        rMAC0 = RI0;\
        RO = signdet rMAC;\
        RO = 47 - RO;

/*---------------------------------------------------------
   macro: $celt.get_pulses
   input unsigned in RIO
   output unsigned in RIO
   register trashed: rMAC, RH
-----------------------------------------------------------*/
#define $celt.get_pulses(RIO, RH, LBL) \
        RH = RIO LSHIFT -3;\
        if Z jump LBL;\
        RH = RH - 1;\
        RIO = RIO AND 7;\
        RIO = RIO + 8;\
        RIO = RIO LSHIFT RH;\
        LBL:

/*-----------------------------------------------------------
   macro:  $celt.fits_in32
   input,
            RN: 24-bit unsigned
            RK: 24-bit unsigned
   output, Z flag
   register trashed: RH
--------------------------------------------------------------*/
#define $celt.fits_in32(RN, RK, RH, LBL1, LBL2) \
        NULL = RN - 14;\
        if NEG jump LBL1;\
           RH = NULL;\
           NULL = RK - 14;\
           if POS jump LBL2;\
              RH = M[$celt.maxN + RK];\
              NULL = RH - RN;\
              if NEG RH = NULL;\
           jump LBL2;\
        LBL1:\
           RH = M[$celt.maxK + RN];\
           NULL = RH - RK;\
           if NEG RH = NULL;\
        LBL2:\
           NULL = RH;

/*-----------------------------------------------------------
   macro:  $celt.ISQRT32
   input: 32 bit unsigned in r1:r0
   output: r3
   register trashed: r2, r4, r7, r8, rMAC, r10, DoLoop

   NOTE: this macro rturns floor(sqrt(input))
      it must be bit-extact, i.e. dont use $math.sqrt function
--------------------------------------------------------------*/
#define $celt.ISQRT32(LBL1, LBL2) \
        rMAC = r1;\
        rMAC0 = r0;\
        r3 = signdet rMAC;\
        r3 = 46 - r3;\
        r3 = r3 LSHIFT -1;\
        r2 = 0;\
        r10 = r3 + 1;\
        r3 = 1 LSHIFT r3;\
        do LBL1;\
           r4 = r2 + r2;\
           r4 = r4 + r3;\
           r8 = r10 - 25;\
           r7 = r4 LSHIFT r8;\
           r8 = r10 - 1;\
           r4 = r4 LSHIFT r8;\
           Null = r0 - r4;\
           Null = r1 - r7 - borrow;\
           if NEG jump LBL2;\
              r2 = r2 + r3;\
              r0 = r0 - r4;\
              r1 = r1 - r7 - borrow;\
           LBL2:\
           r3 = r3  LSHIFT -1;\
        LBL1:
/*----------------------------------------
  
   return k?2:1;
   input: RK
   output: RO
------------------------------------------*/
#define $celt.ncwrs1(RK, RO) \
        RO = 1;\
        NULL = RK;\
        if NZ RO = RO+RO;

/*-----------------------------------------
  return k?4*k:1;
   input: RK
   output: RO
------------------------------------------*/
#define $celt.ncwrs2(RK, RO) \
        RO = 1;\
        NULL = RK;\
        if NZ RO = RK+RK;\
        if NZ RO = RO+RO;

/*------------------------------------------
   return k?2*(2*k*k+1):1;
   input: RK
   output: RO2:ROI, 32-bit unsigned
   trashed: rMAC
--------------------------------------------*/
#define $celt.ncwrs3(RK, RO1, RO2, LBL) \
        RO1 = 1;\
        RO2 = 0;\
        rMAC = RK;\
        if Z jump LBL;\
        rMAC = rMAC + rMAC;\
        rMAC = RK*rMAC;\
        RO1 = rMAC0;\
        RO2 = rMAC1;\
        RO1 = RO1 + 2;\
        RO2 = RO2 + Carry;\
        LBL:
/*---------------------------------------------
   macro:  ncwrs4
   returns: k?((k*k+2)*k)/3<<3:1;
   input: RK
   output: RO2:ROI, 32-bit unsigned
   trashed: rMAC, RH
----------------------------------------------*/
#define $celt.ncwrs4(RK, RO1, RO2, RH, LBL) \
        RO1 = 1;\
        RO2 = 0;\
        RH = 1.0/3.0;\
        rMAC = RK*4(int);\
        if Z jump LBL;\
        RO1 = RK * RK (int);\
        RO1 = RO1 + 2;\
        RO2 = rMAC * RH (frac);\
        RO2 = RO2 * 3(int);\
        Null = RO2 - rMAC;\
        if NZ RO1 = RO1 * RH (frac);\
        Null = RO2 - rMAC;\
        if Z rMAC = rMAC * RH (frac);\
        rMAC = rMAC * RO1;\
        RO1 = rMAC0;\
        RO2 = rMAC1;\
        LBL:
/*------------------------------------------------
   macro:  ncwrs5
   returns: k?(((k*k+5)*k*k)/3<<2)+2:1;
   input: RK
   output: RO2:ROI, 32-bit unsigned
   trashed: rMAC, RH
--------------------------------------------------*/
#define $celt.ncwrs5(RK, RO1, RO2, RH, LBL) \
        RO1 = 1;\
        RO2 = 0;\
        RH = 1.0/3.0;\
        rMAC = RK*RK(int);\
        if Z jump LBL;\
        RO1 = rMAC + 5;\
        rMAC = rMAC + rMAC;\
        RO2 = rMAC * RH (frac);\
        RO2 = RO2 * 3(int);\
        Null = RO2 - rMAC;\
        if NZ RO1 = RO1 * RH (frac);\
        Null = RO2 - rMAC;\
        if Z rMAC = rMAC * RH (frac);\
        rMAC = rMAC * RO1;\
        RO1 = rMAC0;\
        RO2 = rMAC1;\
        RO1 = RO1 + 2;\
        RO2 = RO2 + Carry;\
        LBL:

/*-----------------------------------
   macro: ucwrs2
   returns: k?k+(k-1):0;
   input: RK
   output: RO2:RO
-------------------------------------*/
#define $celt.ucwrs2(RK, RO) \
        RO = RK + RK;\
        RO = RO - 1;\
        if NEG RO = 0;

/*-------------------------------------
   macro: ucwrs3
   returns: k?(2*k-2)*k+1:0;
   input: RK
   output: RO2:ROI, 32-bit unsigned
   trashed: rMAC
---------------------------------------*/
#define $celt.ucwrs3(RK, RO0, RO1, LBL) \
        RO0 = 0;\
        RO1 = 0;\
        rMAC = RK - 1;\
        if NEG jump LBL;\
        rMAC = RK*rMAC;\
        RO0 = rMAC0;\
        RO1 = rMAC1;\
        RO0 = RO0 + 1;\
        RO1 = RO1 + Carry;\
        LBL:

/*--------------------------------------------
   macro: ucwrs5
   returns: k?((2*k*((2*k-3)*k+4)-3):0;
   input: RK
   output: RO2:ROI, 32-bit unsigned
   trashed: rMAC, RH
----------------------------------------------*/
#define $celt.ucwrs4(RK, RO1, RO2, RH, LBL) \
        RO2 = 0;\
        RO1 = RK;\
        if Z jump LBL;\
        RH = 1.0/3.0;\
        rMAC = RK + RK;\
        rMAC = rMAC - 3;\
        rMAC = rMAC * RK (int);\
        rMAC = rMAC + 4;\
        RO2 = rMAC * RH (frac);\
        RO2 = RO2 * 3(int);\
        Null = RO2 - rMAC;\
        if NZ RO1 = RO1 * RH (frac);\
        Null = RO2 - rMAC;\
        if Z rMAC = rMAC * RH (frac);\
        rMAC = rMAC * RO1;\
        RO1 = rMAC0;\
        RO2 = rMAC1;\
        RO1 = RO1 - 1;\
        RO2 = RO2 - Borrow;\
        LBL:

/*----------------------------------------------
   macro: ucwrs5
   returns: k?(((((k-2)*k+5)*k-4)*k)/3<<1)+1:0;
   input: RK
   output: RO2:ROI, 32-bit unsigned
   trashed: rMAC, RH
----------------------------------------------*/
#define $celt.ucwrs5(RK, RO1, RO2, RH, LBL) \
        RO2 = 0;\
        RO1 = RK;\
        if Z jump LBL;\
        RH = 1.0/3.0;\
        rMAC = RK -2;\
        rMAC = rMAC * RK (int);\
        rMAC = rMAC + 5;\
        rMAC = rMAC * RK (int);\
        rMAC = rMAC - 4;\
        RO2 = rMAC * RH (frac);\
        RO2 = RO2 * 3(int);\
        Null = RO2 - rMAC;\
        if NZ RO1 = RO1 * RH (frac);\
        Null = RO2 - rMAC;\
        if Z rMAC = rMAC * RH (frac);\
        rMAC = rMAC * RO1;\
        RO1 = rMAC0;\
        RO2 = rMAC1;\
        RO1 = RO1 + 1;\
        RO2 = RO2 + Carry;\
        LBL:
/*------------------------------------
   macro: $celt.cwrsi1
   returns (k-i)^(-i)
   input, k=RK, i=RI
   output: RO
 -------------------------------------*/
#define $celt.cwrsi1(RK, RI, RO) \
   RO = Null - RI;\
   rMAC = RK + RO;\
   RO = RO XOR rMAC;

/*----------------------------------------
   macro:   sqrt
   is math.sqrt, but saving I0/L0,
   TODO: modify this for less cycles
         and register use
------------------------------------------*/
#define $celt.sqrt \
        push I0;\
        push L0;\
        L0 = 0;\
        call $math.sqrt;\
        pop  L0;\
        pop I0;

#define $celt.icwrs1(RI, RK, RO)\
   RO = 1;\
   RK = RI;\
   if POS RO = NULL;\
   if NZ RK = -RK;
#endif