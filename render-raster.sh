#!/usr/bin/env python
import os
import math
import re
import logging
import optparse
import urllib

try:
    from mapnik import *
except ImportError:
    from mapnik2 import *


OSM_MIRROR_CONF = '/etc/default/openstreetmap-conf'


"""

    Configuration

    Read from command-line arguments, with defaults coming from OSM_MIRROR_CONF

"""

def readconf():
    config = open(OSM_MIRROR_CONF).readlines()
    config = [line.strip().replace('"', '') for line in config]
    return dict([re.split(r'\s*=\s*', line) for line in config])


config = readconf()

parser = optparse.OptionParser(usage="""%prog <stylename> <filename> [options]""")
parser.add_option('-e', '--extent', dest='extent', nargs=4,
                  help='Geographical bounding box. Two long lat pairs e.g. 2.04 43.88 2.22 43.98 (Albi)',
                  type='float',
                  default=[float(v) for v in config['EXTENT'].split(',')],
                  action='store')
parser.add_option('-s', '--scale', dest='scale',
                  help='Scale as integer (e.g. 25000 for 1:25000)',
                  type='int',
                  default=25000,
                  action='store')
parser.add_option('-p', '--projection', dest='projection',
                  help='Projection SRID',
                  type='int',
                  default=2154,
                  action='store')
(options, args) = parser.parse_args()


style = args[0]
output = '%s.png' % args[1]

stylefile = os.path.join('styles', style, '%s.xml' % style)
extension = 'png'
output_tif = output.replace('.png', '.tif')
pixels_per_m = 100.0 / 0.028  # 1 pixel = 0.28mm

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="\033[92m%(message)s\033[0m")


def get_spatial_reference(code):
    if code == 2154:
        return "+proj=lcc +lat_1=49 +lat_2=44 +lat_0=46.5 +lon_0=3 +x_0=700000 +y_0=6600000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
    url = 'http://spatialreference.org/ref/epsg/%s/proj4/' % code
    logger.info('Download spatial reference for %s' % code)
    resp = urllib.urlopen(url).read()
    return resp


def main():
    global options
    wgs84 = Projection('+proj=latlong +datum=WGS84')
    srs = get_spatial_reference(options.projection)
    projection = Projection(srs)
    env = ProjTransform(wgs84, projection)
    bbox = env.forward(Box2d(*options.extent))

    width_m = bbox.width() / options.scale
    height_m = bbox.height() / options.scale
    width_pix = int(math.ceil(pixels_per_m * width_m))
    height_pix = int(math.ceil(pixels_per_m * height_m))

    map = Map(width_pix, height_pix)
    load_map(map, stylefile)
    map.srs = srs
    map.zoom_to_box(bbox)

    logger.info('Extent size: %sm x %sm' % (bbox.width(), bbox.height()))
    logger.info('Scale: 1:%s' % options.scale)
    logger.info('Scaled size: %sm x %sm' % (width_m, height_m))
    logger.info('Image size: %s x %s' % (width_pix, height_pix))
    logger.info('Map extent: %s' % map.envelope())
    logger.info('Map center: %s' % map.envelope().center())
    logger.info('At current scale of %s...' % map.scale())
    logger.info('Map scale denominator: %s' % map.scale_denominator())

    render_to_file(map, output, extension)

    base_cmd = 'gdal_translate %s %s -a_srs "%s" %s %s'
    georeference = '-a_ullr %s %s %s %s' % (bbox.minx, bbox.maxy,
                                            bbox.maxx, bbox.miny)
    opts = '-co "TFW=YES" -co compress=LZW'
    cmd = base_cmd % (output, output_tif, srs, georeference, opts)
    os.system(cmd)
    logger.info("GeoTIFF '%s' created with projection EPSG:%s." % (output_tif, options.projection))


if __name__ == '__main__':
    main()
