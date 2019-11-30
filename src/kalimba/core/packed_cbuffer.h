// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef PACKED_CBUFFER_H
#define PACKED_CBUFFER_H

#ifndef BASE_REGISTER_MODE
#define PACKBUF_DMDECL      DMCIRC
#else
#define PACKBUF_DMDECL      DM
#endif


#include "core_library.h"

   // packed cbuffer field definitions
   .CONST    $packed_cbuffer.READ_BYTEPOS_FIELD       0 + $cbuffer.STRUC_SIZE;
   .CONST    $packed_cbuffer.WRITE_BYTEPOS_FIELD      1 + $cbuffer.STRUC_SIZE;
   .CONST    $packed_cbuffer.STRUC_SIZE               1 + $packed_cbuffer.WRITE_BYTEPOS_FIELD;
   .CONST    $packed_cbuffer.INIT_BYTEPOS             2;
   
   // macros to aid creating packed buffers
   #define DeclarePackedCBuffer(buf_name, mem, buf_size)                      \
      .VAR/PACKBUF_DMDECL mem[buf_size];                                      \
      DeclarePackedCBufferNoMem(buf_name, mem)


#ifdef BASE_REGISTER_MODE
   #define DeclarePackedCBufferNoMem(buf_name, mem)                           \
      .BLOCK/DM buf_name;                                                     \
         .VAR buf_name ## _cbuffer[$cbuffer.STRUC_SIZE] =                     \
            LENGTH(mem),                                                      \
            &mem,                                                             \
            &mem,                                                             \
            &mem;                                                             \
         .VAR buf_name ## _read_bytepos = $packed_cbuffer.INIT_BYTEPOS;  \
         .VAR buf_name ## _write_bytepos = $packed_cbuffer.INIT_BYTEPOS; \
      .ENDBLOCK
#else
   #define DeclarePackedCBufferNoMem(buf_name, mem)                           \
      .BLOCK/DM buf_name;                                                     \
         .VAR buf_name ## _cbuffer[$cbuffer.STRUC_SIZE] =                     \
            LENGTH(mem),                                                      \
            &mem,                                                             \
            &mem;                                                             \
         .VAR buf_name ## _read_bytepos = $packed_cbuffer.INIT_BYTEPOS;  \
         .VAR buf_name ## _write_bytepos = $packed_cbuffer.INIT_BYTEPOS; \
      .ENDBLOCK
#endif


#endif
