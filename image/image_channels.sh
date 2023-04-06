#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=17
#SBATCH --mem=30G
#SBATCH --job-name=MPIImgChan
#SBATCH --time=7-00:00:00
#SBATCH --array=0-221
#SBATCH --output=logs/%A_%a.%x.out
#SBATCH --error=logs/%A_%a.%x.err
#SBATCH --exclude=compute-0-1,compute-0-2,compute-0-30

sleep ${SLURM_ARRAY_TASK_ID}s

# array tasks should be #SBATCH --array=0-221 when actually being used.
module load openmpi-2.1.1
ulimit -n 16384
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK


echo "Start time:"
date +'%Y-%m-%d %H:%M:%S'
DATE_START=`date +%s`


MS_NAME=$(basename $VIS)

# SPLIT DATA ONTO LOCAL SCRATCH DISK
TMP_OUTDIR="${TMP_DIR}/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
echo ">>> ls -lht TMP_OUTDIR ($TMP_OUTDIR)"
ls -lht $TMP_OUTDIR
echo ">>> mkdir -p TMP_OUTDIR ($TMP_OUTDIR)"
mkdir -p $TMP_OUTDIR
pwd
cd $TMP_OUTDIR
pwd

echo ">>> Splitting out Channel ${SLURM_ARRAY_TASK_ID}. Running on ${SLURM_JOB_NODELIST} <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python ${SCRIPT_DIR}/split/split.py \
    --vis="$VIS" \
    --channelwidth=$CHANNEL_WIDTH \
    --outdir=$TMP_OUTDIR \
    --index=$SLURM_ARRAY_TASK_ID

SPLIT_VIS="${TMP_OUTDIR}/$(basename ${VIS%.*ms})_chan_${SLURM_ARRAY_TASK_ID}.ms"
TMP_IMAGE_DIR="${TMP_OUTDIR}/images"
echo ">>> Making image tmp image directory ${TMP_IMAGE_DIR} (TMP_IMAGE_DIR)."
mkdir -p $TMP_IMAGE_DIR

# IMAGE FOR EACH ROBUST PARAMETER
ROBUST="$1"
echo ">>> Imaging Call of a Channel ${SLURM_ARRAY_TASK_ID} robust ${ROBUST}. Running on ${SLURM_JOB_NODELIST} <<<"
# mpirun --mca oob tcp singularity exec --bind /share,/state/partition1 $CONTAINER \
time singularity exec --bind /share,/state/partition1 $CONTAINER \
    python ${SCRIPT_DIR}/image/image_channels.py \
      --polarisation \
      --robust=$ROBUST \
      --vis=$SPLIT_VIS \
      --outpath=$TMP_IMAGE_DIR

# COPYING DATA OUT
CHAN_IMGS="chan_imgs"
echo ">>> Copying from local disk (${TMP_IMAGE_DIR}) to NAS (${OUTDIR}/${CHAN_IMGS}/${SLURM_ARRAY_TASK_ID}/)"
mkdir -p $OUTDIR/chan_imgs/$SLURM_ARRAY_TASK_ID/
cp -r $TMP_IMAGE_DIR $OUTDIR/$CHAN_IMGS/$SLURM_ARRAY_TASK_ID/

# CLEAN UP SCRATCH DISK
echo ">>> rm -r TMP_OUTDIR ($TMP_OUTDIR)"
rm -r $TMP_OUTDIR

echo "Finishing time:"
date +'%Y-%m-%d %H:%M:%S'

DATE_END=`date +%s`
SECONDS=$((DATE_END-DATE_START))
MINUTES=$((SECONDS/60))
SECONDS=$((SECONDS-60*MINUTES))
HOURS=$((MINUTES/60))
MINUTES=$((MINUTES-60*HOURS))
echo Total run time : $HOURS Hours $MINUTES Minutes $SECONDS Seconds
