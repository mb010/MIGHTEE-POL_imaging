#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1500G
#SBATCH --job-name=MergeSPW
#SBATCH --time=1-00:00:00
#SBATCH --output=logs/%j.%x.out
#SBATCH --error=logs/%j.%x.err

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
module load openmpi-2.1.1
ulimit -n 16384

echo "Start time:"
echo $(date + %c)

# IO Lock
while [ -f "$IO_LOCK_FILE" ]
do
  sleep 1m
done
# Activate file lock
printf "VIS: ${VIS}\nMerging to ${OUTDIR}/$(basename ${VIS%.*ms})_merged.ms\nRunning on ${SLURM_JOB_NODELIST}\n" >> $IO_LOCK_FILE
printf "VIS: ${VIS}\nMerging to ${OUTDIR}/$(basename ${VIS%.*ms})_merged.ms\nRunning on ${SLURM_JOB_NODELIST}\n"
echo ">>> File lock check passed ${IO_LOCK_FILE} activated."


echo ">>> Starting Merge <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python ./split/merge_spw.py \
      --vis=$VIS \
      --outdir=$OUTDIR
echo ">>> Merge completed <<<"

# Break file lock
echo ">>> Breaking lock on ${IO_LOCK_FILE}"
rm $IO_LOCK_FILE
