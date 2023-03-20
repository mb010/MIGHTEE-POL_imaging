import os, sys
import shutil
import argparse
import logging
from time import gmtime
import casampi

from casatasks import tclean
from casatools import msmetadata

# import casampi
# from mpi4casa.MPICommandClient import MPICommandClient
# client = MPICommandClient()
# client.set_log_mode('redirect')
# client.start_services()
# ret = client.push_command_request(command,block,target_server,parameters)

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
        help="Measurement set to be imaged (default: '/share/nas2/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms').",
    )
    parser.add_argument(
        "-o",
        "--outpath",
        type=str,
        required=False,
        default="/share/nas2/mbowles/images/",
        help="Full directory path where the images are to be saved (default: '/share/nas2/mbowles/images/').",
    )
    parser.add_argument(
        "--copy",
        action="store_true",
        required=False,
        default=False,
        help="Enables copying of visibility to scratch disk during processing to allow for multiple imaging steps to occur from a single visibility set. (default: False).",
    )

    parser.add_argument(
        "-P",
        "--polarisation",
        action="store_true",
        required=False,
        default=False,
        help="Enables production of IQUV images (default: False).",
    )
    parser.add_argument(
        "-r",
        "--robust",
        type=float,
        required=False,
        default=-0.5,
        help="Robust parameter used for imaging (default: -0.5).",
    )
    parser.add_argument(
        "--clean",
        type=int,
        default=100000,
        required=False,
        help="Cleans iterations used. Set to 0 for quick dirty images (default: 100000).",
    )
    parser.add_argument(
        "--spectral",
        type=float,
        required=False,
        default=0,
        help="Sets spectral imaging width of cube (MHz). Uses MFS if set to 0 (default: 0).",
    )
    parser.add_argument(
        "--nspw",
        type=int,
        required=False,
        default=1,
        help="Denotes how many spw blocks the imaging is to be split into (default: 1).",
    )
    parser.add_argument(
        "--spwidx",
        type=int,
        required=False,
        default=0,
        help="Denotes which spw block this run is for (default: 0).",
    )

    parser.add_argument(
        "--RM",
        type=bool,
        required=False,
        default=False,
        help="NotImplmented: Produces Faraday spectra cubes (default: False).",
    )
    parser.add_argument(
        "--cellsize",
        type=float,
        default=1.5,
        required=False,
        help="Cell size paramter in arcsec (default: 1.0).",
    )

    parser.add_argument(
        "-n",
        "--index",
        type=int,
        required=False,
        default=None,
        help="If provided splits a single channel range out for that given index, i.e. N=5 will split out the 5th channel as a seperate ms. (Default is to split the whole data set).",
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

    args, unknown = parser.parse_known_args()

    return args


def main():
    args = parse_args()
    # --------------------------- edit these parameters -------------------------
    parameters = {
        "threshold": 0.0001,
        "imsize": [6144, 6144],
        "cell": "1.5arcsec",
        "wprojplanes": 768,
        "datacolumn": "data",
        "gridder": "wproject",
        "stokes": "IQUV",
        "uvrange": ">0.25klambda",
        "phasecenter": "",
        "reffreq": "",
        "niter": 1,  # will be 60000
        "parallel": True,
    }
    LOCAL_NAS = "/state/partition1/"
    TMP_DIR = "tmp_bowles"

    # ------------------------------- running clean -----------------------------
    # Find correct SPW if specified:
    if args.index is not None:
        freq_range = [880e6, 1680e6]  # MHz
        start_freq = (
            freq_range[0] + int(args.index) * float(args.channelwidth) * 10**6
        )
        end_freq = (
            freq_range[0] + (int(args.index) + 1) * float(args.channelwidth) * 10**6
        )
        parameters["spw"] = "*:{start_freq}~{end_freq}Hz".format(
            start_freq=int(start_freq), end_freq=int(end_freq)
        )
        print(f""">>> parameters['spw']: {parameters['spw']}""")

    # For details see: https://casa.nrao.edu/docs/taskref/tclean-task.html
    # Using CLI to generate appropriate parameters
    parameters["niter"] = args.clean
    parameters["cell"] = str(args.cellsize) + "arcsec"
    parameters["robust"] = args.robust
    parameters["verbose"] = args.verbose

    parameters["specmode"] = "cube" if (args.RM or abs(args.spectral) > 0) else "mfs"
    parameters["width"] = (
        str(args.spectral) + "MHz" if parameters["specmode"] == "cube" else ""
    )
    parameters["deconvolver"] = (
        "multiscale" if parameters["specmode"] == "cube" else "mtmfs"
    )
    parameters["start"] = ""
    parameters["nchan"] = -1

    # Adjust parameters according to specmode
    if parameters["specmode"] == "cube":
        # start and nchan depend on spw chunk according to slurm job
        # Calculate starting frequency for this specific spw chunk
        l, u = freqRanges
        extent = u - l
        start = l + extent / args.nspw * args.spwidx

        # Produce usable values for CASA
        nchan = int(extent / args.nspw / args.spectral)  # Calculate number of channels
        # print(f">>> TEST: start {start} extent/nspw {extent/args.nspw} nchan {nchan} end {start+nchan*args.spectral}".format(start=start, ))
        start = "{start}MHz".format(start=start)
        width = "{width}MHz".format(width=str(args.spectral))
        deconvolver = "multiscale"
    else:
        nchan = -1
        start = ""
        width = ""
        deconvolver = "mtmfs"

    # MFS or IQUV Image
    if not args.polarisation:
        stokes = ["I"]
    else:
        if parameters["specmode"] == "cube":
            stokes = ["IQUV"]
            # stokes = ["I", "Q", "U", "V"]
            # nchan = []
            # start = []
        else:
            stokes = ["IQUV"]

    # Scales: Approximate width of largest scale object easily seen is ~2arcmin
    parameters["scales"] = (
        [] if parameters["deconvolver"] == "mtfs" else [0, 3, 10, 30, 80, 120]
    )

    # Copy visibility to scratch disk if requested
    parameters["vis"] = args.vis
    if args.copy:
        LOCAL_PATH = os.getcwd()
        os.chdir(LOCAL_NAS)
        os.makedirs(TMP_DIR, exist_ok=True)
        os.chdir(TMP_DIR)
        LOCAL_COPY = str(args.vis.split("/")[-1])
        if os.path.exists(LOCAL_COPY):
            logger.info(
                "A local copy of the MS already exists at {LOCAL_NAS}{TMP_DIR}/{LOCAL_COPY} (likely due to a previous run failing).".format(
                    LOCAL_NAS=LOCAL_NAS, TMP_DIR=TMP_DIR, LOCAL_COPY=LOCAL_COPY
                )
            )
            logger.info("Deleting local copy before copying over fresh version.")
            shutil.rmtree(LOCAL_COPY)
        logger.info(
            "Copying data to {LOCAL_NAS}{TMP_DIR}/ under the name: {LOCAL_COPY}".format(
                LOCAL_NAS=LOCAL_NAS, TMP_DIR=TMP_DIR, LOCAL_COPY=LOCAL_COPY
            )
        )
        shutil.copytree(parameters["vis"], LOCAL_COPY)
        parameters["vis"] = LOCAL_COPY
    else:
        logger.warn(
            "Not copying over files. This can cause a memory lock when multiple tasks are trying to access the same visibility set."
        )

    for stokes_ in stokes:
        parameters["stokes"] = stokes_
        # Generate unique image name
        # parameters['imagename'] = f"{args.outpath}{args.vis.split('/')[-1]}_{parameters['specmode']}_{stokes_}_{args.robust}_{parameters['imsize'][0]}"
        parameters[
            "imagename"
        ] = "{outpath}/{vis_name}_{specmode}_{stokes}_{robust}_{image_size}".format(
            outpath=args.outpath.rstrip("/"),
            vis_name=args.vis.split("/")[-1],
            specmode=parameters["specmode"],
            stokes=stokes_,
            robust=args.robust,
            image_size=parameters["imsize"][0],
        )
        if args.index is not None:
            parameters["imagename"] = parameters["imagename"] + "_" + str(args.index)
        if os.path.exists(parameters["imagename"]) and not args.force:
            logger.error(
                "An image already exists under this name, use --force to overwrite (received output path: {outpath}).".format(
                    outpath=parameters["imagename"]
                )
            )

        logger.info(
            ">>> Starting image: {image_name}".format(
                image_name=parameters["imagename"]
            )
        )
        tclean(**parameters)

    # Remove temporary folder
    if args.copy:
        logger.info("Removing temporary data: {vis}".format(vis=vis))
        os.chdir(local)
        shutil.rmtree(vis)
    return


if __name__ == "__main__":
    main()
