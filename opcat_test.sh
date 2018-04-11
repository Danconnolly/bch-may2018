#!/bin/bash
export LC_ALL=C.UTF-8

# to test the op_cat opcode, to ensure that it does not cause memory issues

# script based on https://github.com/matiu/opcode-tests/blob/master/stress-opcodes.sh
#CLI="/home/daniel/bin/bitcoin-cli -regtest "
CLI="docker exec --user bitcoin $(docker ps --filter name=bchabcmay -q) /usr/local/bin/bitcoin-cli -conf=/home/bitcoin/bitcoin.conf "
#CLITX="/home/daniel/bin/bitcoin-tx -regtest "
CLITX="docker exec --user bitcoin $(docker ps --filter name=bchabcmay -q) /usr/local/bin/bitcoin-tx -conf=/home/bitcoin/bitcoin.conf "
SCRIPT='1 1 XOR'
FEE=0.0001
COUNT=1
OUTPUTSPERTX=1

ECHO="echo "

command -v bc >/dev/null 2>&1 || { echo >&2 "ERROR: bc not found, install with apt install bc.  Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "ERROR: jq not found, install with apt install jq.  Aborting."; exit 1; }

$ECHO "TEST CASE DESCRIPTON"
$ECHO "  Script:$SCRIPT"
$ECHO "  (nr opcodes):`echo $SCRIPT | wc -w`"
$ECHO "  NR OF TXs: $COUNT"
$ECHO "  NR OF OUTPUTS PER TXs: $OUTPUTSPERTX"

function getUnspent () {
    $ECHO " == Getting UTXOs"
    ALL_UTXOS=`$CLI  listunspent | jq ".|=sort_by(.amount)|reverse|.[0:$COUNT]"`

    COUNTER=0
    while [  $COUNTER -lt $COUNT ]; do
        INDEX=$((1+COUNTER))
        UTXO=`echo $ALL_UTXOS| jq ".[-$INDEX]"`
        OUTPOINT=`echo $UTXO | jq .txid | sed -e 's/^"//' -e 's/"$//'`:0
        VALUE=`echo $UTXO | jq .amount | sed -e 's/^"//' -e 's/"$//'`

	if [ $VALUE != "null" ]; then
            UNSPENT="$UNSPENT $OUTPOINT|$VALUE"
	fi

        let COUNTER=COUNTER+1 
    done
}

function createTxs () {
    $ECHO " == Creating TXs"
    for UTXO in $UNSPENT; do
        O=`echo $UTXO| cut -d "|" -f 1`;
        V=`echo $UTXO| cut -d "|" -f 2`;

        VALUE=`echo "($V - $FEE)/$OUTPUTSPERTX" | bc -l`
        VALUE=`printf %.8f $VALUE`

        COUNTER=0
        TXCMD="$CLITX -create in=$O"
        while [  $COUNTER -lt $OUTPUTSPERTX ]; do
          TXCMD="$TXCMD outscript=$VALUE:\"$SCRIPT\""
          let COUNTER=COUNTER+1 
        done

	$ECHO "txcmd = $TXCMD"
        TX1=`eval $TXCMD`
	$ECHO "result = $TX1"
	RESULT=$($CLI signrawtransaction $TX1)
	COMPLETE=$(echo $RESULT | jq .complete)
	if [ $COMPLETE == "false" ]; then
	    $ECHO "ERROR: signing transaction failed, result=$RESULT"
	    exit 1
	fi
	TX=$(echo $RESULT | jq .hex  | sed -e 's/^"//' -e 's/"$//')
	$ECHO "signed = $TX"

        TXS="$TXS $TX|$V"
    done
    $ECHO "all txs = $TXS"
}

function sendTxs () {
    $ECHO " == Sending TXs"
    for TXVALUE in $TXS; do
        TX=`echo $TXVALUE| cut -d "|" -f 1`;
        V=`echo $TXVALUE| cut -d "|" -f 2`;

        TXID=`$CLI sendrawtransaction $TX`
        TXIDS="$TXIDS $TXID|$V"
    done
}


function createSpendTxs () {
    $ECHO " == Creating Spend TXs"
    for TXIDVALUE in $TXIDS ; do
        TXID=`echo $TXIDVALUE| cut -d "|" -f 1`;
        V=`echo $TXIDVALUE| cut -d "|" -f 2`;
        VALUE=`echo $VALUE - $FEE | bc`

        COUNTER=0
        TXCMD="$CLITX -create"
        while [  $COUNTER -lt $OUTPUTSPERTX ]; do
            TXCMD="$TXCMD  in=$TXID:$COUNTER"
          let COUNTER=COUNTER+1 
        done

        TXCMD="$TXCMD outscript=$VALUE:\"$SCRIPT\""
        TX1=`eval $TXCMD`
 

       STXS="$STXS $TX"
    done
}

function sendSpendTxs () {
    $ECHO " ## Sending Spend TXs, USING <SCRIPT> ## TX length:$LENGTH b"
    for TX in $STXS; do
        TXID=`$CLI sendrawtransaction $TX`
    done
}

getUnspent
$ECHO "unspent tx = $UNSPENT"

createTxs
#time sendTxs

#createSpendTxs
#time sendSpendTxs




