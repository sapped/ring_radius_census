FROM postgis/postgis

RUN apt-get update && \
    apt-get install -y postgis && \
    rm -rf /var/lib/apt/lists/*

COPY import_shapefiles.sh /import_shapefiles.sh
COPY import_acs5_sf.sh /import_acs5_sf.sh

RUN chmod +x /import_shapefiles.sh
RUN chmod +x /import_acs5_sf.sh