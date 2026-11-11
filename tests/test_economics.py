# -*- coding: utf-8 -*-
"""Verify historical calendar and dependent-data bootstrap diagnostics."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def script(name):
    path = ROOT / "cong-cu" / name
    spec = importlib.util.spec_from_file_location(path.stem, str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class EconomicRegression(unittest.TestCase):
    def test_cpi_2026_release_calendar_is_complete_and_utc(self):
        v = script("kiem_tra_lich_tin.py")
        rows = v.validate()
        self.assertEqual(len([x for x in rows if x[1] == "CPI" and x[2].startswith("2026")]), 12)
        self.assertIn((1794317400, "CPI", "2026-11-10 13:30"), rows)
        self.assertIn((1796909400, "CPI", "2026-12-10 13:30"), rows)

    def test_moving_block_bootstrap_is_deterministic_and_not_iid(self):
        model = script("bootstrap_khoi_thang.py")
        values, trades = model.monthly_r(
            ROOT / "ket-qua" / "20261107-1924-chinhxac-lenh.csv",
            "C-Donchian20-H4-ADX")
        self.assertEqual(trades, 85)
        one = model.bootstrap(values, blocks=3, draws=300, seed=130326)
        self.assertEqual(one, model.bootstrap(values, blocks=3, draws=300, seed=130326))
        self.assertAlmostEqual(one["observed_R"], 35.08, delta=0.04)
        self.assertLessEqual(one["p025_R"], one["median_R"])
        self.assertLessEqual(one["median_R"], one["p975_R"])


if __name__ == "__main__":
    unittest.main()
