# Copyright (c) 2014 - 2018 Qualcomm Technologies International, Ltd.
# All Rights Reserved.
# Qualcomm Technologies International, Ltd. Confidential and Proprietary.
# Part of BlueLab-7.4-Release
# Part of the Python bindings for the kalaccess library.

from ctypes import c_void_p, c_uint, c_int, c_byte, POINTER
from ka_ctypes import ka_err


class KaMinim:
    def __init__(self, core):
        self._core = core
        self._cfuncs = {}
        self._core._add_cfunc(self._cfuncs, 'minim_is_valid_pm_break_location', POINTER(ka_err), [c_void_p, c_uint, POINTER(c_int)])
        self._core._add_cfunc(self._cfuncs, 'minim_is_prefix_instruction'     , c_byte         , [c_void_p, c_uint, c_byte])
        self._core._add_cfunc(self._cfuncs, 'minim_is_do_instruction'         , c_byte         , [c_void_p, c_uint, c_byte])
        self._core._add_cfunc(self._cfuncs, 'minim_is_call_instruction'       , c_byte         , [c_void_p, c_uint, c_byte])
        self._core._add_cfunc(self._cfuncs, 'minim_is_jump_instruction'       , c_byte         , [c_void_p, c_uint, c_byte])
        self._core._add_cfunc(self._cfuncs, 'minim_is_rts_instruction'        , c_byte         , [c_void_p, c_uint])
        self._core._add_cfunc(self._cfuncs, 'minim_is_rti_instruction'        , c_byte         , [c_void_p, c_uint, c_uint, c_byte])
        self._core._add_cfunc(self._cfuncs, 'minim_will_call_be_taken'        , c_byte         , [c_void_p, c_uint, c_uint, c_uint, c_uint, c_byte, c_byte])

    def is_valid_pm_break_location(self, addr):
        result = c_int()
        err = self._cfuncs['minim_is_valid_pm_break_location'](self._core._get_ka(), addr, result)
        self._core._handle_error(err)
        return bool(result.value)

    def is_prefix_instruction(self, instr, is_prefixed):
        return bool(self._cfuncs['minim_is_prefix_instruction'](self._core._get_ka(), instr, is_prefixed))

    def is_do_instruction(self, instr, is_prefixed):
        return bool(self._cfuncs['minim_is_do_instruction'](self._core._get_ka(), instr, is_prefixed))

    def is_call_instruction(self, instr, is_prefixed):
        return bool(self._cfuncs['minim_is_call_instruction'](self._core._get_ka(), instr, is_prefixed))

    def is_jump_instruction(self, instr, is_prefixed):
        return bool(self._cfuncs['minim_is_jump_instruction'](self._core._get_ka(), instr, is_prefixed))

    def is_rts_instruction(self, instr):
        return bool(self._cfuncs['minim_is_rts_instruction'](self._core._get_ka(), instr))

    def is_rti_instruction(self, instr, prefix1, has_prefix1):
        return bool(self._cfuncs['minim_is_rti_instruction'](self._core._get_ka(), instr, prefix1, has_prefix1))

    def will_call_be_taken(self, instr, prefix1, prefix2, flags, is_prefixed, has_prefix2):
        return bool(self._cfuncs['minim_will_call_be_taken'](self._core._get_ka(), instr, prefix1, prefix2, flags, is_prefixed, has_prefix2))
