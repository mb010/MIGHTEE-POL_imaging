#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200G
#SBATCH --job-name=ImageChannel
#SBATCH --time=0-12:00:00
#SBATCH --array=0-320%320
#SBATCH --output=./logs/%x.%A_%a.out
#SBATCH --error=./logs/%x.%A_%a.err

module load openmpi-2.1.1
ulimit -n 16384
FILE_NAME=${basename $VIS}
PATH_LIST="${OUTDIR}${FILENAME%.*ms}_split.txt"
CHANNEL=$(awk "NR==${SLURM_ARRAY_TASK_ID+1}" $PATH_LIST)
ROBUST="$1"

if [ -f "$CHANNEL" ] || [ -d "$CHANNEL"]; then
  echo ">>> Imaging Call of a Channel: ${CHANNEL} <<<"
  time singularity exec --bind /share,/state/partition1 $CONTAINER \
    python ./image/image.py \
        --polarisation \
        --robust=$ROBUST \
        --vis=$CHANNEL \
        --outpath=$OUTDIR

else
    echo ">>> NOT Imaging: $CHANNEL is not a valid path / file. <<<"
fi
