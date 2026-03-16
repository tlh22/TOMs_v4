-- Verify shared Restrictions base and inheritance (0074, 0075, 0076).
-- Run with: psql -U postgres -d "TOMs_Test" -f test/data/0075_0076_restrictions_inheritance_check.sql
-- Expect: restrictions."Restrictions" exists; toms."Restrictions" and moving_traffic."Restrictions" inherit from it;
--         toms.Bays, Lines inherit toms."LineRestrictions"; toms.RestrictionPolygons inherits toms."Restrictions".

\set ON_ERROR_STOP on

-- 1) Shared base exists
SELECT 1 AS check_restrictions_schema
FROM pg_namespace
WHERE nspname = 'restrictions';

SELECT 1 AS check_restrictions_table
FROM pg_tables
WHERE schemaname = 'restrictions' AND tablename = 'Restrictions';

-- 2) toms.Restrictions inherits restrictions.Restrictions (static restrictions)
SELECT 1 AS check_toms_inherits_restrictions
FROM pg_inherits i
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_namespace cn ON child.relnamespace = cn.oid
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_namespace pn ON parent.relnamespace = pn.oid
WHERE pn.nspname = 'restrictions' AND parent.relname = 'Restrictions'
  AND cn.nspname = 'toms' AND child.relname = 'Restrictions';

-- 3) toms.LineRestrictions inherits toms.Restrictions
SELECT 1 AS check_line_restrictions_inherits_toms
FROM pg_inherits i
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_namespace pn ON parent.relnamespace = pn.oid
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_namespace cn ON child.relnamespace = cn.oid
WHERE pn.nspname = 'toms' AND parent.relname = 'Restrictions'
  AND cn.nspname = 'toms' AND child.relname = 'LineRestrictions';

-- 4) Bays, Lines inherit toms.LineRestrictions
SELECT 1 AS check_bays_inherits_line_restrictions
FROM pg_inherits i
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_namespace pn ON parent.relnamespace = pn.oid
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_namespace cn ON child.relnamespace = cn.oid
WHERE pn.nspname = 'toms' AND parent.relname = 'LineRestrictions'
  AND cn.nspname = 'toms' AND child.relname = 'Bays';

SELECT 1 AS check_lines_inherits_line_restrictions
FROM pg_inherits i
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_namespace pn ON parent.relnamespace = pn.oid
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_namespace cn ON child.relnamespace = cn.oid
WHERE pn.nspname = 'toms' AND parent.relname = 'LineRestrictions'
  AND cn.nspname = 'toms' AND child.relname = 'Lines';

-- 5) RestrictionPolygons inherits toms.Restrictions
SELECT 1 AS check_restriction_polygons_inherits_toms
FROM pg_inherits i
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_namespace pn ON parent.relnamespace = pn.oid
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_namespace cn ON child.relnamespace = cn.oid
WHERE pn.nspname = 'toms' AND parent.relname = 'Restrictions'
  AND cn.nspname = 'toms' AND child.relname = 'RestrictionPolygons';

-- 6) moving_traffic.Restrictions inherits restrictions.Restrictions (moving restrictions) if 0076 was run
SELECT 1 AS check_moving_traffic_inherits_restrictions
FROM pg_inherits i
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_namespace pn ON parent.relnamespace = pn.oid
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_namespace cn ON child.relnamespace = cn.oid
WHERE pn.nspname = 'restrictions' AND parent.relname = 'Restrictions'
  AND cn.nspname = 'moving_traffic' AND child.relname = 'Restrictions';

-- Summary: list direct children of restrictions."Restrictions"
SELECT cn.nspname AS child_schema, child.relname AS child_table
FROM pg_inherits i
JOIN pg_class child ON i.inhrelid = child.oid
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_namespace pn ON parent.relnamespace = pn.oid
JOIN pg_namespace cn ON child.relnamespace = cn.oid
WHERE pn.nspname = 'restrictions' AND parent.relname = 'Restrictions'
ORDER BY child_schema, child_table;

\echo 'Restrictions inheritance check completed successfully.'
