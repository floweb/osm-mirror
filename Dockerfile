FROM debian:jessie

# Setup everything
# extent (xmin,ymin,xmax,ymax)
ENV EXTENT -167.7,-59.4,194.8,85.1
ENV DB_HOST osm-db
ENV DB_NAME osm
ENV DB_USER osm
ENV DB_PASSWORD osm
ENV OSM_DATA /usr/share/mapnik-osm-data/world_boundaries
ENV STYLES_PATH /etc/mapnik-osm-data/makina
ENV RENDERD_CONF /etc/renderd.conf
ENV PREVIEW_CONF /var/www/conf.js

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

# Load world boundaries data...
RUN mkdir -p $OSM_DATA && \
    rm -rf $OSM_DATA/ne_10m_populated_places_fixed.* && \
    curl -L -o "/tmp/ne_10m_populated_places.zip" "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip" && \
    unzip -qqu /tmp/ne_10m_populated_places.zip -d /tmp && \
    rm /tmp/ne_10m_populated_places.zip && \
    mv /tmp/ne_10m_populated_places.* $OSM_DATA/ && \
    ogr2ogr $OSM_DATA/ne_10m_populated_places_fixed.shp $OSM_DATA/ne_10m_populated_places.shp && \
    
    curl -L -o "/tmp/simplified-land-polygons-complete-3857.zip" "http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip" && \
    unzip -qqu /tmp/simplified-land-polygons-complete-3857.zip simplified-land-polygons-complete-3857/simplified_land_polygons.* -d /tmp && \
    rm /tmp/simplified-land-polygons-complete-3857.zip && \
    mv /tmp/simplified-land-polygons-complete-3857/simplified_land_polygons.* $OSM_DATA/ && \

    curl -L -o "/tmp/land-polygons-split-3857.zip" "http://data.openstreetmapdata.com/land-polygons-split-3857.zip" && \
    unzip -qqu /tmp/land-polygons-split-3857.zip -d /tmp && \
    rm /tmp/land-polygons-split-3857.zip && \
    mv /tmp/land-polygons-split-3857/land_polygons.* $OSM_DATA/ && \

    curl -L -o "/tmp/coastline-good.zip" "http://tilemill-data.s3.amazonaws.com/osm/coastline-good.zip" && \
    unzip -qqu /tmp/coastline-good.zip -d /tmp && \
    rm /tmp/coastline-good.zip && \
    mv /tmp/coastline-good.* $OSM_DATA/ && \

    curl -L -o "/tmp/shoreline_300.tar.bz2" "http://tile.openstreetmap.org/shoreline_300.tar.bz2" && \
    tar -xf /tmp/shoreline_300.tar.bz2 -C /tmp && \
    rm /tmp/shoreline_300.tar.bz2 && \
    mv /tmp/shoreline_300.* $OSM_DATA/ && \
    
    curl -L -o "/tmp/world_boundaries-spherical.tgz" "http://planet.openstreetmap.org/historical-shapefiles/world_boundaries-spherical.tgz" && \
    tar -xf /tmp/world_boundaries-spherical.tgz -C /tmp && \
    rm /tmp/world_boundaries-spherical.tgz && \
    mv /tmp/world_boundaries/builtup_area.* $OSM_DATA/ && \

    curl -L -o "/tmp/ne_110m_admin_0_boundary_lines_land.zip" "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip" && \
    unzip -qqu /tmp/ne_110m_admin_0_boundary_lines_land.zip -d /tmp && \
    rm /tmp/ne_110m_admin_0_boundary_lines_land.zip && \
    mv /tmp/ne_110m_admin_0_boundary_lines_land.* $OSM_DATA/ && \

    curl -L -o "/tmp/10m-land.zip" "http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.3.0/physical/10m-land.zip" && \
    unzip -qqu /tmp/10m-land.zip -d /tmp && \
    rm /tmp/10m-land.zip && \
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

# Deploy preview map...
# RUN rm -rf /var/www/html && cp -R preview/* /var/www/

# Deploy map styles...
# RUN mkdir -p $STYLES_PATH && cp -R styles/* $STYLES_PATH

COPY httpd-foreground /usr/local/bin/

EXPOSE 80

CMD ["httpd-foreground"]
