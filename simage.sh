#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --array=0-5%6
#SBATCH --job-name=ImgDebug
#SBATCH --time=14-00:00:00

module load openmpi-2.1.1
ulimit -n 16384

export CONTAINER=/share/nas2/mbowles/dev/casa-6_v2.simg
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export VIS=/share/nas2/mbowles/dev/testing/1538856059_sdp_l0.J0217-0449.mms

# Need to produce 2 robustness for cube and mfs. Cubes are split into multiple parts:
# Total nodes: 2+2*N, N=number of spw splits for cube imaging
export NSPW=(1 1 6 6 6 6 6 6 6 6)
export SPECTRAL_BLOCK=(0 0 0 1 2 3 0 1 2 3)

export SPECTRAL=(0 0 2.5078 2.5078 2.5078 2.5078 2.5078 2.5078 2.5078 2.5078) #Units: MHz (0 defaults to MFS)
export ROBUST=(-0.5 0.4 -0.5 -0.5 -0.5 -0.5 0.0 0.0 0.0 0.0)

echo ">>> Imaging call"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python image.py \
      --polarisation \
      --spectral=${SPECTRAL[$SLURM_ARRAY_TASK_ID]} \
      --robust=${ROBUST[$SLURM_ARRAY_TASK_ID]} \
      --vis=$VIS \
      --nspw=${NSPW[$SLURM_ARRAY_TASK_ID]} \
      --spwidx=${SPECTRAL_BLOCK[$SLURM_ARRAY_TASK_ID]} \
      --copy
