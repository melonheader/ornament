#!/usr/bin/env bash

##############################################
## INFO: Score a PWM over RNA sequence      ##
## DATE: 03.02.2024                         ##
##############################################

# {INPUT}
SEQ=$1 # RNA sequence with a length of 7 bp
PWM_FILE=$2 # path to PWM file from oRNAment

# {MAIN}
readarray -t PWM < "$PWM_FILE"
PROD=1.0
MIN_PROD=1.0
MAX_PROD=1.0
for ((i=0; i<${#SEQ}; i++)); do
    BASE=${SEQ:$i:1}
    IDX=$(echo -e "A\nC\nG\nU" | grep -n "$BASE" | cut -d: -f1)
    # extract the probabilities..
    # shellcheck disable=SC2206
    PROBS=(${PWM[$((i + 1))]})
    ## .. for a corresponding BASE    
    PROB=${PROBS[$IDX]}
    ## maximum probability
    MAX_PROB=${PROBS[1]}
    for ((j = 1; j < ${#PROBS[@]}; j++)); do
        if [ "$(echo "scale=6; $MAX_PROB < ${PROBS[j]}" | bc)" -eq 1 ]; then
            MAX_PROB=${PROBS[j]}
        fi
    done
    ## minimum probability
    MIN_PROB=${PROBS[1]}
    for ((j = 1; j < ${#PROBS[@]}; j++)); do
        if [ "$(echo "scale=6; $MIN_PROB > ${PROBS[j]}" | bc)" -eq 1 ]; then
            MIN_PROB=${PROBS[j]}
        fi
    done
    # multiply along the SEQ
    PROD=$(echo "scale=6; $PROD*$PROB" | bc)
    MIN_PROD=$(echo "scale=6; $MIN_PROD*$MIN_PROB" | bc)
    MAX_PROD=$(echo "scale=6; $MAX_PROD*$MAX_PROB" | bc)
done
# compute MSS
# MSS = (current_score – minimum_score)/(maximum_score – minimum_score) - essentialy, minmax 
# echo Results:
MSS=$(echo "scale=6; ($PROD-$MIN_PROD)/($MAX_PROD-$MIN_PROD)" | bc)
echo "$MSS"