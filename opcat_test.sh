#!/bin/bash

# to test the op_cat opcode, to ensure that it does not cause memory issues
# DO NOT RUN THIS ON MAINNET - it loses funds and also exposes funds to theft
# script based on https://github.com/matiu/opcode-tests/blob/master/stress-opcodes.sh

# requires a local node on the testnet with monolith enabled and an active wallet with funds
# the script will take the first unspent txo it finds in the nodes wallet
# it will send a small tx to the second spending tx - this amount is unrecoverable
# it will send the remainder to a new address from the nodes wallet

# creates a funding tx with two outputs
#	first output script is valid, OP_CAT top of stack up to 520 bytes
#       second output script is invalid, OP_CAT top of stack up to 521 bytes
# then creates a tx for each output script, returning funds
# second tx should fail

# license: please feel free to copy this and use as needed.

export LC_ALL=en_US.UTF-8               # remove possible locale problems

CLI="/home/daniel/bin/bitcoin-cli "
#CLI="docker exec --user bitcoin $(docker ps --filter name=bchabcmay -q) /usr/local/bin/bitcoin-cli -conf=/home/bitcoin/bitcoin.conf "
CLITX="/home/daniel/bin/bitcoin-tx -testnet "
#CLITX="docker exec --user bitcoin $(docker ps --filter name=bchabcmay -q) /usr/local/bin/bitcoin-tx -conf=/home/bitcoin/bitcoin.conf "

# do several DUP CAT's but stay within the max size bounds
SCRIPT1="0x400102030405060708090A0B0C0D0E0F100102030405060708090A0B0C0D0E0F200102030405060708090A0B0C0D0E0F300102030405060708090A0B0C0D0E0F40 DUP CAT DUP CAT DUP CAT 0x080102030405060708 CAT SIZE 0x020802 NUMEQUALVERIFY"

# do many DUP CAT cycles, to make it just too big - will fail when spent
SCRIPT2="0x400102030405060708090A0B0C0D0E0F100102030405060708090A0B0C0D0E0F200102030405060708090A0B0C0D0E0F300102030405060708090A0B0C0D0E0F40 DUP CAT DUP CAT DUP CAT 0x09010203040506070809 CAT"

FEE=0.0001

command -v bc >/dev/null 2>&1 || { echo >&2 "ERROR: bc not found, install with apt install bc.  Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "ERROR: jq not found, install with apt install jq.  Aborting."; exit 1; }

RECOVERADDR=$($CLI getnewaddress | cut -d ":" -f 2)
echo "recovery address=$RECOVERADDR"

ALL_UTXOS=`$CLI  listunspent | jq ".|=sort_by(.amount)|reverse|.[0:1]"`
if [ "$ALL_UTXOS" == "[]" ]; then
    echo "no utxo's found."
    exit 1
fi
UTXO=`echo $ALL_UTXOS| jq ".[-1]"`
OUTTX=`echo $UTXO | jq .txid | sed -e 's/^"//' -e 's/"$//'`
OINDEX=$(echo $UTXO | jq .vout)
OUTPOINT=$(echo $OUTTX:$OINDEX)
VALUE=`echo $UTXO | jq .amount | sed -e 's/^"//' -e 's/"$//'`
echo "found utxo $OUTPOINT, value $VALUE"

HIGHVAL=$(echo "$VALUE - ($FEE * 3)" | bc -l)
HIGHVAL=$(printf %.8f $HIGHVAL)
LOWVAL=$(echo "$FEE * 2" | bc -l)
LOWVAL=$(printf %.8f $LOWVAL)

TXCMD="$CLITX -create in=$OUTPOINT outscript=$HIGHVAL:\"$SCRIPT1\" outscript=$LOWVAL:\"$SCRIPT2\""

FUNDTXRAW=$(eval $TXCMD)
FTXRAWSIGN=$($CLI signrawtransaction $FUNDTXRAW)
COMPLETE=$(echo $FTXRAWSIGN | jq .complete)
if [ $COMPLETE == "false" ]; then
    echo "ERROR: signing transaction failed, result=$FTXRAWSIGN"
    exit 1
fi
FTXRAWSIGN=$(echo $FTXRAWSIGN | jq .hex  | sed -e 's/^"//' -e 's/"$//')
FTXID=$($CLI sendrawtransaction $FTXRAWSIGN)
echo "funding tx sent, txid=$FTXID"

# spend first output, should pass
RETVAL=$(echo "$HIGHVAL - $FEE" | bc -l)
RETVAL=$(printf %.8f $RETVAL)
TXCMD="$CLITX -create in=$FTXID:0 outaddr=$RETVAL:$RECOVERADDR"
S1RAW=$(eval $TXCMD)
S1TXID=$($CLI sendrawtransaction $S1RAW)
echo "PASS: sent first spending tx, txid=$S1TXID"

# spend second output, should fail
TXCMD="$CLITX -create in=$FTXID:1 outaddr=$FEE:$RECOVERADDR"
S2RAW=$(eval $TXCMD)
echo "raw second spending tx=$S2RAW"
S2RESULT=$($CLI sendrawtransaction $S2RAW >/dev/null 2>&1)
if [ $? == 26 ]; then
    echo "PASS: send of second spending tx failed as expected"
else
    echo "FAIL: send of second spending tx did not fail as expected, result=$S2RESULT"
    exit 1
fi



