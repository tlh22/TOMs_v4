--
-- Moving restrictions (schema moving_traffic) inherit from shared restrictions."Restrictions".
-- Logical name: "Moving restrictions" = schema moving_traffic.
-- RestrictionID in moving_traffic changes from uuid to varchar(254) to match the shared base.
-- Run after 0075. Requires 0016 (CreateDateTime/CreatePerson on moving_traffic.Restrictions) and 0014b if used.
--

-- =============================================================================
-- 1. Change RestrictionID to varchar(254) so moving_traffic."Restrictions" can inherit
-- =============================================================================

ALTER TABLE moving_traffic."Restrictions"
    ALTER COLUMN "RestrictionID" TYPE character varying(254) USING "RestrictionID"::text;


-- =============================================================================
-- 2. Make moving_traffic."Restrictions" inherit shared base (Moving restrictions)
-- =============================================================================

ALTER TABLE moving_traffic."Restrictions" INHERIT restrictions."Restrictions";


-- =============================================================================
-- 3. Prevent direct insert into moving_traffic."Restrictions"
-- =============================================================================

CREATE OR REPLACE FUNCTION moving_traffic."prevent_insert_restrictions_base"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Do not insert into moving_traffic."Restrictions" (Moving restrictions). Use AccessRestrictions, CarriagewayMarkings, etc.';
END;
$$;

ALTER FUNCTION moving_traffic."prevent_insert_restrictions_base"() OWNER TO postgres;

DROP TRIGGER IF EXISTS "prevent_insert_restrictions" ON moving_traffic."Restrictions";
CREATE TRIGGER "prevent_insert_restrictions"
    BEFORE INSERT ON moving_traffic."Restrictions"
    FOR EACH ROW EXECUTE FUNCTION moving_traffic."prevent_insert_restrictions_base"();
