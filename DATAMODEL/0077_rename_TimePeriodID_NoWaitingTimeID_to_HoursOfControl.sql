/**
 * Rename columns to unified name HoursOfControl:
 * - Bays: TimePeriodID → HoursOfControl
 * - Lines: NoWaitingTimeID → HoursOfControl
 * - RestrictionPolygons: TimePeriodID → HoursOfControl
 * (RestrictionPolygons.NoWaitingTimeID is unchanged.)
 */

-- Bays
ALTER TABLE toms."Bays" RENAME COLUMN "TimePeriodID" TO "HoursOfControl";

-- Lines
ALTER TABLE toms."Lines" RENAME COLUMN "NoWaitingTimeID" TO "HoursOfControl";

-- RestrictionPolygons (only TimePeriodID; NoWaitingTimeID unchanged)
ALTER TABLE toms."RestrictionPolygons" RENAME COLUMN "TimePeriodID" TO "HoursOfControl";

-- Update FK constraint names to match (optional; run if constraint names exist as below)
-- ALTER TABLE toms."Bays" RENAME CONSTRAINT "Bays_TimePeriodID_fkey" TO "Bays_HoursOfControl_fkey";
-- ALTER TABLE toms."Lines" RENAME CONSTRAINT "Lines_NoWaitingTimeID_fkey" TO "Lines_HoursOfControl_fkey";
-- ALTER TABLE toms."RestrictionPolygons" RENAME CONSTRAINT "RestrictionsPolygons_TimePeriodID_fkey" TO "RestrictionsPolygons_HoursOfControl_fkey";
