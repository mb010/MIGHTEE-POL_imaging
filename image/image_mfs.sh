#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --job-name=ImageMFS
#SBATCH --time=14-00:00:00
#SBATCH --output=./logs/%x.%j.out
#SBATCH --error=./logs/%x.%j.err

module load openmpi-2.1.1
ulimit -n 16384

#export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
ROBUST="$1"

echo ">>> MFS Imaging Call <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python ./image/image.py \
      --polarisation \
      --robust=$ROBUST \
      --vis=$VIS \
      --outpath=$OUTPATH
