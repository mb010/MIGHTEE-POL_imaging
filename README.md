# MIGHTEE-POL_imaging
Science imaging on Manchester's Galahad HPC for MIGHTEE-POL.

## Pipeline Outline
- `full_imaging.sh` defines all parameters needed to run the imaging and calls the following.
    - `split/merge_spw.sh`.
        - Merges the mms back into a single ms across all spectral windows. This makes it much easier to split into appropriate channels.
        - We expect this to take approx. 4hrs.
        - Calls `split/merge_spw.py` and saves merged data into `$OUTPATH` as defined in `full_imaging.sh` and calls it `${VIS}_merged.ms`.
    - `image/image.mfs.sh ROBUST`
        - Copies data to `$TMP_OUTDIR`, generates mfs image with polarisation in the same directory before copying out the NAS.
        - Returns data into `${OUTDIR}/mfs_${ROBUST}/`
        - Deletes any local working files used during imaging as these (except the MS) should have been copied over to the NAS.
    - `image/image_channels.sh ROBUST1 ROBUST2`
        - Only is called when data merging is complete (slurm dependancy).
        - Splits data from merged data set into appropriate MS for the given channels (as indexed through a job array).
        - Breaks file lock after this data has been split into the working directory (`$TMP_DIR`).
        - Uses the same split MS to produce image cubes for both `$ROBUST1` and `$ROBUST2`.
        - Copies data out to the NAS from the working directory and deletes local data.
    - `concat/concat.sh ROBUST`
        - Not yet implemented.
        - Should concatenate all of the finished data products from the channelwise imaging into 4d cubes.
    - `cleanup/cleanup.sh`
        - Not implemented yet.
        - Should verify that no residual data is present on various scratch disks.

Warnings that the data is not being copied locally will appear. These can be ignored unless using the `image_mfs.py` and `image_channels.py` scripts independantly (in which case, they are still a warning and consider if your use case is appropriate).

This is an example.
