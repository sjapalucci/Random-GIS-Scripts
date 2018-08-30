#! /bin/bash
################################################################
# Simple Utility to automate the download and reprojection 
# of the PA Department of Environmental Protections locational 
# data set on Oil & Gas Wells
################################################################

SELFPATH=$(readlink -f $0)       
SELFDIR=`dirname ${SELFPATH}`   
SELF=`basename ${SELFPATH}`     
LOGGER="${SELF}.log"


#Spatial Reference
SPROJ=4269  #The coordinate system the DEP uses 
DPROJ=26915 #The coordinate system that the software prefers 

#URL to Open GIS Data Access for the Commonwealth of Pennsylvania.
#Updated monthly
URL='ftp://ftp.pasda.psu.edu/pub/pasda/dep/'

#The filename is usually appended with the 4 digit year and 2 digit month
FILENAME="OilGasLocations_ConventionalUnconventional$(date +%Y_%m)"

#Destination Filename
PRODFILE='PADEPConvUnconv'

DESTDIR=`pwd`

function usage {
  echo "
  usage: $SELF [options]
  -h            		Print this help message
  -q            		Suppress screen output
  -i <filename> 		filename to grab from PASDA
  -p <production_filename>	The processed filename 
  -l <log>      		optional  print errors and output to this file.
                		default ${SELF}.log
  -d <destdir>  		store output here.
                		default is current directory"
  exit 1
}


function rlog {
  if [[ $QUIET == "true" ]]
  then
    echo $(date) $1 1>> $LOGGER
  else
    echo $(date) $1 |tee -a $LOGGER
  fi
}

while getopts :hqfi:p:o:l: args
do
  case $args in
  h) usage ;;
  q) QUIET='true' ;; ## Suppress messages, just log them.
  l) LOGGER="$OPTARG" ;;
  i) FILENAME="$OPTARG" ;;
  p) PRODFILE="$OPTARG" ;;
  o) DESTDIR="$OPTARG" ;;
  :) rlog "The argument -$OPTARG requires a parameter" ;;
  *) usage ;;
  esac
done


function main {
	rlog "retrieving $FILENAME from PASDA"
	curl -o $DESTDIR/$FILENAME.zip  $URL/$FILENAME.zip
	
	rlog "Decompressing $FILENAME.zip to $DESTDIR/"
	unzip -od $DESTDIR $DESTDIR/$FILENAME.zip

	rlog "Filtering and Reprojecting $FILENAME"
	
	mkdir -p $DESTDIR/temp
	ogr2ogr -f "ESRI Shapefile" $DESTDIR/temp/$PRODFILE$$.shp  $DESTDIR/$FILENAME.shp -sql "SELECT * FROM  $FILENAME WHERE COUNTY IN ('Westmoreland','Allegheny','Washington','Greene','Fayette','Butler','Beaver','Armstrong') ORDER BY COUNTY DESC"

	ogr2ogr -f "ESRI Shapefile" $DESTDIR/temp/$PRODFILE.shp $DESTDIR/temp/$PRODFILE$$.shp  -t_srs EPSG:$DPROJ -s_srs EPSG:$SPROJ

	rlog "Moving file to destination and cleaning up any remaining waste"
	mv $DESTDIR/temp/$PRODFILE.*  $DESTDIR/
	find $DESTDIR/temp -type f -exec rm -f {} \;
	rmdir $DESTDIR/temp

	rlog "Set Permissions and Creating index on $PRODFILE"
	chown nobody:nobody $DESTDIR/$PRODFILE.*
	chmod 644 $DESTDIR/$PRODFILE.*
	shptree $DESTDIR/$PRODFILE
	rlog "###############################################"
	rlog "Complete\n\\n"
}

main "$@"
