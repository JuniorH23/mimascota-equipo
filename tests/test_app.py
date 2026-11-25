import unittest
from datetime import date, datetime
from decimal import Decimal

from app import (
    build_personalized_search_query,
    parse_date,
    parse_datetime,
    parse_positive_integer,
    parse_positive_number,
)


class InputParsingTests(unittest.TestCase):
    def test_parse_date_accepts_iso_and_rejects_invalid_date(self):
        self.assertEqual(parse_date("2026-11-18"), date(2026, 11, 18))
        with self.assertRaises(ValueError):
            parse_date("18/11/2026")

    def test_parse_datetime_accepts_optional_seconds(self):
        self.assertEqual(parse_datetime("2026-11-18 09:30"), datetime(2026, 11, 18, 9, 30))
        self.assertEqual(
            parse_datetime("2026-11-18 09:30:45"),
            datetime(2026, 11, 18, 9, 30, 45),
        )
        with self.assertRaises(ValueError):
            parse_datetime("mañana")

    def test_measurements_must_be_positive(self):
        self.assertEqual(parse_positive_integer("3", "Cantidad"), 3)
        self.assertEqual(parse_positive_number("4,25", "Peso"), Decimal("4.25"))
        with self.assertRaises(ValueError):
            parse_positive_integer("0", "Cantidad")
        with self.assertRaises(ValueError):
            parse_positive_number("-1", "Peso")
        with self.assertRaises(ValueError):
            parse_positive_number("NaN", "Peso")


class PersonalizedSearchTests(unittest.TestCase):
    def test_search_uses_only_pet_id_as_a_parameterized_filter(self):
        sql, params = build_personalized_search_query(" 12 ")
        self.assertIn("m.id_mascota = %s", sql)
        self.assertNotIn("p.nombre LIKE %s", sql)
        self.assertNotIn("m.nombre LIKE %s", sql)
        self.assertNotIn("DATE(c.fecha_hora) = %s", sql)
        self.assertEqual(params, (12,))

    def test_search_rejects_non_numeric_or_non_positive_ids(self):
        for pet_id in ("", "abc", "0", "-1"):
            with self.subTest(pet_id=pet_id), self.assertRaises(ValueError):
                build_personalized_search_query(pet_id)


if __name__ == "__main__":
    unittest.main()
