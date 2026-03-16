#!/bin/bash
# One shared Restrictions base for static (toms) and moving (moving_traffic). Run after 0074.
psql -U postgres -d "TOMs_Test" -a -f "/io/DATAMODEL/0075_shared_restrictions_base.sql"
