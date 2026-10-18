"""Tests for the PRP walk reference model (tools/prp_model.py).

These validate the exact algorithm used by rtl/dma/dma_engine.sv, including the
scenario in sim/integration/tb_dma_prp.sv, without needing a Verilog simulator.
"""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from prp_model import prp_pages  # noqa: E402

PAGE = 4096


def test_single_page_no_offset():
    pages, reads = prp_pages(0x1000, 0, 512)
    assert pages == [(0x1000, 512)]
    assert reads == []


def test_single_page_with_offset_up_to_end():
    # offset 0x200 -> first page can carry 0xE00 bytes; exactly fills it
    pages, reads = prp_pages(0x1_0000_0200, 0, PAGE - 0x200)
    assert pages == [(0x1_0000_0200, PAGE - 0x200)]
    assert reads == []


def test_two_pages_prp2_is_data():
    # offset 0 first page (4096) + 100 more -> PRP2 is a data page
    pages, reads = prp_pages(0x1000, 0x5000, PAGE + 100)
    assert pages == [(0x1000, PAGE), (0x5000, 100)]
    assert reads == []


def test_three_pages_via_list_matches_tb():
    # mirrors sim/integration/tb_dma_prp.sv
    table = {0x2_0000_0000: 0x3_0000_0000, 0x2_0000_0008: 0x4_0000_0000}
    length = 3584 + 4096 + 100
    pages, reads = prp_pages(0x1_0000_0200, 0x2_0000_0000, length,
                             list_read=table.__getitem__)
    assert [a for a, _ in pages] == [0x1_0000_0200, 0x3_0000_0000, 0x4_0000_0000]
    assert [n for _, n in pages] == [3584, 4096, 100]
    assert reads == [0x2_0000_0000, 0x2_0000_0008]
    assert sum(n for _, n in pages) == length


def test_list_chaining_across_list_pages():
    # PRP2 points at the LAST slot of a list page -> that entry chains to a new
    # list page, from which the data-page entries are read.
    last_slot = 0x2_0000_0FF8          # offset 0xFF8 = PAGE-8
    chained = 0x9_0000_0000            # next list page
    table = {
        last_slot:         chained,        # chain pointer
        chained + 0x0:     0x3_0000_0000,  # data page 1
        chained + 0x8:     0x4_0000_0000,  # data page 2
    }
    length = PAGE * 3                   # page0 (prp1) + 2 pages via list
    pages, reads = prp_pages(0x1000, last_slot, length, list_read=table.__getitem__)
    assert [a for a, _ in pages] == [0x1000, 0x3_0000_0000, 0x4_0000_0000]
    assert [n for _, n in pages] == [PAGE, PAGE, PAGE]
    assert reads == [last_slot, chained + 0x0, chained + 0x8]


def test_list_required_raises():
    with pytest.raises(ValueError):
        prp_pages(0x1000, 0x2000, PAGE * 4)  # spans >2 pages, no callback


def test_total_bytes_preserved_random_sizes():
    table = {0x2_0000_0000 + 8 * i: 0x5_0000_0000 + (i << 12) for i in range(16)}
    for length in (1, 4096, 4097, 10000, 65536):
        pages, _ = prp_pages(0x1_0000_0000, 0x2_0000_0000, length,
                             list_read=lambda a: table.get(a, 0x7_0000_0000))
        assert sum(n for _, n in pages) == length
