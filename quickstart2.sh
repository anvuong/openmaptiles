if [ $# -eq 0 ]; then
    osm_area=albania                         #  default test country
    echo "No parameter - set area=$osm_area "
else
    osm_area=$1
fi
testdata=${osm_area}.osm.pbf

##  Min versions ...
MIN_COMPOSE_VER=1.7.1
MIN_DOCKER_VER=1.12.3
STARTTIME=$(date +%s)
STARTDATE=$(date +"%Y-%m-%dT%H:%M%z")
githash=$( git rev-parse HEAD )

log_file=./quickstart.log

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Start importing OpenStreetMap data: ./data/${testdata} -> imposm3[./build/mapping.yaml] -> PostgreSQL"
echo "      : Imposm3 documentation: https://imposm.org/docs/imposm3/latest/index.html "
echo "      :   Thank you Omniscale! "
echo "      :   Source code: https://github.com/openmaptiles/import-osm "
echo "      : The OpenstreetMap data license: https://www.openstreetmap.org/copyright (ODBL) "
echo "      : Thank you OpenStreetMap Contributors ! "
docker-compose run --rm import-osm

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Start importing Wikidata: ./wikidata/latest-all.json.gz -> PostgreSQL"
echo "      : Source code: https://github.com/openmaptiles/import-wikidata "
echo "      : The Wikidata license: https://www.wikidata.org/wiki/Wikidata:Database_download/en#License "
echo "      : Thank you Wikidata Contributors ! "
docker-compose run --rm import-wikidata

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Start SQL postprocessing:  ./build/tileset.sql -> PostgreSQL "
echo "      : Source code: https://github.com/openmaptiles/import-sql "
docker-compose run --rm import-sql

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Analyze PostgreSQL tables"
make psql-analyze

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Bring up postserve at localhost:8090/tiles/{z}/{x}/{y}.pbf"
docker-compose up -d postserve

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Start generating MBTiles (containing gzipped MVT PBF) from a TM2Source project. "
echo "      : TM2Source project definitions : ./build/openmaptiles.tm2source/data.yml "
echo "      : Output MBTiles: ./data/tiles.mbtiles  "
echo "      : Source code: https://github.com/openmaptiles/generate-vectortiles "
echo "      : We are using a lot of Mapbox Open Source tools! : https://github.com/mapbox "
echo "      : Thank you https://www.mapbox.com !"
echo "      : See other MVT tools : https://github.com/mapbox/awesome-vector-tiles "
echo "      :  "
echo "      : You will see a lot of deprecated warning in the log! This is normal!  "
echo "      :    like :  Mapnik LOG>  ... is deprecated and will be removed in Mapnik 4.x ... "

docker-compose -f docker-compose.yml -f ./data/docker-compose-config.yml  run --rm generate-vectortiles

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Add special metadata to mbtiles! "
docker-compose run --rm openmaptiles-tools  generate-metadata ./data/tiles.mbtiles
docker-compose run --rm openmaptiles-tools  chmod 666         ./data/tiles.mbtiles

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Stop PostgreSQL service ( but we keep PostgreSQL data volume for debugging )"
docker-compose stop postgres

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : Inputs - Outputs md5sum for debugging "
rm -f ./data/quickstart_checklist.chk
md5sum build/mapping.yaml                     >> ./data/quickstart_checklist.chk
md5sum build/tileset.sql                      >> ./data/quickstart_checklist.chk
md5sum build/openmaptiles.tm2source/data.yml  >> ./data/quickstart_checklist.chk
md5sum ./data/${testdata}                     >> ./data/quickstart_checklist.chk
md5sum ./data/tiles.mbtiles                   >> ./data/quickstart_checklist.chk
md5sum ./data/docker-compose-config.yml       >> ./data/quickstart_checklist.chk
md5sum ./data/osmstat.txt                     >> ./data/quickstart_checklist.chk
cat ./data/quickstart_checklist.chk

ENDTIME=$(date +%s)
ENDDATE=$(date +"%Y-%m-%dT%H:%M%z")
if stat --help >/dev/null 2>&1; then
  MODDATE=$(stat -c %y ./data/${testdata} )
else
  MODDATE=$(stat -f%Sm -t '%F %T %z' ./data/${testdata} )
fi

echo " "
echo " "
echo "-------------------------------------------------------------------------------------"
echo "--                           S u m m a r y                                         --"
echo "-------------------------------------------------------------------------------------"
echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : (disk space) We have created a lot of docker images: "
echo "      : Hint: you can remove with:  docker rmi IMAGE "
docker images | grep openmaptiles


echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : (disk space) We have created this new docker volume for PostgreSQL data:"
echo "      : Hint: you can remove with : docker volume rm openmaptiles_pgdata "
docker volume ls -q | grep openmaptiles

echo " "
echo "-------------------------------------------------------------------------------------"
echo "====> : (disk space) We have created the new vectortiles ( ./data/tiles.mbtiles ) "
echo "      : Please respect the licenses (OdBL for OSM data) of the sources when distributing the MBTiles file."
echo "      : Created from $testdata ( file moddate: $MODDATE ) "
echo "      : Size: "
ls -la ./data/*.mbtiles

echo " "
echo "-------------------------------------------------------------------------------------"
echo "The ./quickstart.sh $osm_area  is finished! "
echo "It takes $(($ENDTIME - $STARTTIME)) seconds to complete"
echo "We saved the log file to $log_file  ( for debugging ) You can compare with the travis log !"
echo " "
echo "Start experimenting! And check the QUICKSTART.MD file!"
echo "Available help commands (make help)  "
make help

echo "-------------------------------------------------------------------------------------"
echo " Acknowledgments "
echo " Generated vector tiles are produced work of OpenStreetMap data. "
echo " Such tiles are reusable under CC-BY license granted by OpenMapTiles team: "
echo "   https://github.com/openmaptiles/openmaptiles/#license "
echo " Maps made with these vector tiles must display a visible credit: "
echo "   © OpenMapTiles © OpenStreetMap contributors "
echo " "
echo " Thanks to all free, open source software developers and Open Data Contributors!    "
echo "-------------------------------------------------------------------------------------"
