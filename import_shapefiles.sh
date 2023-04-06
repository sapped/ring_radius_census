#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <shapefile_directory> <db_user> <db_name>"
  exit 1
fi

shapefile_directory=$1
db_user=$2
db_name=$3

# Extract the subdirectories from the path
sub_dirs=$(echo "$shapefile_directory" | cut -d'/' -f3,4)

# Replace the '/' with '_' and store it in a variable
output_table=$(echo "$sub_dirs" | tr '/' '_')

# Make sure shp2pgsql is available
if ! command -v shp2pgsql &>/dev/null; then
  echo "shp2pgsql could not be found. Please install it and try again."
  exit 1
fi

echo "Output table: $output_table"

all_shapefiles=$(find "$shapefile_directory" -name "*.shp")

# echo "CREATE TABLE IF NOT EXISTS ${output_table} (gid serial PRIMARY KEY);" | psql -U $db_user -d $db_name

# Check if the table exists
if psql -U "$db_user" -d "$db_name" -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '${output_table}')"; then
  # If the table exists, drop it
  psql -U "$db_user" -d "$db_name" -c "DROP TABLE IF EXISTS ${output_table};"
fi

first_file=true
for file in $all_shapefiles; do
  # Extract the base name without the extension
  base_name=$(basename "$file" .shp)

  echo "----------"
  echo "$(TZ=America/New_York date '+%H:%M:%S %Y-%m-%d') Importing $file..."
  echo "File size: $(stat -c%s "$file") bytes"
  
  if $first_file; then
    # Create the table based on the first .shp file, but don't import data using the -p flag
    echo "Creating table $output_table based on $file"
    shp2pgsql -I -s 4326 -p -W "latin1" "$file" "$output_table" | psql -U "$db_user" -d "$db_name" > /dev/null
    first_file=false
  fi

  # Import the shapefile into the database, using the -a option flag
  shp2pgsql -I -s 4326 -a "$file" "$output_table" | psql -U "$db_user" -d "$db_name" > /dev/null
done

echo "Finished importing shapefiles."