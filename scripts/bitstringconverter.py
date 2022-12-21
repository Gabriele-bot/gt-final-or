import bitstring as bs
import numpy as np


# Vectorizing bs.pack to use bitstring with numpy arrays
def pack_wrapper(formatstring, data, str_fromat):
    if str_fromat == 'hex':
        return bs.pack(formatstring, data).hex
    elif str_fromat == 'bin':
        return bs.pack(formatstring, data).bin

pack_vec = np.vectorize(pack_wrapper)


# Vectorizing bitstring unpacking function to work with numpy arrays of strings
def unpack_wrapper(formatstring, bitstring):
    return np.array([bs.Bits(hex=s).unpack(fs)[0] for s, fs in zip(bitstring, formatstring)])


def unpack_vec(formatstring, bitstring):
    return np.array([unpack_wrapper(formatstring, line) for line in bitstring])


# Padding function for a single value (and a numpy vector)
def padd_value(val, padding):
    # determine length of string
    length = len(val)
    if (padding < length):
        print("ERROR: padding too small")
    else:
        return (padding - length) * '0' + val


padd_vec = np.vectorize(padd_value)


# unpadding function to undo padd_value
def unpadd_value(val, padding):
    # crosschecking whether only 0s are removed
    for i, char in enumerate(val[:padding]):
        if (char != "0"): print("WARNING: unpadding non-0 character!")
    return val[padding:]


unpadd_vec = np.vectorize(unpadd_value)


# just outsourced Arturs functions and added usage of total_bits to have everything in one place
def convert_to_ap_fixed(a, total_bits, int_bits):
    frac_bits = total_bits - int_bits
    float_ar = np.asarray(a)
    fixed_ar = np.ndarray(float_ar.shape, np.dtype('int' + str(total_bits)))
    fixed_ar[:] = float_ar * 2 ** frac_bits
    return fixed_ar


def convert_to_ap_ufixed(a, total_bits, int_bits):
    frac_bits = total_bits - int_bits
    float_ar = np.asarray(a)
    fixed_ar = np.ndarray(float_ar.shape, np.dtype('uint' + str(total_bits)))
    fixed_ar[:] = float_ar * 2 ** frac_bits
    return fixed_ar


def convert_from_ap_fixed(a, total_bits, int_bits):
    frac_bits = total_bits - int_bits
    mask1 = 1 << (total_bits - 1)
    mask2 = mask1 - 1
    return ((a & mask2) - (a & mask1)) / (1 << frac_bits)


def convert_from_ap_ufixed(a, total_bits, int_bits):
    frac_bits = total_bits - int_bits
    return a / (1 << frac_bits)
