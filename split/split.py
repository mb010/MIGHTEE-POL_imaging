import os, sys
import shutil
import argparse
import logging
from time import gmtime

import casatasks
from casatools import msmetadata

msmd = msmetadata()

logging.Formatter.converter = gmtime
logger = logging.getLogger(__name__)
logging.basicConfig(format="%(asctime)-15s %(levelname)s: %(message)s")
loglevel = logging.DEBUG  # if verbose else logging.INFO
logger.setLevel(loglevel)


def parse_args():
    """
    Parse in command line arguments.
    """
    THIS_PROG = os.path.realpath(__file__)
    SCRIPT_DIR = os.path.dirname(THIS_PROG)

    parser = argparse.ArgumentParser(
        prog=THIS_PROG,
        description="MIGHTEE-POL Imaging: github.com/mb010/MIGHTEE-POL_imaging.",
    )

    parser.add_argument(
        "-M",
        "--vis",
        type=str,
        required=False,
        default="/share/nas2/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms",
        help="Measurement set to be imaged (default: '/share/nas/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms').",
    )
    parser.add_argument(
        "-O",
        "--outdir",
        type=str,
        required=False,
        default="/share/nas2/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms",
        help="Measurement set to be imaged (default: '/share/nas/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms').",
    )
    parser.add_argument(
        "-C",
        "--channelwidth",
        type=str,
        required=False,
        default="2.5078",
        help="Channel width to use for splitting. Default: 2.5078",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=False,
        required=False,
        help="Verbose output.",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        default=False,
        required=False,
        help="Forces overwrite of output (default: False).",
    )
    parser.add_argument(
        "-n",
        "--index",
        type=int,
        required=False,
        default=None,
        help="If provided splits a single channel range out for that given index, i.e. N=5 will split out the 5th channel as a seperate ms. (Default is to split the whole data set).",
    )
    args, unknown = parser.parse_known_args()
    return args


class Split:
    def __init__(
        self,
        vis,
        datacolumn,
        chan_width,
        force,
        outdir,
        freq_range="880-1680",
        index=None,
    ):
        # Read in parameters
        self.vis = vis
        self.outdir = outdir
        self.datacolumn = datacolumn  # Should maybe be 'corrected'
        self.freq_range = [int(f) * 1e6 for f in freq_range.split("-")]
        self.chan_width = int(float(chan_width) * 1e6)
        self.filebase = self.vis.rstrip(".mms").split("/")[-1]
        self.force = force
        self.index = index

        # Will be changed as each split is made
        self.start_freq = self.freq_range[0]
        self.out_files = []

        self.split()

    def split(self):
        if self.index is not None:
            counter = self.index
        else:
            counter = 0
        while self.start_freq <= self.freq_range[1]:
            self.start_freq = self.start_freq + (counter - 1) * self.chan_width
            self.stop_freq = self.start_freq + self.chan_width
            self.spw = f"*:{int(self.start_freq)}~{int(self.stop_freq)}Hz"  ### use self.index to calculate
            print(f">>> self.spw: {self.spw}")
            # Decided on filename formatting. Index should be easier with slurm jobs
            # filename = f"{self.outdir}{self.filebase}.{self.spw}.ms"
            filename = f"{self.outdir}/{self.filebase}_chan_{counter}.ms"

            if ~os.path.isdir(filename) or self.force:
                casatasks.split(
                    vis=self.vis,
                    outputvis=filename,
                    keepmms=False,
                    width=1,
                    spw=self.spw,
                    datacolumn=self.datacolumn,
                )
                self.out_files.append(f"{self.outdir}/{filename}")
            counter += 1
            if self.index is not None:
                logger.info(
                    f"Split index {self.index} successfully.\n\tSaved to: {filename}.\n\tFrequencies: {self.spw}"
                )
                return
            else:
                logger.info(
                    f"Folder already exists at output: {filename}. Not including in list to be imaged."
                )
        logger.info(
            f"Split {len(self.out_files)} out of a total possible {(self.freq_range[1]-self.freq_range[0])//self.chan_width} channel splits."
        )
        return


def main():
    args = parse_args()
    print(f"msmd: \n{msmd}")

    split = Split(
        vis=args.vis,
        datacolumn="data",
        chan_width=args.channelwidth,
        force=args.force,
        outdir=args.outdir,
        index=args.index,
    )
    # Write file names to txt
    with open(f"{split.outdir}{split.filebase}_split.txt", "w") as f:
        for item in split.out_files:
            f.write(f"{item}\n")


if __name__ == "__main__":
    main()
