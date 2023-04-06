RENAME THE FOLDER FROM census_db to census_ring_radius

# Download the Census Data from ftp.census.gov
- I coded this on a Macbook Air, I needed to [install FTP on mac OS](https://apple.stackexchange.com/questions/320781/missing-ftp-command-line-tool-on-macos) using `brew install inetutils`
- Ran into some frustration with CLI FTP early on, so I switched and used FileZilla instead
- Looks like the Census provides a [Web Interface](https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.2021.html#list-tab-790442341), though I didn't test that out
- You can translate the FTP instructions in this [seminal tutorial by Will Cadell](https://sparkgeo.com/blog/building-a-us-census-tracts-postgis-database/) to get FTP working with FileZilla, or with your CLI FTP client should you choose that route
- That tutorial relied on the Tract-level data. However, I'm focusing on block group data (most granular)
- So the folder I want to locate from the Census Bureau's ftp.census.gov is located in [geo/tiger/TIGER2021/TABBLOCK20](https://www2.census.gov/geo/tiger/TIGER2021/TABBLOCK20/). I know this because I looked at the [definitions file](https://www2.census.gov/geo/tiger/TIGER2021/2021_TL_Shapefiles_File_Name_Definitions.pdf) from the [TIGER2021 directory](https://www2.census.gov/geo/tiger/TIGER2021/)
- I will match the census bureau's folder hierarchy in my source code, so this will all go in shapefiles/TIGER2021/TABBLOCK20. Go ahead and move into this directory. Once it's all downloaded via FTP (could take a bit, since the files are pretty large), unzip everything 

```sh
  unzip \*.zip
```

- The above command is for Mac OS, where you need to escape the *. On Linux, I believe you just remove the '\' from teh above command
- Feel free to delete all the ZIP files once they're all unzipped. On Mac OS, I did this in the directory with

```sh
  find . -type f -name "*.zip" -delete
```

# Spin up the PostGIS Database
- I've already built the docker-compose file for you. Note, I needed to specify the `platform: linux/amd64` under the `db:` service so I could get this to work on my Macbook Air
- Move to the project top directory (where you see the docker-compose.yml file) and type `docker-compose up --build`. You can add an optional -d flag to print log in the background and not in the terminal, but I like seeing the logs in my terminal so I don't type in the -d flag.
- (DEPRECATED, DELETE THIS BULLET IN FINAL VERSION) I'm going to mess around with the Postgres container using Jetbrains DataGrip's free trial. I might pay for it if it's nice, I've had a few colleagues recommend it. I followed [this tutorial](https://www.jetbrains.com/help/datagrip/docker.html)

# Feed the Data into the PostGIS Database
- We will do these steps in pgadmin. If you need help configuring pgdamin, review [this tutorial](https://towardsdatascience.com/how-to-run-postgresql-and-pgadmin-using-docker-3a6a8ae918b5)
- Access pgadmin at: http://localhost:5050/, use the credentials in the docker-compose.yml file
- Click add new server
    - Start on Tab General
    - Name: census_db
    - Move to Tab Connection
    - Host name / address: postgis_container
    - Enter the POSTGRES_USER and POSTGRES_PASSWORD fields from the docker-compose.yml file
    - Click Save, you're in
- You should see the database is empty
- Now, let's import shapefiles using the bash script `import_shapefiles.sh` in the main directory
- It's worth personally reviewing that import_shapefiles.sh script, but skip it if you're in a rush
- Unless you've changed the shapefile directory or PG user / password credentials, you should be good to just use this command without modifying anything to run import_shapefiles.sh:

```sh
docker exec -it postgis_container bash -c "./import_shapefiles.sh '/shapefiles/TIGER2021/TABBLOCK20' postgres census_db"
```
Alternative command if you want to run it at the tract level (assuming you followed the above steps, but for the TRACT dataset)
```sh
docker exec -it postgis_container bash -c "./import_shapefiles.sh '/shapefiles/TIGER2021/TRACT' postgres census_db"
```

- This command will create a table named tiger2021_tabblock20, or delete it if it exists then recreate it, using all the files in the directory you mentioned
- FYI: If you want to import other census shapefiles (like, for Tracts instead of Blocks), the bash script will basically just use the folder structure to name the directory. In that specific case, you would just make sure to save the [tract data from here](https://www2.census.gov/geo/tiger/TIGER2021/TRACT/) down into ./shapefiles/TIGER2021/TRACT
- I ran this import bash script on my Macbook Air (16GB RAM / Apple M2 Chip) and it took about 2 hours

# Visualize the Tract and Block Shapefiles on geojson.io
- Now, let's quickly visualize the shapefiles we just imported to make sure everything went smoothly:
- This SQL query will visulize the block-level data for 1,000 random census blocks in California (statefp20='06'). Copy-paste the JSON object this query creates into the right-side half of geojson.io:

```SQL
  SELECT
    json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(
        json_build_object(
          'type', 'Feature',
          'geometry', t.geometry,
          'properties', json_build_object(
			  'gid', t.gid,
			  'statefp', t.statefp20,
			  'countyfp', t.countyfp20,
			  'name', t.name20,
			  'centroid', t.centroid
		  )
        )
      )
    )
FROM
    (
      SELECT ST_AsGeoJSON(geom)::json AS geometry,
		geom,
		gid,
		statefp20,
		countyfp20,
		name20,
		centroid
      FROM tiger2021_tabblock20
      WHERE statefp20 = '06'
	  LIMIT 1000
    ) AS t

```

- This SQL query will visulize all the tract-level data for all of Rhode Island (statefp='44')
- Once you have the geojson, just paste it into geojson.io

```SQL
  SELECT
    json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(
        json_build_object(
          'type', 'Feature',
          'geometry', t.geometry,
          'properties', json_build_object(
			  'gid', t.gid,
			  'statefp', t.statefp,
			  'countyfp', t.countyfp,
			  'name', t.name,
			  'namelsad', t.namelsad,
		  )
        )
      )
    )
FROM
    (
      SELECT ST_AsGeoJSON(geom)::json AS geometry,
		geom,
		gid,
		statefp,
		countyfp,
		name,
		namelsad,
      FROM tiger2021_tract
      WHERE statefp = '44'
      LIMIT 1000
    ) AS t
```

- Note how we pull in additional columns as "properties". This can be super helpful later on when associating various pieces of information with each geometry for our visualizations
- [This tutorial](https://www.flother.is/til/postgis-geojson/) was helpful in learning to generate geojson from PostGIS
- Copy-paste the JSON object that creates into the right-side half of geojson.io
- You should see your blocks / tracts visualized nicely!

# Creating Centroid Column
- Now create the centroid column in your dataset. Let's do the tracts first, which we can do in just one basic query. We'll use a more advanced query for the blocks in just a moment. FYT, this took ~5mins to run on my Macbook Air M2:
```sql
  ALTER TABLE tiger2021_tract ADD COLUMN centroid geometry(POINT, 4326);
  UPDATE tiger2021_tract SET centroid = ST_Centroid(geom);
```

- And let's just create a blank centroid column on the tiger2021_tabblock20 dataset:
```sql
  ALTER TABLE tiger2021_tabblock20 ADD COLUMN centroid geometry(POINT, 4326);
```

- Let's index our two datasets on columns we plan on frequently querying (optional performance step):
```sql
  CREATE INDEX idx_tiger2021_tabblock20_statefp20_countyfp20_centroid ON tiger2021_tabblock20 (statefp20, countyfp20, centroid);
```

- And also for the tract dataset:
```sql
  CREATE INDEX idx_tiger2021_tract_statefp_countyfp_centroid ON tiger2021_tract (statefp, countyfp, centroid);
```

- And now let's add centroids on our tiger2021_tabblock20 dataset. The code below uses batches to loop through the dataset, because the single query required 2:27:08.121 to run on my Macbook Air M2. You may want to modify the batch_size for your particular machine:
```sql
  DO $$
DECLARE
  updated_rows INTEGER := 1;
  batch_size INTEGER := 1000; -- Adjust the batch size to a suitable value based on your system's resources
  BEGIN
    WHILE updated_rows > 0
    LOOP
      UPDATE tiger2021_tabblock20
      SET centroid = ST_Centroid(geom)
      WHERE gid IN (
        SELECT gid FROM tiger2021_tabblock20
        WHERE centroid IS NULL
        LIMIT batch_size
      );
      
      GET DIAGNOSTICS updated_rows = ROW_COUNT;
      COMMIT;
      PERFORM pg_sleep(1); -- Optional: Sleep for 1 second between batches to reduce system load
    END LOOP;
  END $$;
```

- You can keep following this tutorial while that long query runs, I'll include some workarounds so your queries still pull helpful data while your ~8M tabblock20 centroids populate
- ! Flag this as a TBU - bake this into the import_shapefiles.sh logic.

# Visualize Centroids and Shapefiles
- Now, let's sample a few tracts and blocks to visually confirm the centroids we generated are correct
- First, let's find a county where all our centroids have been updated while we wait for all the SQL batches to finish

```sql
  SELECT tractce20, countyfp20, statefp20
  FROM tiger2021_tabblock20
  GROUP BY tractce20, countyfp20, statefp20
  HAVING COUNT(*) = COUNT(centroid)
  LIMIT 10;
```
- My query returned countyfp20='005' and satefp20='04'
- Run this code to generate the geojson output for the Tracts (larger areas, faster dataset), but this time include points for each centroid
```sql
  SELECT
    json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(
        json_build_object(
          'type', 'Feature',
          'geometry', t.geometry,
          'properties', json_build_object(
			  'gid', t.gid,
			  'statefp', t.statefp,
			  'countyfp', t.countyfp,
        'tractce', t.tractce,
			  'name', t.name,
			  'namelsad', t.namelsad,
			  'centroid', t.centroid
		  )
        )
      )
    )
FROM
    (
      SELECT ST_AsGeoJSON(geom)::json AS geometry,
		geom,
		gid,
		statefp,
		countyfp,
    tractce,
		name,
		namelsad,
		centroid
      FROM tiger2021_tract
      WHERE countyfp = '005'
      AND statefp='04'
		
	  UNION ALL
	  
	  SELECT ST_AsGeoJSON(centroid)::json AS geometry,
		geom,
		gid,
		statefp,
		countyfp,
    tractce,
		name,
		namelsad,
		centroid
      FROM tiger2021_tract
      WHERE countyfp = '005'
      AND statefp = '04'
    ) AS t
```

- Now let's zoom into the blocks for one of the tracts in that dataset, specifically block '000100':
```sql
  SELECT
    json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(
        json_build_object(
          'type', 'Feature',
          'geometry', t.geometry,
          'properties', json_build_object(
			  'gid', t.gid,
			  'statefp20', t.statefp20,
			  'countyfp20', t.countyfp20,
			  'tractce20', t.tractce20,
			  'name20', t.name20,
			  'centroid', t.centroid
		  )
        )
      )
    )
FROM
    (
      SELECT ST_AsGeoJSON(geom)::json AS geometry,
		geom,
		gid,
		statefp20,
		countyfp20,
    tractce20,
		name20,
		centroid
      FROM tiger2021_tabblock20
	  WHERE countyfp20 = '005'
      AND statefp20 ='04'
	  AND tractce20 = '000100'
		
	  UNION ALL
	  
	  SELECT ST_AsGeoJSON(centroid)::json AS geometry,
		geom,
		gid,
		statefp20,
		countyfp20,
    tractce20,
		name20,
		centroid
      FROM tiger2021_tabblock20
	  WHERE countyfp20 = '005'
      AND statefp20 ='04'
	  AND tractce20 = '000100'
    ) AS t
```

# Confirm all Centroids Generated
- It will take quite some time for your machine to generate all of the centroids on the tiger2021_tabblock20 dataset. On my Macbook Air M2 with 16GB RAM, the process took ~10 hours.

Once it's finished, though, let's just confirm that you have no null entries in your tiger2021_tract or tiger2021_tabblock20 datasets
- The query below for tiger2021_tabblock20 ran for 34 seconds before returning data on my laptop. You can just alter the table name to 'tiger2021_tract' in the query below to also check that dataset:

```sql
  SELECT 
    COUNT(*) FILTER (WHERE centroid IS NULL) AS null_centroids,
    COUNT(*) FILTER (WHERE centroid IS NOT NULL) AS not_null_centroids
  FROM tiger2021_tabblock20;
```

# Download the actual Demographic Data

# Build API that Performs Ring Radius Analysis at block level