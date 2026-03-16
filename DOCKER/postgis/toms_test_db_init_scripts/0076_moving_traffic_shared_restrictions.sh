#!/bin/bash
# Moving restrictions inherit from shared restrictions base. Run after 0075.
psql -U postgres -d "TOMs_Test" -a -f "/io/DATAMODEL/0076_moving_traffic_shared_restrictions.sql"
