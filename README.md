# LaSRC 2.0 FMASK 4.1

Landsat-8 and Sentinel-2 LaSRC atmospheric correction 2.0 and cloud masking FMASK 4.1.

## Dependencies

- Docker

## Setting up Auxiliary Data

Download the ``https://edclpdsftp.cr.usgs.gov/downloads/auxiliaries/lasrc_auxiliary/L8/`` into *L8*. The LADS folder can contain only data from dates which are going to be processed, instead of all the files.

## Installation

1. [Download FMask 4.1 standalone Linux installer](https://github.com/GERSL/Fmask)
   and copy it into the root of this repository.

2. Run

   ```bash
   $ docker build -t lasrcfmask .
   ```

   from the root of this repository.

## Usage

To process a Landsat-8 scene (e.g. `LC08_L1TP_220069_20190112_20190131_01_T1`) run

```bash
$ docker run --rm \
    -v /path/to/input/:/mnt/input-dir:rw \
    -v /path/to/output:/mnt/output-dir:rw \
    -v /path/to/auxiliaries/L8:/mnt/lasrc-aux:ro \
    -t lasrcfmask LC08_L1TP_220069_20190112_20190131_01_T1
```

To process a Sentinel-2 scene (e.g. `S2A_MSIL1C_20190105T132231_N0207_R038_T23LLF_20190105T145859.SAFE`)
that is located on your PC run

```bash
$ docker run --rm \
    -v /path/to/input/:/mnt/input-dir:rw \
    -v /path/to/output:/mnt/output-dir:rw \
    -v /path/to/auxiliaries/L8:/mnt/lasrc-aux:ro \
    -t lasrcfmask S2A_MSIL1C_20190105T132231_N0207_R038_T23LLF_20190105T145859.SAFE
```

Results are written to the folder mounted on `/mnt/output-dir/SCENEID`.
