--
-- Static restrictions (schema toms): restriction inheritance for Bays, Lines, RestrictionPolygons.
-- Logical name: "Static restrictions" = schema toms.
-- Existing tables toms."Bays", toms."Lines", toms."RestrictionPolygons" inherit from the restriction
-- table(s) defined here. We do NOT create new Bays/Lines/RestrictionPolygons; we create only the
-- parent table(s) and attach the existing tables via ALTER TABLE ... INHERIT.
--
-- Structure:
--   toms."Restrictions"        = common columns for Bays, Lines, RestrictionPolygons (only common columns).
--   toms."LineRestrictions"    = INHERITS Restrictions; adds geom (LineString), RestrictionLength, AzimuthToRoadCentreLine (Bays + Lines only).
--   toms."Bays"                = existing table → INHERIT LineRestrictions.
--   toms."Lines"               = existing table → INHERIT LineRestrictions.
--   toms."RestrictionPolygons" = existing table → INHERIT Restrictions.
--
-- Run order: run after Bays, Lines, RestrictionPolygons (and their triggers, indexes, FKs) already exist.
-- Existing triggers, constraints, indexes and FKs on Bays, Lines, RestrictionPolygons are unchanged.
--

-- =============================================================================
-- 1. Create parent table toms."Restrictions" (common columns only)
--    Column names and types must match existing Bays, Lines, RestrictionPolygons.
-- =============================================================================

CREATE TABLE toms."Restrictions" (
    "RestrictionID" character varying(254) COLLATE pg_catalog."default" NOT NULL,
    "GeometryID" character varying(12) COLLATE pg_catalog."default" NOT NULL,
    "RestrictionTypeID" integer NOT NULL,
    "GeomShapeID" integer NOT NULL,
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
    "CPZ" character varying(40) COLLATE pg_catalog."default",
    "LastUpdateDateTime" timestamp without time zone NOT NULL,
    "LastUpdatePerson" character varying(255) COLLATE pg_catalog."default" NOT NULL,
    "ComplianceRoadMarkingsFaded" integer,
    "ComplianceRestrictionSignIssue" integer,
    "ComplianceNotes" character varying(254) COLLATE pg_catalog."default",
    "MHTC_CheckIssueTypeID" integer,
    "MHTC_CheckNotes" character varying(254) COLLATE pg_catalog."default",
    "CreateDateTime" timestamp without time zone NOT NULL,
    "CreatePerson" character varying(255) COLLATE pg_catalog."default" NOT NULL,
    "label_pos" geometry(MultiPoint,27700),
    "label_ldr" geometry(MultiLineString,27700),
    "MatchDayEventDayZone" character varying(40) COLLATE pg_catalog."default",
    "MatchDayTimePeriodID" integer,
    "DisplayLabel" boolean NOT NULL DEFAULT true,
    CONSTRAINT "Restrictions_pkey" PRIMARY KEY ("RestrictionID")
)
TABLESPACE pg_default;

ALTER TABLE toms."Restrictions" OWNER TO postgres;

COMMENT ON TABLE toms."Restrictions" IS 'Static restrictions: parent table for TOM restriction geometry. Only columns common to Bays, Lines and RestrictionPolygons. Do not insert; use toms."Bays", toms."Lines", or toms."RestrictionPolygons".';


-- =============================================================================
-- 2. Create toms."LineRestrictions" (common to Bays and Lines only)
-- =============================================================================

CREATE TABLE toms."LineRestrictions" (
    "geom" geometry(LineString,27700) NOT NULL,
    "RestrictionLength" double precision NOT NULL,
    "AzimuthToRoadCentreLine" double precision
)
INHERITS (toms."Restrictions")
TABLESPACE pg_default;

ALTER TABLE toms."LineRestrictions" OWNER TO postgres;

COMMENT ON TABLE toms."LineRestrictions" IS 'Static restrictions: parent for line-based restrictions. Do not insert; use toms."Bays" or toms."Lines".';


-- =============================================================================
-- 3. Attach existing Bays, Lines, RestrictionPolygons to the restriction table(s)
--    Existing tables keep all their columns, triggers, constraints, indexes, FKs.
-- =============================================================================

ALTER TABLE toms."Bays" INHERIT toms."LineRestrictions";
ALTER TABLE toms."Lines" INHERIT toms."LineRestrictions";
ALTER TABLE toms."RestrictionPolygons" INHERIT toms."Restrictions";


-- =============================================================================
-- 4. Prevent direct insert into parent tables
-- =============================================================================

CREATE OR REPLACE FUNCTION toms."prevent_insert_restrictions_base"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Do not insert into %. Use toms."Bays", toms."Lines", or toms."RestrictionPolygons".', TG_TABLE_NAME;
END;
$$;

CREATE OR REPLACE FUNCTION toms."prevent_insert_line_restrictions_base"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Do not insert into %. Use toms."Bays" or toms."Lines".', TG_TABLE_NAME;
END;
$$;

ALTER FUNCTION toms."prevent_insert_restrictions_base"() OWNER TO postgres;
ALTER FUNCTION toms."prevent_insert_line_restrictions_base"() OWNER TO postgres;

CREATE TRIGGER "prevent_insert_restrictions"
    BEFORE INSERT ON toms."Restrictions"
    FOR EACH ROW EXECUTE FUNCTION toms."prevent_insert_restrictions_base"();

CREATE TRIGGER "prevent_insert_line_restrictions"
    BEFORE INSERT ON toms."LineRestrictions"
    FOR EACH ROW EXECUTE FUNCTION toms."prevent_insert_line_restrictions_base"();


-- =============================================================================
-- 5. Grants on parent tables (align with existing Bays/Lines/RestrictionPolygons)
-- =============================================================================

REVOKE ALL ON TABLE toms."Restrictions" FROM toms_public;
GRANT ALL ON TABLE toms."Restrictions" TO postgres;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE toms."Restrictions" TO toms_admin;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE toms."Restrictions" TO toms_operator;
GRANT SELECT ON TABLE toms."Restrictions" TO toms_public;

REVOKE ALL ON TABLE toms."LineRestrictions" FROM toms_public;
GRANT ALL ON TABLE toms."LineRestrictions" TO postgres;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE toms."LineRestrictions" TO toms_admin;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE toms."LineRestrictions" TO toms_operator;
GRANT SELECT ON TABLE toms."LineRestrictions" TO toms_public;
