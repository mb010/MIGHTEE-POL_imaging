#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --job-name=FullImaging
#SBATCH --output=logs/%j.%x.out
#SBATCH --error=logs/%j.%x.err

# Define variables used in this full imaging run.
export VIS="$1"
# export VIS=/share/nas2/MIGHTEE/calibration/cosmos/1587911796_sdp_l0/1587911796_sdp_l0.4k.J1000+0212.mms #COSMOS test
#export VIS=/share/nas2/mbowles/dev/1587911796_sdp_l0.4k.J1000+0212_merged.ms
export CONTAINER=/share/nas2/mbowles/casa-6_v2.simg
export CHANNEL_WIDTH=2.5078
export TMP_DIR=/state/partition1/tmp_bowles
export IO_LOCK_FILE=/share/nas2/mbowles/nas2_5.lock
export SCRIPT_DIR=/share/nas2_5/MIGHTEE/MIGHTEE-POL_imaging

export OUTDIR="/share/nas2_5/MIGHTEE/images/$(basename ${VIS%.*ms})"
mkdir -p $OUTDIR

YES="yes"
MERGE=$2
MERGE=${2:-yes}

echo "Starting time:"
date +'%Y-%m-%d %H:%M:%S'

if [ "$MERGE" == "$YES" ]; then
    # Merge SPW of data set to allow for easy channel slicing # This works, but takes >230min (~4hrs)
    IMG_MERGE=$(sbatch --export=ALL ${SCRIPT_DIR}/split/merge_spw.sh) # returns string containing job number.
    IMG_MERGE=${IMG_MERGE##* } # Finds last space and returns string after that space (i.e. the job number)
    sleep 1m
fi

Imaging: MFS IQUV, 2 briggs weightings
IMG_MFS_IQUV1=$(sbatch --export=ALL ${SCRIPT_DIR}/image/image_mfs.sh -0.5)
IMG_MFS_IQUV1=${IMG_MFS_IQUV1##* }
sleep 3s
IMG_MFS_IQUV2=$(sbatch --export=ALL ${SCRIPT_DIR}/image/image_mfs.sh 0.4)
IMG_MFS_IQUV2=${IMG_MFS_IQUV2##* }

# Change VIS to merged VIS:
export VIS="${OUTDIR}/$(basename ${VIS%.*ms})_merged.ms"
echo ">>> VIS for channel imaging: ${VIS}"
sleep 3s
# Imaging: Channelwise IQUV, 2 briggs weightings
# Takes approx 5200m (~86h / ~3.5days)
if [ "$MERGE" == "$YES" ]; then
    echo ">>> Waiting for Merge to finish before launching channel imaging."
    echo $(date + %Y-%m-%d %H:%M:%S)
    IMG_CHAN_IQUV1=$(sbatch --dependency=afterany:$IMG_MERGE --export=ALL ${SCRIPT_DIR}/image/image_channels.sh 0.0)
    IMG_CHAN_IQUV1=${IMG_CHAN_IQUV##* }
else
    echo ">>> Launching channel imaging."
    echo $(date + %Y-%m-%d %H:%M:%S)
    IMG_CHAN_IQUV1=$(sbatch --export=ALL ${SCRIPT_DIR}/image/image_channels.sh 0.0)
    IMG_CHAN_IQUV1=${IMG_CHAN_IQUV##* }
fi

# Concatenate images: 2 briggs weightings
#CONCAT_ID1=$(sbatch --dependency=afterany:$IMG_MFS_IQUV2:$IMG_CHAN_IQUV2 ${SCRIPT_DIR}/concat/concat.sh -0.5)
#CONCAT_ID2=$(sbatch --dependency=afterany:$IMG_MFS_IQUV2:$IMG_CHAN_IQUV2 ${SCRIPT_DIR}/concat/concat.sh 0.0)

# Cleanup
# Remove merged VIS during cleanup
#sbatch --dependency=afterany:$CONCAT_ID1:$CONCAT_ID2 ${SCRIPT_DIR}/cleanup/cleanup.sh

echo "Finishing time:"
date +'%Y-%m-%d %H:%M:%S'
