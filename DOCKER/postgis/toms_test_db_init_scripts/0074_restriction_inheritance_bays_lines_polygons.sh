#!/bin/bash
# Restriction inheritance: Bays/Lines/RestrictionPolygons inherit from Restrictions / LineRestrictions
psql -U postgres -d "TOMs_Test" -a -f "/io/DATAMODEL/0074_restriction_inheritance_bays_lines_polygons.sql"
