// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#ifndef MALLOC_HEADER_INCLUDED
#define MALLOC_HEADER_INCLUDED

// Definition of structure used to represent a buffer in the $malloc.pool array.
.CONST $malloc.BUFFER_ADDRESS_FIELD    0; // The address of the buffer
.CONST $malloc.BUFFER_SIZE_FLAGS_FIELD 1; // The size of the buffer (in words) and some flags
.CONST $malloc.BUFFER_STRUC_SIZE       2;

.CONST $malloc.SIZE_MASK 0xFFFF;
.CONST $malloc.FLAGS_MASK ~$malloc.SIZE_MASK;

// Buffer flags
.CONST $malloc.FLAG_ALLOCATED (1 << 23); // Set=allocated, Clear=free
.CONST $malloc.FLAG_ALLOCATED_INV ($malloc.FLAG_ALLOCATED ^ 0xFFFFFF);
.CONST $malloc.FLAG_DM2  (1 << 22);       // Set=DM2, Clear=DM1
.CONST $malloc.FLAG_CIRCULAR  (1 << 21);  // Set for circular buffer

#endif
