#!/bin/bash

PARENT_DIR="./acs_summary_file/2021/sequence-based-SF/5_year_entire_sf"
YEAR=2021
DATABASE_NAME="census_db"
USERNAME="postgres"
PASSWORD="postgres"
HOST="postgis_container"
PORT="5432"

# Function to import data from a text file into the PostGIS database
import_data() {
    local table_name="$1"
    local filepath="$2"
    echo "Importing $filepath into $table_name ..."
    PGPASSWORD="$PASSWORD" psql -U "$USERNAME" -h "$HOST" -p "$PORT" -d "$DATABASE_NAME" -c "\COPY $table_name FROM '$filepath' WITH (FORMAT csv, HEADER, DELIMITER E'\t');"
}

# Find direct child subdirectories of the input parent directory and store them in a variable
child_dirs=$(find "$PARENT_DIR" -maxdepth 1 -mindepth 1 -type d)

# Loop through directories and files
for dir in $child_dirs; do
    if [ -d "$dir" ]; then
        # Get the directory name and append the YEAR variable to create the table name
        dir_name=$(basename "$dir")
        table_name="${dir_name}_${YEAR}"
        
        for file in "$dir"/*.txt; do
            import_data "$table_name" "$file"
        done
    fi
done