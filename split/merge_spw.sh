#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=1500G
#SBATCH --job-name=MergeSPW
#SBATCH --time=1-00:00:00
#SBATCH --output=./logs/%x.%j.out
#SBATCH --error=./logs/%x.%j.err

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
module load openmpi-2.1.1
ulimit -n 16384

# IO Lock
IO_LOCK_FILE="/share/nas2/mbowles/nas2.lock"
while [ -f "$IO_LOCK_FILE59" ]
do
  sleep 1m
done
printf "VIS: ${VIS_TMP}\nChannel No.: ${SLURM_ARRAY_TASK_ID}\nRunning on ${SLURM_JOB_NODELIST}\n" >> $IO_LOCK_FILE
printf "VIS: ${VIS_TMP}\nChannel No.: ${SLURM_ARRAY_TASK_ID}\nRunning on ${SLURM_JOB_NODELIST}\n"
echo ">>> File lock check passed ${IO_LOCK_FILE} activated."


echo ">>> Starting Merge <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python ./split/merge_spw.py \
      --vis=$VIS \
      --outdir=$OUTDIR
echo ">>> Merge completed <<<"

echo ">>> Breaking lock on ${IO_LOCK_FILE}"
rm $IO_LOCK_FILE
