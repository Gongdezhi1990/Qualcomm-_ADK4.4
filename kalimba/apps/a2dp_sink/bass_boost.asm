// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "music_example.h"
#include "music_manager_config.h"

#if uses_BASS_BOOST

// *****************************************************************************
// MODULE:
//    $bass_boost_process_wrapper
//
// DESCRIPTION:
//    Wrapper function to process the Bass Boost feature
//    (this allows the bass_boost to be selected and bypassed)
//
// INPUTS:
//    - r7 = pointer to the bass boost definition table
//
// OUTPUTS:
//    none
//
// TRASHED:
//    - Assume all
//
// *****************************************************************************
.MODULE $M.bass_boost_process_wrapper;
   .CODESEGMENT BASS_BOOST_PROCESS_WRAPPER;

   $bass_boost_process_wrapper:

   $push_rLink_macro;

   // Get the bass enhancement selection
   r1 = M[$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_BASS_ENHANCEMENT_SELECTION];

   // Bass Boost selected?
   null = r1 AND $M.MUSIC_MANAGER.CONFIG.BASS_ENHANCEMENT_SELECT_BASS_BOOST;
   if Z jump exit;   // No - exit

      r8 = $M.MUSIC_MANAGER.CONFIG.BASS_ENHANCEMENT_BYPASS;

      // Process the right channel
      // r7 = definition table, r8 = bypass bitfield?
      call $music_example.peq.process;

   exit:

   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
