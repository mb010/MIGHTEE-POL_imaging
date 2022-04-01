#!/bin/bash

#SBATCH --time=1-00
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --job-name=SplitData

VIS=/share/nas2/mbowles/dev/testing/1538856059_sdp_l0.J0217-0449.mms
CONTAINER=/share/nas2/mbowles/dev/casa-6_v2.simg
ulimit -n 16384

time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python split.py \
    --vis=$VIS \
    --outpath=/share/nas2/mbowles/tmp
