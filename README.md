# LaSRC 2.0.1, LEDAPS 3.4.0 and FMASK 4.3

Landsat-4,5,7 atmospheric correction through LEDAPS 3.4.0, Landsat-8 and Sentinel-2 atmospheric correction through LaSRC 2.0.1, cloud masking FMASK 4.3.

## Dependencies

- Docker

## LEDAPS Auxiliary Data

Download the baseline auxiliary files ``http://edclpdsftp.cr.usgs.gov/downloads/auxiliaries/ledaps_auxiliary/ledaps_aux.1978-2017.tar.gz``.

## LaSRC Auxiliary Data

Download the ``https://edclpdsftp.cr.usgs.gov/downloads/auxiliaries/lasrc_auxiliary/L8/`` into *L8*. The LADS folder can contain only data from dates which are going to be processed, instead of all the files.

## Installation

1. [Download FMask 4.3 standalone Linux installer](https://github.com/GERSL/Fmask)
   and copy it into the root of this repository.

2. Run

   ```bash
   $ docker build -t lasrc_ledaps_fmask .
   ```

   from the root of this repository.

## Usage

To process a Landsat-4,5,7 scene (e.g. `LT05_L1TP_166072_19950217_20170110_01_T1`) run

```bash
$ docker run --rm \
    -v /path/to/input/:/mnt/input-dir:rw \
    -v /path/to/output:/mnt/output-dir:rw \
    -v /path/to/ledaps_auxiliaries:/mnt/ledaps-aux:ro \
    -t lasrc_ledaps_fmask LT05_L1TP_166072_19950217_20170110_01_T1
```

To process a Landsat-8 scene (e.g. `LC08_L1TP_220069_20190112_20190131_01_T1`) run

```bash
$ docker run --rm \
    -v /path/to/input/:/mnt/input-dir:rw \
    -v /path/to/output:/mnt/output-dir:rw \
    -v /path/to/lasrc_auxiliaries/L8:/mnt/lasrc-aux:ro \
    -t lasrc_ledaps_fmask LC08_L1TP_220069_20190112_20190131_01_T1
```

To process a Sentinel-2 scene (e.g. `S2A_MSIL1C_20190105T132231_N0207_R038_T23LLF_20190105T145859.SAFE`) run

```bash
$ docker run --rm \
    -v /path/to/input/:/mnt/input-dir:rw \
    -v /path/to/output:/mnt/output-dir:rw \
    -v /path/to/lasrc_auxiliaries/L8:/mnt/lasrc-aux:ro \
    -t lasrc_ledaps_fmask S2A_MSIL1C_20190105T132231_N0207_R038_T23LLF_20190105T145859.SAFE
```

Results are written on mounted `/mnt/output-dir/SCENEID`.

## Acknowledgements

Copyright for portions of FMASK docker 4.0 code are held by Dion Häfner, 2018 as part of project fmaskilicious (https://github.com/DHI-GRAS/fmaskilicious).
Copyright for portions of LaSRC 1.4 docker code are held by DHI GRAS A/S, 2018 as part of project lasrclicious (https://github.com/DHI-GRAS/lasrclicious).