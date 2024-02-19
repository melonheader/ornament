#!/usr/bin/env bash

##############################################
## INFO: Start-up to initialise scripts and ##
##       download oRNAment data             ##
## DATE: 01.02.2024                         ##
##############################################

SOURCE=${BASH_SOURCE[0]} # locate source
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SOURCE_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$SOURCE_DIR/$SOURCE
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SOURCE_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
# download 
DATA_DIR="$SOURCE_DIR"/data
if [ ! -d "$DATA_DIR" ]; then
  mkdir -p "$DATA_DIR"/annot
fi
if [ ! -d "$DATA_DIR"/raw ]; then
  mkdir -p "$DATA_DIR"/raw
fi
# Get ensembl genome fasta; release 97 as in oRNAment
STEM=https://ftp.ensembl.org/pub/release-97/fasta/
SPECIES=( homo_sapiens  mus_musculus )
if [ "$(ls | wc -l)" -lt 3 ]; then
  for ANIMAL in "${SPECIES[@]}"; do
    wget -r --no-parent -nd -P "$DATA_DIR"/annot "$STEM""$ANIMAL"/dna_index/
  done
fi
unset STEM
# Get oRNAment database
STEM=https://rnabiology.ircm.qc.ca/BIF/oRNAment/static/
TARS=( Homo_sapiens_oRNAment.bed.tar.gz Mus_musculus_oRNAment.bed.tar.gz PWMs.tgz )
for TAR in "${TARS[@]}"; do
  if [ ! -f "$DATA_DIR"/raw/"$TAR" ]; then
    wget -P "$DATA_DIR"/raw "$STEM""$TAR"
    tar -xvf "$DATA_DIR"/raw -C "$DATA_DIR"
  fi
done
#
export PATH="$PATH":"$SOURCE_DIR"/scripts