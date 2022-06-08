#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=32G
#SBATCH --job-name=ImageChannel
#SBATCH --time=14-00:00:00
#SBATCH --array=0-319%320
#SBATCH --output=./logs/%x.%A_%a.out
#SBATCH --error=./logs/%x.%A_%a.err
#SBATCH --exclude=compute-0-8

sleep ${SLURM_ARRAY_TASK_ID}s

module load openmpi-2.1.1
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
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

MS_NAME=$(basename $VIS)
#IMAGE_LIST="${OUTDIR}${MS_NAME%.*ms}_*.ms" # will be useful for concatenation
#PATH_LIST="${OUTDIR}${FILE_NAME%.*ms}_split.txt"
#CHANNEL=$(awk "NR==${SLURM_ARRAY_TASK_ID+1}" $PATH_LIST)

# SPLIT DATA ONTO LOCAL SCRATCH DISK
TMP_OUTDIR="${TMP_DIR}/$(basename ${VIS%.*ms})_${SLURM_ARRAY_TASK_ID}/"
echo ">>> ls of TMP_OUTDIR"
ls -lht $TMP_OUTDIR
du -sh $TMP_OUTDIR*
rm -r $TMP_OUTDIR
mkdir --parents $TMP_OUTDIR
pwd
cd $TMP_OUTDIR
pwd

echo ">>> Splitting out Channel ${SLURM_ARRAY_TASK_ID}. Running on ${SLURM_JOB_NODELIST} <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python /share/nas2/mbowles/MIGHTEE-POL_imaging/split/split.py \
    --vis="$VIS" \
    --channelwidth=$CHANNEL_WIDTH \
    --outdir=$TMP_OUTDIR \
    --index=$SLURM_ARRAY_TASK_ID

# Break file Lock
echo ">>> Breaking lock on ${IO_LOCK_FILE}"
rm $IO_LOCK_FILE

SPLIT_VIS="${TMP_OUTDIR}$(basename ${VIS%.*ms})_${SLURM_ARRAY_TASK_ID}.ms"
TMP_OUTDIR="${TMP_OUTDIR}images/"

# IMAGE FOR EACH ROBUST PARAMETER
ROBUST="$1"
echo ">>> Imaging Call of a Channel ${SLURM_ARRAY_TASK_ID} robust ${ROBUST}. Running on ${SLURM_JOB_NODELIST} <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python /share/nas2/mbowles/MIGHTEE-POL_imaging/image/image_channels.py \
      --polarisation \
      --robust=$ROBUST \
      --vis="$SPLIT_VIS" \
      --outpath=$TMP_OUTDIR

ROBUST="$2"
echo ">>> Imaging Call of a Channel ${SLURM_ARRAY_TASK_ID} robust ${ROBUST}. Running on ${SLURM_JOB_NODELIST} <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python /share/nas2/mbowles/MIGHTEE-POL_imaging/image/image_channels.py \
      --polarisation \
      --robust=$ROBUST \
      --vis="$SPLIT_VIS" \
      --outpath=$TMP_OUTDIR

# COPYING DATA OUT
echo ">>> Copying from local disk (${TMP_OUTDIR}) to NFS (${OUTDIR}/chan_${SLURM_ARRAY_TASK_ID})"
cp -r "${TMP_OUTDIR}"* "${OUTDIR}/chan_${SLURM_ARRAY_TASK_ID}"
# CLEAN UP SCRATCH DISK
echo ">>> Removing data from scratch <<<"
cd ../
rm -r $TMP_OUTDIR
