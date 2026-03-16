# coding=utf-8
"""Tests for shared Restrictions inheritance (0074, 0075, 0076).

Static restrictions (toms): Bays, Lines, RestrictionPolygons inherit from toms.Restrictions / LineRestrictions.
Moving restrictions (moving_traffic): AccessRestrictions, etc. inherit from moving_traffic.Restrictions.
Both toms.Restrictions and moving_traffic.Restrictions inherit from restrictions.Restrictions (shared base).

Run with pytest. Requires TOMs_Test DB with migrations 0074, 0075 (and 0076 for moving_traffic) applied.
Set PGSERVICE or connection params if not using default.
"""

from __future__ import absolute_import

import os
import unittest

try:
    import psycopg2
    from psycopg2 import sql
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False


def get_connection():
    """Connect using PGSERVICE or env vars."""
    if os.environ.get("PGSERVICE"):
        return psycopg2.connect(service=os.environ["PGSERVICE"], dbname="TOMs_Test")
    dbname = os.environ.get("PGDATABASE", "TOMs_Test")
    host = os.environ.get("PGHOST", "localhost")
    port = os.environ.get("PGPORT", "5435")
    user = os.environ.get("PGUSER", "postgres")
    password = os.environ.get("PGPASSWORD", "postgis")
    return psycopg2.connect(
        dbname=dbname, host=host, port=port, user=user, password=password
    )


@unittest.skipUnless(HAS_PSYCOPG2, "psycopg2 not installed")
class TestRestrictionsInheritance(unittest.TestCase):
    """Verify restrictions schema and inheritance structure."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.conn = get_connection()
        except Exception as e:
            raise unittest.SkipTest("Cannot connect to TOMs_Test: %s" % e)

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, "conn") and cls.conn:
            cls.conn.close()

    def test_restrictions_schema_exists(self):
        with self.conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM pg_namespace WHERE nspname = %s", ("restrictions",)
            )
            self.assertIsNotNone(cur.fetchone(), "Schema restrictions should exist")

    def test_restrictions_base_table_exists(self):
        with self.conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM pg_tables WHERE schemaname = %s AND tablename = %s",
                ("restrictions", "Restrictions"),
            )
            self.assertIsNotNone(cur.fetchone(), "restrictions.Restrictions should exist")

    def test_toms_restrictions_inherits_shared_base(self):
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT 1 FROM pg_inherits i
                JOIN pg_class parent ON i.inhparent = parent.oid
                JOIN pg_namespace pn ON parent.relnamespace = pn.oid
                WHERE pn.nspname = 'restrictions' AND parent.relname = 'Restrictions'
                  AND i.inhrelid = 'toms."Restrictions"'::regclass
            """)
            self.assertIsNotNone(cur.fetchone(), "toms.Restrictions should inherit restrictions.Restrictions")

    def test_bays_inherits_line_restrictions(self):
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT 1 FROM pg_inherits i
                WHERE i.inhparent = 'toms."LineRestrictions"'::regclass
                  AND i.inhrelid = 'toms."Bays"'::regclass
            """)
            self.assertIsNotNone(cur.fetchone(), "toms.Bays should inherit toms.LineRestrictions")

    def test_lines_inherits_line_restrictions(self):
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT 1 FROM pg_inherits i
                WHERE i.inhparent = 'toms."LineRestrictions"'::regclass
                  AND i.inhrelid = 'toms."Lines"'::regclass
            """)
            self.assertIsNotNone(cur.fetchone(), "toms.Lines should inherit toms.LineRestrictions")

    def test_restriction_polygons_inherits_toms_restrictions(self):
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT 1 FROM pg_inherits i
                WHERE i.inhparent = 'toms."Restrictions"'::regclass
                  AND i.inhrelid = 'toms."RestrictionPolygons"'::regclass
            """)
            self.assertIsNotNone(cur.fetchone(), "toms.RestrictionPolygons should inherit toms.Restrictions")

    def test_moving_traffic_restrictions_inherits_shared_base(self):
        """Requires 0076. Skip if moving_traffic.Restrictions does not inherit restrictions.Restrictions."""
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT 1 FROM pg_inherits i
                JOIN pg_class parent ON i.inhparent = parent.oid
                JOIN pg_namespace pn ON parent.relnamespace = pn.oid
                WHERE pn.nspname = 'restrictions' AND parent.relname = 'Restrictions'
                  AND i.inhrelid = 'moving_traffic."Restrictions"'::regclass
            """)
            row = cur.fetchone()
            if row is None:
                self.skipTest("0076 not applied: moving_traffic.Restrictions does not inherit restrictions.Restrictions")
            self.assertIsNotNone(row)
