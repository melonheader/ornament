#!/usr/bin/env bash

##############################################
## INFO: Scout the ROI for hits in          ##
##       oRNAment database                  ##
## DATE: 03.02.2024                         ##
##############################################

# {INPUT}
ROI=$1
RBP=$2
BED_DIR=$3
OUT_PATH=$4
TMP_PATH=$5

# {MAIN}
echo "scouting $RBP"
ROI_NAME="$(basename "${ROI%".bed"}")"
# extract RBP bed and intersect
gunzip -c "$BED_DIR"/"$RBP".bed.gz |\
awk -v s=1 '{print $1, $2-1, $3, $4}' |\
sed 's/ /\t/g' |\
sed 's/chr//g' |\
sort -k1,1 -k2,2n > "$TMP_PATH"/"$RBP".bed
bedtools intersect -wb -sorted -F 1.00 -a "$ROI" -b "$TMP_PATH"/"$RBP".bed |\
awk 'BEGIN {OFS="\t"} {print $1, $2, $3, $8}' |\
awk '!seen[$0]++' >\
"$OUT_PATH"/"$ROI_NAME"_"$RBP".bed
# clean after yourself
rm "$TMP_PATH"/"$RBP".bed