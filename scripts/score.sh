#!/usr/bin/env bash

##############################################
## INFO: Score the scouted hits with the    ##
##       PWMs from oRNAment database        ##
## DATE: 03.02.2024                         ##
##############################################

# {INPUT}
ROI=$1
RBP=$2
GENOME_FASTA=$3
OUT_PATH=$4
TMP_PATH=$5
SOURCE=$6

# {MAIN}
echo "scoring $RBP"
ROI_NAME="$(basename "${ROI%".bed"}")"
TMP="$(dirname "$GENOME_FASTA")"
PWM_DIR="$(dirname "$TMP")"/PWMs
# get related fasta
bedtools getfasta -fi "$GENOME_FASTA" -bed "$OUT_PATH"/"$ROI_NAME"_"$RBP".bed >\
    "$TMP_PATH"/"$ROI_NAME"_"$RBP".fa
rm "$OUT_PATH"/"$ROI_NAME"_"$RBP".bed
while read -r LINE; do
    # detect the start of the sequence
    if [[ $LINE == ">"* ]]; then
        # read the seq identified
        SEQ_NAME=${LINE#>}
        SEQ_NAME=$(echo "$SEQ_NAME" | sed -e 's/:/\t/g' -e 's/-/\t/g')
        # read the sequence
        read -r SEQ
        # check if the sequences are of length 7
        if [ ${#SEQ} != 7 ]; then
            continue
        fi
        # reshape into RNA vocabulary per strand and score spearately
        STRANDS=( "+" "-" )
        # declare an associative array to preserve strand specificity
        declare -A MAX_SCORES
        for STRAND in "${STRANDS[@]}"; do
            if [ "$STRAND" = "+" ]; then
                RNA_SEQ=$(echo "$SEQ" | tr 'ATCGatcg' 'TAGCtagc' | tr 'T' 'U')
                
            else
                RNA_SEQ=$(echo "$SEQ" | rev | tr 'ATCGatcg' 'TAGCtagc' | tr 'T' 'U')
            fi
            # score the sequence per available PWM
            SCORES=()
            # use the find
            for PWM_FILE in "$PWM_DIR/$RBP"*; do
                MSS=$("$SOURCE"/score_pwm.sh "$RNA_SEQ" "$PWM_FILE")
                SCORES+=( "$MSS" )
            done
            # select the maximum score
            MAX=${SCORES[0]}
            # iterate over an array of MSS scores
            for SCORE in "${SCORES[@]}"; do
                if [[ $(echo "scale=6; $SCORE > $MAX" | bc) -eq 1 ]]; then
                    MAX=$SCORE
                fi                   
            done
            # record the maximum score for this strand
            MAX_SCORES["$STRAND"]="$MAX"
            #echo results for "$SEQ" at "$STRAND"
            #echo "$RNA_SEQ"
            #echo "$MAX"
        done
        # select the maximum scores between two strands...
        MAX_SCORE=0
        for STRAND in "${!MAX_SCORES[@]}"; do
            SCORE="${MAX_SCORES[$STRAND]}"
            if [[ $(echo "scale=6; $SCORE > $MAX_SCORE" | bc) -eq 1 ]]; then
                MAX_SCORE="$SCORE"
                MAX_STRAND="$STRAND"
            fi
        done
        #echo Maximum score over strands
        #echo "$MAX_SCORE"
        # ...skip the score is too close to zero
        if [[ $(echo "scale=6; $MAX_SCORE < 0.0001" | bc) -eq 1 ]]; then
            continue
        else
        # ...or record to a bed file
        echo -e "$SEQ_NAME""\t""$RBP""\t""$MAX_SCORE""\t""$MAX_STRAND" >>\
            "$OUT_PATH"/"$ROI_NAME"_"$RBP"_scored.bed
        fi
    fi
done < "$TMP_PATH"/"$ROI_NAME"_"$RBP".fa
# intersect with input bed to store record the input entries
bedtools intersect -wo -s\
    -a "$OUT_PATH"/"$ROI_NAME".bed \
    -b "$OUT_PATH"/"$ROI_NAME"_"$RBP"_scored.bed >\
    "$OUT_PATH"/"$ROI_NAME"_"$RBP"_scored_merged.bed
# remove the redundant overlap size column
sed -i 's/\t[^\t]*$//' "$OUT_PATH"/"$ROI_NAME"_"$RBP"_scored_merged.bed