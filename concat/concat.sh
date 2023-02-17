#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --job-name=Concatenate
#SBATCH --time=4-00:00:00
#SBATCH --output=./logs/%x.%A_%a.out
#SBATCH --error=./logs/%x.%A_%a.err

module load openmpi-2.1.1
ulimit -n 16384

MS_NAME=$(basename $VIS)
#CHANNEL="${OUTDIR}${MS_NAME%.*ms}_${SLURM_ARRAY_TASK_ID}.ms"
CHANNEL="${OUTDIR}${MS_NAME%.*ms}_{channel_index}.ms"


ROBUST="$1"

# The ia.imageconcat task from casa image module, is not a python importable function.
echo ">>> Concatenating ${IDX} <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python ./concat/concat.py \
    --basename=$CHANNEL \
    --polarisation \
    --robust=$ROBUST \
    --outpath=$OUTDIR \
    --index=$SLURM_ARRAY_TASK_ID \
    --channelwidth=$CHANNEL_WIDTH

# Use ia.imageconcat directly through CLI?
# Not sure how to call CLI variables as casa task
# Something like: with asterisk to match any image which is there.
/share/apps/casa-pipeline/bin/casa --inp "ia.imageconcat(vis=$CHANNEL)"
