#!/bin/bash

#SBATCH --time=1-00
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --job-name=SplitData
#SBATCH --output=./logs/%x.%j.out
#SBATCH --error=./logs/%x.%j.err

ulimit -n 16384

time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python ./split/split.py \
    --vis=$VIS \
    --channelwidth=$CHANNEL_WIDTH \
    --outpath=/share/nas2/mbowles/tmp
