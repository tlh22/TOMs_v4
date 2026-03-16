--
-- One shared "Restrictions" base for both:
--   Static restrictions (schema toms): Bays, Lines, RestrictionPolygons, etc.
--   Moving restrictions (schema moving_traffic): AccessRestrictions, CarriagewayMarkings, etc.
--
-- Naming: "Static restrictions" = toms, "Moving restrictions" = moving_traffic.
-- Run after 0074 (which creates toms."Restrictions" and attaches Bays/Lines/RestrictionPolygons).
-- Schema "restrictions" holds the single base table; toms."Restrictions" (Static) inherits from it.
-- moving_traffic (Moving) migration to same base is in 0076 (RestrictionID uuid→varchar).
--

-- =============================================================================
-- 1. Create schema and shared base table (columns common to toms + moving_traffic)
--    RestrictionID varchar(254) so both schemas can use it (moving_traffic uses uuid→varchar in 0076).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS restrictions;
ALTER SCHEMA restrictions OWNER TO postgres;

CREATE TABLE restrictions."Restrictions" (
    "RestrictionID" character varying(254) COLLATE pg_catalog."default" NOT NULL,
    "GeometryID" character varying(12) COLLATE pg_catalog."default" NOT NULL,
    "Notes" character varying(254) COLLATE pg_catalog."default",
    "Photos_01" character varying(255) COLLATE pg_catalog."default",
    "Photos_02" character varying(255) COLLATE pg_catalog."default",
    "Photos_03" character varying(255) COLLATE pg_catalog."default",
    "RoadName" character varying(254) COLLATE pg_catalog."default",
    "USRN" character varying(254) COLLATE pg_catalog."default",
    "label_Rotation" double precision,
    "label_TextChanged" character varying(254) COLLATE pg_catalog."default",
    "OpenDate" date,
    "CloseDate" date,
    "LastUpdateDateTime" timestamp without time zone NOT NULL,
    "LastUpdatePerson" character varying(255) COLLATE pg_catalog."default" NOT NULL,
    "ComplianceRoadMarkingsFaded" integer,
    "ComplianceRestrictionSignIssue" integer,
    "ComplianceNotes" character varying(254) COLLATE pg_catalog."default",
    "MHTC_CheckIssueTypeID" integer,
    "MHTC_CheckNotes" character varying(254) COLLATE pg_catalog."default",
    "CreateDateTime" timestamp without time zone NOT NULL,
    "CreatePerson" character varying(255) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT "Restrictions_pkey" PRIMARY KEY ("RestrictionID")
)
TABLESPACE pg_default;

ALTER TABLE restrictions."Restrictions" OWNER TO postgres;

COMMENT ON SCHEMA restrictions IS 'Shared base for Static restrictions (toms) and Moving restrictions (moving_traffic).';
COMMENT ON TABLE restrictions."Restrictions" IS 'Single base table for all restrictions. Do not insert; use Static (toms) or Moving (moving_traffic) child tables.';


-- =============================================================================
-- 2. Make toms."Restrictions" inherit from shared base (Static restrictions)
-- =============================================================================

ALTER TABLE toms."Restrictions" INHERIT restrictions."Restrictions";


-- =============================================================================
-- 3. Prevent direct insert into shared base
-- =============================================================================

CREATE OR REPLACE FUNCTION restrictions."prevent_insert_restrictions_base"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Do not insert into restrictions."Restrictions". Use Static (toms) or Moving (moving_traffic) child tables.';
END;
$$;

ALTER FUNCTION restrictions."prevent_insert_restrictions_base"() OWNER TO postgres;

CREATE TRIGGER "prevent_insert_restrictions"
    BEFORE INSERT ON restrictions."Restrictions"
    FOR EACH ROW EXECUTE FUNCTION restrictions."prevent_insert_restrictions_base"();


-- =============================================================================
-- 4. Grants on shared base
-- =============================================================================

REVOKE ALL ON TABLE restrictions."Restrictions" FROM toms_public;
GRANT ALL ON TABLE restrictions."Restrictions" TO postgres;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE restrictions."Restrictions" TO toms_admin;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE restrictions."Restrictions" TO toms_operator;
GRANT SELECT ON TABLE restrictions."Restrictions" TO toms_public;

GRANT USAGE ON SCHEMA restrictions TO postgres, toms_admin, toms_operator, toms_public;
