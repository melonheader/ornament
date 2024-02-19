#!/usr/bin/env bash

##############################################
## INFO: Main script to utilise oRNAment    ##
##       database                           ##
## DATE: 03.02.2024                         ##
##############################################

# {SETUP}
set -e
# Process arguments
# Help message
HELP="usage: $0 -i [bed_file] [options]
options:
    -h, --help              show brief help
    -i, --path_to_bed       path(s) to input bed file(s) with ROI(s)
    -o, --out_dir           specify a directory to write results (default source dir)
    -g, --genome            name of the genome <MM|HS> (default HS)
    -r, --rbps_to_look      name(s) of RBPs to score (defaults to all, n = 223)
    -n, --n_cores           number of cores to parallelize jobs (default 6)
    -t, --tmp_dir           specify a directory to tmp files (default out_dir/tmp)
    the database is built on ensemble release 97; GRCm38 & GRCh38
"
if [ $# -eq 0 ]; then
    echo "No arguments provided"
    echo "$HELP"
    exit 0
fi
while (( "$#" )); do
    case "$1" in
        -h|--help)
            echo "usage: $0 -i [bed_file] [options]"
            echo "options:"
            echo "-h, --help              show brief help"
            echo "-i, --path_to_bed       path to input bed file with ROI(s)"
            echo "-o, --out_dir           specify a directory to write results (default source dir)"
            echo "-g, --genome			  name of the genome <MM|HS> (default HS)"
            echo "-r, --rbps_to_look      name(s) of RBPs to score (defaults to all, n = 223)"
			echo "-n, --n_cores           number of cores to parallelize jobs (default 6)"
            echo "-t, --tmp_dir           specify a directory to tmp files (default out_dir/tmp)"
            echo "the database is built on ensemble release 97; GRCm38 & GRCh38"
            exit 0
        ;;
        -i|--path_to_bed)
            shift 
            if test $# -gt 0; then
                ROI=$1
            else
                echo "No input bed files provided"
				exit 1
            fi
            shift
        ;;
        -o|--out_dir)
            shift
            if test $# -gt 0; then
                OUT_DIR=$1
            fi
            shift
		;;
		-g|--genome)
			shift
			if test $# -gt 0; then
				GENOME=$1
			fi
			shift
		;;
        -r|--rbps_to_look)
            shift 
            if test $# -gt 0; then
                RBPS=()
				ARGS=( "$@" )
				set -- "${ARGS[@]}"
				while (( $# )); do
					if [ ${1:0:1} == "-" ]; then
						break
					fi
					RBPS+=("$1")
					shift
				done
				unset ARGS
            fi
        ;;
        -m|--merge)
            MERGE="TRUE"
            shift
        ;;
		-n|--n_cores)
			shift
			if test $# -gt 0; then
				N_CORES=$1
			fi
			shift
		;;
        -t|--tmp_dir)
            shift
            if test $# -gt 0; then
                TMP_DIR=$1
            fi
            shift
		;;
        *)
            echo "bad option"
            exit 1
        ;;
    esac
done

# {INPUT}
# fill empty variables
if [ -z "$GENOME" ]; then
    GENOME=HS
fi
if [ -z "$N_CORES" ]; then
    N_CORES=6
fi
# Build paths to data
# shellcheck disable=SC2154
SOURCE=${BASH_SOURCE[0]} # locate source
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SOURCE_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$SOURCE_DIR/$SOURCE
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SOURCE_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
WD=$(dirname "$SOURCE_DIR")
DATA_DIR="$WD"/data
if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$WD"/out
fi
if [ ! -d "$OUT_DIR" ]; then
    mkdir "$OUT_DIR"
fi
if [ -z "$TMP_DIR" ]; then
    TMP_DIR="$OUT_DIR"/tmp
fi
if [ ! -d "$TMP_DIR" ]; then
    mkdir "$TMP_DIR"
fi
if [ "$GENOME" = HS ]; then
    GENOME_FASTA="$DATA_DIR"/annot/Homo_sapiens.GRCh38.dna.toplevel.fa.gz
    BED_DIR="$DATA_DIR"/"$GENOME"
else
    GENOME_FASTA="$DATA_DIR"/annot/Mus_musculus.GRCm38.dna.toplevel.fa.gz
    BED_DIR="$DATA_DIR"/"$GENOME"
fi
if [[ -z "$RBPS" ]]; then
    RBPS=("$DATA_DIR"/"$GENOME"/*.bed.gz)
    for (( i = 0; i < ${#RBPS[@]}; i++ )); do
        TMP=$(basename "${RBPS[i]}")
        RBPS[i]=${TMP%".bed.gz"}
    done
    unset TMP
else
    NI_RBPS=${#RBPS[@]}
    for (( i = 0; i < "$NI_RBPS"; i++ )); do
        #RBP_TEST="$DATA_DIR"/"$GENOME"/${RBPS[i]}.bed.gz
        if ! find "$DATA_DIR"/"$GENOME" -maxdepth 1 -type f -name "${RBPS[i]}".bed.gz | grep -q "${RBPS[i]}"; then
            echo "${RBPS[i]}" is not in the database
            unset 'RBPS[i]'
        fi
    done
fi
# {MAIN}
## remove chr from the chromosome name
ROI_NAME="$(basename "${ROI%".bed"}")"
awk '{sub(/^chr/, "", $1); print}'  FS="\t" OFS="\t" "$ROI" |\
sort -k1,1 -k2,2n > "$OUT_DIR"/"$ROI_NAME".bed
ROI="$OUT_DIR"/"$ROI_NAME".bed
for RBP in "${RBPS[@]}"; do
    ##
    (
        "$SOURCE_DIR"/scout.sh "$ROI" "$RBP" "$BED_DIR" "$OUT_DIR" "$TMP_DIR"; wait
        "$SOURCE_DIR"/score.sh  "$ROI" "$RBP" "$GENOME_FASTA" "$OUT_DIR" "$TMP_DIR" "$SOURCE_DIR"
    ) &
    ## allow parallel execution of n jobs
    if [[ $(jobs -r -p | wc -l) -gt $((N_CORES - 1)) ]]; then
        # wait for a batch to finish
        wait
    fi
done; wait
# merge results results
if [ -n "$MERGE" ]; then
    for SCORED_BED in "$OUT_DIR"/*_scored_ann.bed; do
        cat "$SCORED_BED" >> "$OUT_DIR"/"$ROI_NAME"_scored_ann_merged.bed
    done
fi 