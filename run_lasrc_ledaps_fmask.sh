#!/bin/bash

set -e
shopt -s nullglob

if [ $1 == "--help" ]; then
    echo "Usage: \
    docker run --rm \
    -v /path/to/input/:/mnt/input-dir:ro \
    -v /path/to/output:/mnt/output-dir:rw \
    -v /path/to/lasrc_auxiliaries/L8:/mnt/lasrc-aux:ro \
    -v /path/to/ledaps_auxiliaries:/mnt/ledaps-aux:ro
    -t lasrcfmask <LANDSAT-4,5,7,8 FOLDER OR SENTINEL-2.SAFE>"
    exit 0
fi

# Set default directories to the INDIR and OUTDIR
# You can customize it using INDIR=/my/custom OUTDIR=/my/out run_lasrc_ledaps_fmask.sh
if [ -z "${INDIR}" ]; then
    INDIR=/mnt/input-dir
fi

if [ -z "${INDIR}" ]; then
    OUTDIR=/mnt/output-dir
fi


##Landsat
if [[ $1 == "LT04"* ]] || [[ $1 == "LT05"* ]] || [[ $1 == "LE07"* ]] || [[ $1 == "LC08"* ]]; then
    SCENE_ID=$1
    WORKDIR=/work/${SCENE_ID}

    MTD_FILES=$(find ${INDIR} -name "${SCENE_ID}_MTL.txt" -o -name "${SCENE_ID}_ANG.txt")
    TIF_PATTERNS="${SCENE_ID}_*.tif -iname ${SCENE_ID}_*.TIF"

    # ensure that workdir/sceneid is clean
    rm -rf ${WORKDIR}
    mkdir -p $WORKDIR
    cd $WORKDIR

    # only make files with the correct scene ID visible
    for f in $(find ${INDIR} -iname "${SCENE_ID}*.tif"); do
        echo $f
        if gdalinfo $f | grep -q 'Block=.*x1\s'; then
            ln -s $(readlink -f $f) $WORKDIR/$(basename $f)
        else
            # convert tiled tifs to striped layout
            gdal_translate -co TILED=NO $f $WORKDIR/$(basename $f)
        fi
    done

    for f in $MTD_FILES; do
        cp $f $WORKDIR
    done

    # run ESPA stack
    convert_lpgs_to_espa --mtl=${SCENE_ID}_MTL.txt
    if [[ $1 == "LC08"* ]]; then
        do_lasrc_landsat.py --xml ${SCENE_ID}.xml --write_toa
    else #Landsat 4,5,7
        do_ledaps.py --xml ${SCENE_ID}.xml
    fi
    convert_espa_to_gtif --xml=${SCENE_ID}.xml --gtif=$SCENE_ID --del_src_files


    ##FMASK
    MCROOT=/usr/local/MATLAB/MATLAB_Runtime/v96

    /usr/GERS/Fmask_4_1/application/run_Fmask_4_1.sh $MCROOT "$@"

    ## Copy outputs from workdir
    mkdir -p $OUTDIR
    OUT_PATTERNS="$WORKDIR/${SCENE_ID}_toa_*.tif $WORKDIR/${SCENE_ID}_sr_*.tif $WORKDIR/${SCENE_ID}_bt_*.tif $WORKDIR/${SCENE_ID}_radsat_qa.tif"
    for f in $OUT_PATTERNS; do
        cp $f $OUTDIR/$(basename $f)
    done
    OUT_PATTERNS="$WORKDIR/${SCENE_ID}_Fmask4*.tif"
    for f in $OUT_PATTERNS; do
        cp $f $OUTDIR/${SCENE_ID}_Fmask41.tif
    done

    for f in $MTD_FILES; do
        cp $WORKDIR/$(basename $f) $OUTDIR/$(basename $f)
    done

    rm -rf $WORKDIR

## SENTINEL-2
elif [[ $1 == "S2"* ]]; then
    SAFENAME=$1

    SAFEDIR=/mnt/input-dir/${SAFENAME}
    SCENE_ID=${SAFENAME:0:-5}
    WORKDIR=/work/${SAFENAME}
    OUTDIR=/mnt/output-dir/
    JP2_PATTERNS=$(find ${INDIR} -name "${SCENE_ID}_*.jp2" -o -name "${SCENE_ID}_*.JP2")


    # ensure that workdir/sceneid is clean
    rm -rf ${WORKDIR}
    mkdir -p ${WORKDIR}
    cp -r ${SAFEDIR}/* ${WORKDIR}
    cd ${WORKDIR}/GRANULE

    for entry in `ls ${WORKDIR}/GRANULE`; do
        GRANULE_SCENE=${WORKDIR}/GRANULE/${entry}
    done
    IMG_DATA=${GRANULE_SCENE}/IMG_DATA
    cd ${IMG_DATA}

    #Copy XMLs
    cp $WORKDIR/MTD_MSIL1C.xml $IMG_DATA
    cp $GRANULE_SCENE/MTD_TL.xml $IMG_DATA


    # run ESPA stack
    convert_sentinel_to_espa

    for entry in `ls ${IMG_DATA}/S2*.xml`; do
        SCENE_ID_XML=${entry}
    done
    do_lasrc_sentinel.py --xml=${SCENE_ID_XML}
    convert_espa_to_gtif --xml=${SCENE_ID_XML} --gtif=${SCENE_ID} --del_src_files

    ##FMASK
    MCROOT=/usr/local/MATLAB/MATLAB_Runtime/v96
    cd ${GRANULE_SCENE}
    /usr/GERS/Fmask_4_1/application/run_Fmask_4_1.sh $MCROOT "$@"

    ## Copy outputs from workdir
    mkdir -p $OUTDIR
    OUT_PATTERNS="${IMG_DATA}/${SCENE_ID}_sr_*.tif"
    for f in $OUT_PATTERNS; do
        cp $f $OUTDIR/$(basename $f)
    done
    OUT_PATTERNS="${GRANULE_SCENE}/FMASK_DATA/*_Fmask4*.tif"
    for f in $OUT_PATTERNS; do
        cp $f $OUTDIR/${SCENE_ID}_Fmask41.tif
    done

    rm -rf $WORKDIR
fi

exit 0
