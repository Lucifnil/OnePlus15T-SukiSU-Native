#!/usr/bin/env python3
"""Validate a raw BTF blob and its pinned PLZ110 compatibility metrics."""

from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path


HEADER = struct.Struct("<HBBIIIII")
TYPE_HEADER = struct.Struct("<III")


def parse_types(data: bytes) -> int:
    offset = 0
    count = 0
    while offset < len(data):
        if len(data) - offset < TYPE_HEADER.size:
            raise ValueError(f"truncated BTF type header at byte {offset}")
        _name_offset, info, _size_or_type = TYPE_HEADER.unpack_from(data, offset)
        kind = (info >> 24) & 0x1F
        vlen = info & 0xFFFF
        offset += TYPE_HEADER.size

        if kind == 0:  # BTF_KIND_UNKN
            extra = 0
        elif kind == 1:  # BTF_KIND_INT
            extra = 4
        elif kind == 2:  # BTF_KIND_PTR
            extra = 0
        elif kind == 3:  # BTF_KIND_ARRAY
            extra = 12
        elif kind in (4, 5):  # BTF_KIND_STRUCT / BTF_KIND_UNION
            extra = 12 * vlen
        elif kind == 6:  # BTF_KIND_ENUM
            extra = 8 * vlen
        elif kind in (7, 8, 9, 10, 11, 12):
            # FWD, TYPEDEF, VOLATILE, CONST, RESTRICT, FUNC
            extra = 0
        elif kind == 13:  # BTF_KIND_FUNC_PROTO
            extra = 8 * vlen
        elif kind == 14:  # BTF_KIND_VAR
            extra = 4
        elif kind == 15:  # BTF_KIND_DATASEC
            extra = 12 * vlen
        elif kind == 16:  # BTF_KIND_FLOAT
            extra = 0
        elif kind == 17:  # BTF_KIND_DECL_TAG
            extra = 4
        elif kind == 18:  # BTF_KIND_TYPE_TAG
            extra = 0
        elif kind == 19:  # BTF_KIND_ENUM64
            extra = 12 * vlen
        else:
            raise ValueError(f"unsupported BTF kind {kind} at type {count + 1}")

        offset += extra
        if offset > len(data):
            raise ValueError(f"truncated BTF kind {kind} payload at type {count + 1}")
        count += 1

    return count


def inspect(path: Path) -> dict[str, int | str]:
    blob = path.read_bytes()
    if len(blob) < HEADER.size:
        raise ValueError("file is shorter than a BTF header")

    magic, version, flags, header_len, type_off, type_len, str_off, str_len = (
        HEADER.unpack_from(blob)
    )
    if magic != 0xEB9F:
        raise ValueError(f"bad BTF magic 0x{magic:04x}")
    if version != 1:
        raise ValueError(f"unsupported BTF version {version}")
    if header_len < HEADER.size or header_len > len(blob):
        raise ValueError(f"invalid BTF header length {header_len}")

    type_start = header_len + type_off
    type_end = type_start + type_len
    str_start = header_len + str_off
    str_end = str_start + str_len
    if type_end > len(blob) or str_end > len(blob):
        raise ValueError("BTF section range exceeds file size")
    if max(type_end, str_end) != len(blob):
        raise ValueError("unexpected trailing bytes after BTF sections")

    strings = blob[str_start:str_end]
    if not strings or strings[0] != 0 or strings[-1] != 0:
        raise ValueError("BTF string table is not NUL bounded")

    type_count = parse_types(blob[type_start:type_end])
    return {
        "sha256": hashlib.sha256(blob).hexdigest(),
        "file_len": len(blob),
        "flags": flags,
        "type_len": type_len,
        "string_len": str_len,
        "type_count": type_count,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("btf", type=Path)
    parser.add_argument("--sha256")
    parser.add_argument("--type-count", type=int)
    parser.add_argument("--type-len", type=int)
    parser.add_argument("--string-len", type=int)
    args = parser.parse_args()

    actual = inspect(args.btf)
    expected = {
        "sha256": args.sha256.lower() if args.sha256 else None,
        "type_count": args.type_count,
        "type_len": args.type_len,
        "string_len": args.string_len,
    }
    for key, value in expected.items():
        if value is not None and actual[key] != value:
            raise SystemExit(f"{key}: expected {value}, got {actual[key]}")

    print(
        "BTF verified: "
        f"sha256={actual['sha256']} types={actual['type_count']} "
        f"type_len={actual['type_len']} string_len={actual['string_len']}"
    )


if __name__ == "__main__":
    main()
