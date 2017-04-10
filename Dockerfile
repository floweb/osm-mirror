FROM debian:jessie

# Setup everything
ENV EXTENT
ENV DB_HOST osm-db
ENV DB_NAME osm
ENV DB_USER osm
ENV DB_PASSWORD osm
ENV OSM_DATA /usr/share/mapnik-osm-data/world_boundaries

# Install deps
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y git curl wget libgdal1h gdal-bin mapnik-utils unzip \
    apache2 dpkg-dev debhelper apache2-dev \
    libmapnik-dev autoconf automake m4 libtool libcurl4-gnutls-dev \
    libcairo2-dev apache2-mpm-event && rm -rf /var/lib/apt/lists/*

# Install software
RUN git clone --recursive --depth=50 https://github.com/floweb/osm-mirror && \
    git clone https://github.com/makinacorpus/mod_tile && \
    cd mod_tile && dpkg-buildpackage && cd .. && \
    dpkg -i renderd_0.4.1_amd64.deb && \
    dpkg -i libapache2-mod-tile_0.4.1_amd64.deb

RUN mkdir -p $OSM_DATA && \
   rm -rf $OSM_DATA/ne_10m_populated_places_fixed.* && \
    zipfile=/tmp/ne_10m_populated_places.zip && \
    curl -L -o "$zipfile" "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip" && \
    unzip -qqu $zipfile -d /tmp && \
    rm $zipfile && \
    mv /tmp/ne_10m_populated_places.* $OSM_DATA/ && \
    ogr2ogr $OSM_DATA/ne_10m_populated_places_fixed.shp $OSM_DATA/ne_10m_populated_places.shp && \
    
    zipfile=/tmp/simplified-land-polygons-complete-3857.zip && \
    curl -L -o "$zipfile" "http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip" && \
    unzip -qqu $zipfile simplified-land-polygons-complete-3857/simplified_land_polygons.{shp,shx,prj,dbf,cpg} -d /tmp && \
    rm $zipfile && \
    mv /tmp/simplified-land-polygons-complete-3857/simplified_land_polygons.* $OSM_DATA/ && \

    zipfile=/tmp/land-polygons-split-3857.zip && \
    curl -L -o "$zipfile" "http://data.openstreetmapdata.com/land-polygons-split-3857.zip" && \
    unzip -qqu $zipfile -d /tmp && \
    rm $zipfile && \
    mv /tmp/land-polygons-split-3857/land_polygons.* $OSM_DATA/ && \

    zipfile=/tmp/coastline-good.zip && \
    curl -L -o "$zipfile" "http://tilemill-data.s3.amazonaws.com/osm/coastline-good.zip" && \
    unzip -qqu $zipfile -d /tmp && \
    rm $zipfile && \
    mv /tmp/coastline-good.* $OSM_DATA/ && \

    tarfile=/tmp/shoreline_300.tar.bz2 && \
    curl -L -o "$tarfile" "http://tile.openstreetmap.org/shoreline_300.tar.bz2" && \
    tar -xf $tarfile -C /tmp && \
    rm $tarfile && \
    mv /tmp/shoreline_300.* $OSM_DATA/ && \
    
    tarfile=/tmp/world_boundaries-spherical.tgz && \
    curl -L -o "$tarfile" "http://planet.openstreetmap.org/historical-shapefiles/world_boundaries-spherical.tgz" && \
    tar -xf $tarfile -C /tmp && \
    rm $tarfile && \
    mv /tmp/world_boundaries/builtup_area.* $OSM_DATA/ && \

    zipfile=/tmp/ne_110m_admin_0_boundary_lines_land.zip && \
    curl -L -o "$zipfile" "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip" && \
    unzip -qqu $zipfile -d /tmp && \
    rm $zipfile && \
    mv /tmp/ne_110m_admin_0_boundary_lines_land.* $OSM_DATA/ && \

    zipfile=/tmp/10m-land.zip && \
    curl -L -o "$zipfile" "http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.3.0/physical/10m-land.zip" && \
    unzip -qqu $zipfile -d /tmp && \
    rm $zipfile && \
    mv /tmp/10m-land.* $OSM_DATA/

RUN shapeindex --shape_files \
    $OSM_DATA/simplified_land_polygons.shp \
    $OSM_DATA/land_polygons.shp \
    $OSM_DATA/coastline-good.shp \
    $OSM_DATA/10m-land.shp \
    $OSM_DATA/shoreline_300.shp \
    $OSM_DATA/ne_10m_populated_places_fixed.shp \
    $OSM_DATA/builtup_area.shp \
    $OSM_DATA/ne_110m_admin_0_boundary_lines_land.shp

RUN rm -rf /var/www/html && cp -R preview/* /var/www/

RUN update-data.sh && update-conf.sh