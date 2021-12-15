#!/bin/bash

#SBATCH --time=3-00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --array=0-3%4
#SBATCH --job-name=debug
#SBATCH --time=14-00:00:00

module load openmpi-2.1.1
ulimit -n 16384

export CASA_PATH=/share/nas/mbowles/dev/casa-6.simg
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export VIS=/share/nas/mbowles/dev/testing/1538856059_sdp_l0.J0217-0449.mms

export SPECTRAL=(0 0 2.5 2.5) #Units: MHz (0 defaults to MFS)
export ROBUST=(-0.5 0.4 -0.5 0.0)

echo ">>> Imaging call"
time singularity exec --bind /share,/state/partition1 /share/nas/mbowles/dev/casa-6.simg python image.py --polarisation --spectral=${SPECTRAL[$SLURM_ARRAY_TASK_ID]} --robust=${ROBUST[$SLURM_ARRAY_TASK_ID]} --vis=$VIS
