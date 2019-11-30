// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CBOPS_LIMITED_AMOUNT_HEADER_INCLUDED
#define CBOPS_LIMITED_AMOUNT_HEADER_INCLUDED
   
   .CONST   $cbops.limited_amount.AMOUNT_FIELD                        0;
   .CONST   $cbops.limited_amount.FLUSH_THRESHOLD_FIELD               $cbops.limited_amount.AMOUNT_FIELD + 1;
#ifdef USE_PACKED_ENCODED_DATA
   .CONST   $cbops.limited_amount.PACKED_CBUFFER_FIELD                $cbops.limited_amount.FLUSH_THRESHOLD_FIELD + 1;
   .CONST   $cbops.limited_amount.FLUSH_COUNTER_FIELD                 $cbops.limited_amount.PACKED_CBUFFER_FIELD + 1;
#else
   .CONST   $cbops.limited_amount.FLUSH_COUNTER_FIELD                 $cbops.limited_amount.FLUSH_THRESHOLD_FIELD + 1;
#endif
   .CONST   $cbops.limited_amount.STRUC_SIZE                          $cbops.limited_amount.FLUSH_COUNTER_FIELD  + 1;

   .CONST   $cbops.limited_amount.NO_AMOUNT                          -1;
   
   

#endif // CBOPS_LIMITED_AMOUNT_HEADER_INCLUDED
