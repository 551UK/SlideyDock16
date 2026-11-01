#!/usr/bin/env python3
"""Re-encode 8-bit RGB settings PNGs as RGBA, preserving every RGB pixel."""
from pathlib import Path
import struct
import sys
import zlib

SIGNATURE = b"\x89PNG\r\n\x1a\n"

def make_chunk(kind, value):
    return (struct.pack(">I", len(value)) + kind + value +
            struct.pack(">I", zlib.crc32(kind + value) & 0xffffffff))

def paeth(a, b, c):
    p = a + b - c
    da, db, dc = abs(p-a), abs(p-b), abs(p-c)
    return a if da <= db and da <= dc else (b if db <= dc else c)

def normalize(path):
    data = path.read_bytes()
    if not data.startswith(SIGNATURE):
        raise ValueError(f"Not PNG: {path}")
    offset = len(SIGNATURE)
    image_data = bytearray()
    header = None
    while offset < len(data):
        count = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset+4:offset+8]
        payload = data[offset+8:offset+8+count]
        crc = struct.unpack_from(">I", data, offset+8+count)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError(f"Invalid PNG CRC: {path}")
        offset += 12 + count
        if kind == b"IHDR":
            header = bytearray(payload)
        elif kind == b"IDAT":
            image_data.extend(payload)
        elif kind == b"IEND":
            break
    if header is None or len(header) != 13:
        raise ValueError(f"Invalid IHDR: {path}")
    width, height, depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", header)
    if depth != 8 or compression != 0 or filtering != 0 or interlace != 0:
        raise ValueError(f"Unsupported PNG format: {path}")
    if color_type == 6:
        print(f"Already RGBA: {path}")
        return
    if color_type != 2:
        raise ValueError(f"Expected RGB PNG: {path}; received type {color_type}")
    rgb = zlib.decompress(bytes(image_data))
    stride = width * 3
    if len(rgb) != height * (stride+1):
        raise ValueError(f"Incorrect pixel data length: {path}")
    previous = bytearray(stride)
    rgba = bytearray()
    pos = 0
    for _ in range(height):
        filter_type = rgb[pos]
        pos += 1
        encoded = rgb[pos:pos+stride]
        pos += stride
        current = bytearray(stride)
        for i, byte in enumerate(encoded):
            left = current[i-3] if i >= 3 else 0
            above = previous[i]
            upper_left = previous[i-3] if i >= 3 else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left+above)//2
            elif filter_type == 4:
                predictor = paeth(left, above, upper_left)
            else:
                raise ValueError(f"Invalid PNG filter {filter_type}: {path}")
            current[i] = (byte + predictor) & 255
        rgba.append(0)
        for i in range(0, stride, 3):
            rgba.extend(current[i:i+3])
            rgba.append(255)
        previous = current
    header[9] = 6
    encoded = (SIGNATURE + make_chunk(b"IHDR", bytes(header)) +
               make_chunk(b"IDAT", zlib.compress(bytes(rgba), 9)) +
               make_chunk(b"IEND", b""))
    assert encoded[25] == 6
    path.write_bytes(encoded)
    print(f"Normalized {path}: original artwork retained, RGBA PNG")

if __name__ == "__main__":
    for filename in sys.argv[1:]:
        normalize(Path(filename))
