#!/bin/bash

#SBATCH --time=1-00
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --job-name=SplitData

ulimit -n 16384
export VIS=/share/nas/mbowles/dev/testing/1538856059_sdp_l0.J0217-0449.mms
export CONTAINER=/share/nas2/mbowles/dev/casa-6_v2.simg
export CHANNEL_WIDTH=2.5078

# Split data into a list of MS
SPLIT_ID=$(sbatch ./channel_split/split.sh)
echo $SPLIT_ID
# Call imaging instances in slurm array (for first robust)

# Call imaging instances in slurm array (for second robust)

# Concatenate images

# Cleanup
