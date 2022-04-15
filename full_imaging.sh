#!/bin/bash

#SBATCH --time=30-00
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --job-name=FullImaging
#SBATCH --output=./logs/%x.%j.out
#SBATCH --error=./logs/%x.%j.err

export VIS=/share/nas2/mbowles/dev/testing/1538856059_sdp_l0.J0217-0449.mms
export CONTAINER=/share/nas2/mbowles/dev/casa-6_v2.simg
export CHANNEL_WIDTH=2.5078

export OUTDIR="/share/nas2/mbowles/images/$(basename ${VIS%.*ms})/"
mkdir $OUTDIR

# Split data into a list of MS
#SPLIT_ID=$(sbatch ./split/split.sh --export=ALL)
#SPLIT_ID=${SPLIT_ID##* }

# Imaging:
# MFS IQUV: 2 briggs weightings
IMG_MFS_IQUV1=$(sbatch --export=ALL ./image/image_mfs.sh -0.5)
IMG_MFS_IQUV1=${IMG_MFS_IQUV1##* }
IMG_MFS_IQUV2=$(sbatch --export=ALL ./image/image_mfs.sh 0.4)
IMG_MFS_IQUV2=${IMG_MFS_IQUV2##* }

# Channelwise IQUV: 2 briggs weightings
IMG_CHAN_IQUV1=$(sbatch --export=ALL ./image/image_channels.sh -0.5)
IMG_CHAN_IQUV1=${IMG_CHAN_IQUV1##* }
IMG_CHAN_IQUV2=$(sbatch --dependency=afterany:%IMG_CHAN_IQUV1 --export=ALL ./image/image_channels.sh 0.0)
IMG_CHAN_IQUV2=${IMG_CHAN_IQUV2##* }

# Concatenate images: 2 briggs weightings
#CONCAT_ID1=$(sbatch --dependency=afterany:$IMG_MFS_IQUV2:$IMG_CHAN_IQUV2 ./concat/concat.sh -0.5)
#CONCAT_ID2=$(sbatch --dependency=afterany:$IMG_MFS_IQUV2:$IMG_CHAN_IQUV2 ./concat/concat.sh 0.0)

# Cleanup
#sbatch --dependency=afterany:$CONCAT_ID1:$CONCAT_ID2 ./cleanup/cleanup.sh
