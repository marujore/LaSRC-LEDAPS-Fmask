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
    -t lasrc_ledaps_fmask <LANDSAT-4,5,7,8 FOLDER OR SENTINEL-2.SAFE>"
    exit 0
fi
# Set default directories to the INDIR and OUTDIR
# You can customize it using INDIR=/my/custom OUTDIR=/my/out run_lasrc_ledaps_fmask.sh
if [ -z "${INDIR}" ]; then
    INDIR=/mnt/input-dir
fi

##Landsat
if [[ $1 == "LT04"* ]] || [[ $1 == "LT05"* ]] || [[ $1 == "LE07"* ]] || [[ $1 == "LC08"* ]]; then
    SCENE_ID=$1
    WORKDIR=/work/${SCENE_ID}
    # ensure that workdir/sceneid is clean
    rm -rf ${WORKDIR}
    mkdir -p $WORKDIR
    cd $WORKDIR

    if [ -z "${OUTDIR}" ]; then
        OUTDIR=/mnt/output-dir/${SCENE_ID}
    fi

    MTD_FILES=$(find ${INDIR} -name "${SCENE_ID}_MTL.txt" -o -name "${SCENE_ID}_ANG.txt")
    TIF_PATTERNS="${SCENE_ID}_*.tif -iname ${SCENE_ID}_*.TIF"
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
        do_lasrc_landsat.py --xml ${SCENE_ID}.xml # --write_toa
        OUT_PATTERNS="$WORKDIR/${SCENE_ID}_toa_*.tif $WORKDIR/${SCENE_ID}_sr_*.tif $WORKDIR/${SCENE_ID}_bt_*.tif $WORKDIR/${SCENE_ID}_radsat_qa.tif $WORKDIR/${SCENE_ID}_sensor*.tif $WORKDIR/${SCENE_ID}_solar*.tif"
    else #Landsat 4,5,7
        do_ledaps.py --xml ${SCENE_ID}.xml
        OUT_PATTERNS="$WORKDIR/${SCENE_ID}_sr_*.tif $WORKDIR/${SCENE_ID}_bt_*.tif $WORKDIR/${SCENE_ID}_radsat_qa.tif $WORKDIR/${SCENE_ID}_sensor*.tif $WORKDIR/${SCENE_ID}_solar*.tif"
    fi
    convert_espa_to_gtif --xml=${SCENE_ID}.xml --gtif=$SCENE_ID --del_src_files
    ##FMASK
    MCROOT=/usr/local/MATLAB/MATLAB_Runtime/v96
    /usr/GERS/Fmask_4_3/application/run_Fmask_4_3.sh $MCROOT "$@"
    ## Copy outputs from workdir
    mkdir -p $OUTDIR
    for f in $OUT_PATTERNS; do
        gdal_translate -co "COMPRESS=DEFLATE" $f $OUTDIR/$(basename $f)
    done
    # Check if Fmask exists because it is not generated when 100% of image is cloud
    OUT_PATTERNS="$WORKDIR/${SCENE_ID}_Fmask4*.tif"
    if ls $OUT_PATTERNS* 1> /dev/null 2>&1; then
        # echo "files do exist"
        for f in $OUT_PATTERNS; do
            gdal_translate -co "COMPRESS=DEFLATE" -a_nodata 255 $f $OUTDIR/${SCENE_ID}_Fmask4.tif
        done
    else
        # if Fmask does not exist create a copy image with values set to 4 (cloud) and keeps nodata as nodata
        echo "Generating synthetic 100% Cloud Fmask"
        $REFIMG="${IMG_DATA}/${SCENE_ID}_B4.TIF"
        gdal_calc.py --NoDataValue=255 -A $REFIMG --outfile=$OUTDIR/${SCENE_ID}_Fmask4.tif --calc="(logical_or(A>0, A<0)*4)+((A==0)*255)"
    fi
    for f in $MTD_FILES; do
        cp $WORKDIR/$(basename $f) $OUTDIR/$(basename $f)
    done
    rm -rf $WORKDIR
## SENTINEL-2
elif [[ $1 == "S2"* ]]; then
    SAFENAME=$1
    SAFEDIR=${INDIR}/${SAFENAME}
    SCENE_ID=${SAFENAME:0:-5}

    WORKDIR=/work/${SAFENAME}
    JP2_PATTERNS=$(find ${INDIR} -name "${SCENE_ID}_*.jp2" -o -name "${SCENE_ID}_*.JP2")
    # ensure that workdir/sceneid is clean
    rm -rf ${WORKDIR}
    mkdir -p ${WORKDIR}
    cp -r ${SAFEDIR}/* ${WORKDIR}/
    cd ${WORKDIR}/GRANULE
    for entry in `ls ${WORKDIR}/GRANULE`; do
        GRANULE_SCENE=${WORKDIR}/GRANULE/${entry}
    done
    IMG_DATA=${GRANULE_SCENE}/IMG_DATA
    cd ${IMG_DATA}
    #Copy XMLs
    cp $WORKDIR/MTD_MSIL1C.xml $IMG_DATA
    cp $GRANULE_SCENE/MTD_TL.xml $IMG_DATA

    if [ -z "${OUTDIR}" ]; then
        OUTDIR=/mnt/output-dir/${SCENE_ID}
    fi

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
    /usr/GERS/Fmask_4_3/application/run_Fmask_4_3.sh $MCROOT "$@"
    ## Copy outputs from workdir
    mkdir -p $OUTDIR
    OUT_PATTERNS="${IMG_DATA}/${SCENE_ID}_sr_*.tif"
    for f in $OUT_PATTERNS; do
        gdal_translate -co "COMPRESS=DEFLATE" $f $OUTDIR/$(basename $f)
    done
    #Copy XMLs
    cp $WORKDIR/MTD_MSIL1C.xml $OUTDIR
    cp $GRANULE_SCENE/MTD_TL.xml $OUTDIR
    OUT_PATTERNS="${GRANULE_SCENE}/FMASK_DATA/*_Fmask4*.tif"
    # if Fmask does not exist create a copy image with values set to 4 (cloud) and keeps nodata as nodata
    if ls $OUT_PATTERNS* 1> /dev/null 2>&1; then
        for f in $OUT_PATTERNS; do
            gdalwarp -tr 10 10 -r near -overwrite -co "COMPRESS=DEFLATE" -dstnodata 255 $f $OUTDIR/${SCENE_ID}_Fmask4.tif
        done
    else
        # if Fmask does not exist set image values to 4 (cloud) and keeps nodata as nodata
        echo "Generating synthetic 100% Cloud Fmask"
        for f in $(find ${IMG_DATA} -iname "*_B8A.jp2"); do
            REFIMG=$f
        done
        gdal_calc.py --NoDataValue=255 -A $REFIMG --outfile=$OUTDIR/${SCENE_ID}_Fmask4.tif --calc="(logical_or(A>0, A<0)*4)+((A==0)*255)"
    fi
    rm -rf $WORKDIR
fi
exit 0
