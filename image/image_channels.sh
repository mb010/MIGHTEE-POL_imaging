#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=300G
#SBATCH --job-name=ImageChannel
#SBATCH --time=14-00:00:00
#SBATCH --array=0-320%70
#SBATCH --output=./logs/%x.%A_%a.out
#SBATCH --error=./logs/%x.%A_%a.err

module load openmpi-2.1.1
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
ulimit -n 16384

MS_NAME=$(basename $VIS)
IMAGE_LIST="${OUTDIR}${MS_NAME%.*ms}_*.ms"
#PATH_LIST="${OUTDIR}${FILE_NAME%.*ms}_split.txt"
#CHANNEL=$(awk "NR==${SLURM_ARRAY_TASK_ID+1}" $PATH_LIST)

ROBUST="$1"
echo ">>> Imaging Call of a Channel ${IDX}. Running on ${SLURM_JOB_NODELIST}<<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python ./image/image.py \
      --polarisation \
      --robust=$ROBUST \
      --vis=$VIS \
      --outpath=$OUTDIR \
      --index=$SLURM_ARRAY_TASK_ID \
      --channelwidth=$CHANNEL_WIDTH

echo ">>> Concatenating images <<<"
time /share/apps/casa-pipeline-release-5.6.2-2.el7/bin/casa
