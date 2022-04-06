#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --time=1-00:00:00
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=250G
#SBATCH --job-name=SplitData
#SBATCH --output=./logs/%x.%j.out
#SBATCH --error=./logs/%x.%j.err

ulimit -n 16384

# Change VIS to be local scratch disk version
# Copy data to local scratch disk

MS_NAME=$(basename $VIS)
TMP_VIS="/state/partition1/${MS_NAME}"
TMP_OUTDIR="/state/partition1/$(basename ${VIS%.*ms})/"
echo ">>> Copying data to local disk."
mkdir $TMP_OUTDIR
cp -r $VIS $TMP_VIS

for IDX in {0..320..1}
do
  echo ">>> Starting split for ${IDX}/320."
  time singularity exec --bind /share,/state/partition1 $CONTAINER \
    python ./split/split.py \
      --vis=$TMP_VIS \
      --channelwidth=$CHANNEL_WIDTH \
      --outdir=$TMP_OUTDIR \
      --index=$IDX
done

# Copy data back
echo ">>> Copying data back to shared disk."
cp -r "${TMP_OUTDIR}/*" $OUTDIR

# Delete local scratch version at the end
echo ">>> Cleaning up local disk."
rm -r $TMP_OUTDIR
rm -r $TMP_VIS
