#!/bin/bash


### LANDSAT
##LaSRC
set -e
shopt -s nullglob

if [ $1 == "--help" ]; then
    echo "Usage: run_lasrc_fmask.sh <LANDSAT-8_FOLDER OR SENTINEL-2.SAFE>"
    exit 0
fi

if [[ $1 == "LC08"* ]]; then
    SCENE_ID=$1
    WORKDIR=/work/${SCENE_ID}
    INDIR=/mnt/input-dir/${SCENE_ID}
    OUTDIR=/mnt/output-dir/${SCENE_ID}
    MTD_FILES="${INDIR}/${SCENE_ID}_MTL.txt ${INDIR}/${SCENE_ID}_ANG.txt"
    TIF_PATTERNS="${INDIR}/${SCENE_ID}_*.tif ${INDIR}/${SCENE_ID}_*.TIF"

    # ensure that workdir/sceneid is clean
    rm -rf ${WORKDIR}
    mkdir -p $WORKDIR
    cd $WORKDIR

    # only make files with the correct scene ID visible
    for f in $TIF_PATTERNS; do
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
    do_lasrc_landsat.py --xml ${SCENE_ID}.xml --write_toa
    convert_espa_to_gtif --xml=${SCENE_ID}.xml --gtif=$SCENE_ID --del_src_files


    ##FMASK
    MCROOT=/usr/local/MATLAB/MATLAB_Runtime/v96

    /usr/GERS/Fmask_4_1/application/run_Fmask_4_1.sh $MCROOT "$@"


    ## Copy outputs from workdir
    mkdir $OUTDIR
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

elif [[ $1 == "S2"* ]]; then
  ## SENTINEL

    SAFENAME=$1
    SAFENAME=S2A_MSIL1C_20190105T132231_N0207_R038_T23LLF_20190105T145859.SAFE

    SAFEDIR=/mnt/input-dir/${SAFENAME}
    SCENE_ID=${SAFENAME:0:-5}
    WORKDIR=/work/${SAFENAME}
    OUTDIR=/mnt/output-dir/${SCENE_ID}
    JP2_PATTERNS="${INDIR}/${SCENE_ID}_*.jp2 ${INDIR}/${SCENE_ID}_*.JP2"


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
    mkdir $OUTDIR
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
