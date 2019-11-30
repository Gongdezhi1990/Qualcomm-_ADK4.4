// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// The malloc library requires an external array of buffer structures called
// $malloc.pool - see malloc.h for a description of the structure fields.
// To optimise malloc, the array may be ordered by size from smallest buffer to
// largest buffer.
//
// *****************************************************************************
#include "malloc.h"

// *****************************************************************************
// MODULE:
//    $_malloc
//
// DESCRIPTION:
//    Memory allocate r0 bytes - where a byte is the smallest addressable unit
//    of memory.
//
// INPUTS:
//    - r0 - The number of bytes to allocate
//
// OUTPUTS:
//    - r0 - NULL if the memory could not be allocated, otherwise the address of
//    the allocated memory.
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3
//
// NOTES:
//    The function returns the first buffer in the pool array that meets the
//    size requirement.
//
// *****************************************************************************
.MODULE $_malloc;
   .CODESEGMENT PM;

$_malloc:
    Null = r0;
    if Z rts;

    r1 = Null;
    search:
        // Test if the buffer is large enough
        r2 = M[r1 + &$malloc.pool + $malloc.BUFFER_SIZE_FLAGS_FIELD];
        r3 = r2 AND $malloc.SIZE_MASK;
        Null = r3 - r0;
        if NEG jump next;
            // Test if the buffer is free
            Null = r2 AND ($malloc.FLAGS_MASK & $malloc.FLAG_ALLOCATED);
            if NZ jump next;
                // The buffer is large enough and free, set the allocated bit in flags
                r2 = r2 OR $malloc.FLAG_ALLOCATED;
                M[r1 + &$malloc.pool + $malloc.BUFFER_SIZE_FLAGS_FIELD] = r2;
                // Return the address of the buffer
                r0 = M[r1 + &$malloc.pool + $malloc.BUFFER_ADDRESS_FIELD];
                rts;
        next:
            r1 = r1 + $malloc.BUFFER_STRUC_SIZE;
            Null = r1 - $malloc.pool.length;
            if NEG jump search;

    // Unable to allocate a buffer
    r0 = Null;
    rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $_free
//
// DESCRIPTION:
//    Free allocated memory.
//
// INPUTS:
//    - r0 - Address of allocated memory to free.
//
// OUTPUTS:
//    - None
//
// TRASHED REGISTERS:
//    r0, r1, r2
//
// *****************************************************************************
.MODULE $_free;
   .CODESEGMENT PM;

$_free:
    Null = r0;
    if Z rts;

    r1 = Null;
    search:
        // Test if this buffer is to be freed
        r2 = M[r1 + &$malloc.pool + $malloc.BUFFER_ADDRESS_FIELD];
        Null = r2 - r0;
        if Z jump found;
            r1 = r1 + $malloc.BUFFER_STRUC_SIZE;
            Null = r1 - $malloc.pool.length;
            if NEG jump search;
            rts;
        found:
            // Clear the allocated flag
            r2 = M[r1 + &$malloc.pool + $malloc.BUFFER_SIZE_FLAGS_FIELD];
            r2 = r2 AND $malloc.FLAG_ALLOCATED_INV;
            M[r1 + &$malloc.pool + $malloc.BUFFER_SIZE_FLAGS_FIELD] = r2;
            rts;
.ENDMODULE;
