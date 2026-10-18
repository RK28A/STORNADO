"""PRP walk reference model (oracle for rtl/dma/dma_engine.sv).

Pure-Python implementation of the exact page-walk algorithm the RTL uses, so the
logic can be validated without a Verilog simulator. The SV FSM and this model
must stay in lockstep; `host/tests/test_prp_model.py` checks several scenarios,
including the one in sim/integration/tb_dma_prp.sv.

NVMe 2.0, section 4.1.2:
  - page size P; PRP1 may carry a byte offset within its page.
  - first transfer covers from that offset to the end of the page (or the whole
    length if smaller).
  - if what remains fits in one more page, PRP2 is a data-page pointer.
  - otherwise PRP2 points to a PRP list; each 8-byte entry is a page address, and
    the last slot of a list page chains to the next list page.
"""
from __future__ import annotations

from collections.abc import Callable


def prp_pages(
    prp1: int,
    prp2: int,
    length: int,
    page: int = 4096,
    list_read: Callable[[int], int] | None = None,
) -> tuple[list[tuple[int, int]], list[int]]:
    """Return (data_pages, list_reads).

    data_pages: ordered [(host_addr, nbytes), ...] actually transferred.
    list_reads: ordered addresses of PRP-list entries read (incl. chain reads).
    list_read(addr) -> 64-bit entry; required once a PRP list is used.
    """
    if length <= 0:
        return [], []

    offset = prp1 % page
    first = min(length, page - offset)
    data_pages: list[tuple[int, int]] = [(prp1, first)]
    remaining = length - first
    list_reads: list[int] = []

    if remaining == 0:
        return data_pages, list_reads

    if remaining <= page:
        # exactly one more page: PRP2 is a data pointer
        data_pages.append((prp2, remaining))
        return data_pages, list_reads

    # more than two pages: PRP2 is a PRP list
    if list_read is None:
        raise ValueError("transfer spans > 2 pages: a list_read callback is required")

    list_addr = prp2
    guard = 0
    while remaining > 0:
        guard += 1
        if guard > 1 << 20:
            raise RuntimeError("PRP walk did not terminate (bad list?)")
        entry = list_read(list_addr)
        list_reads.append(list_addr)
        if list_addr % page == page - 8:
            # last slot of this list page chains to the next list page
            list_addr = entry
            continue
        chunk = min(remaining, page)
        data_pages.append((entry, chunk))
        remaining -= chunk
        list_addr += 8

    return data_pages, list_reads
