#!/bin/bash
#
# cluster

SRCIP=
DSTIP=

CLI=
# PASS中$需要做转义处理
PASS=""

while read line
do
KY=$(echo $line | awk '{print $1}')
TY=$(echo $line | awk '{print $2}')

case "$TY" in
"string")
# string
SRCVALUE=$($CLI -c -h $SRCIP -a "$PASS" get "$KY")
SRCTTL=$($CLI -c -h $SRCIP -a "$PASS" ttl "$KY")

$CLI -c -h $DSTIP -a "$PASS" set "$KY" "$SRCVALUE"
if [ $SRCTTL -gt 0 ]
then
$CLI -c -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"hash")
# hash
FLD=$(echo $line | awk '{print $3}')
SRCVALUE=$($CLI -c -h $SRCIP -a "$PASS" hget "$KY" "$FLD")
SRCTTL=$($CLI -c -h $SRCIP -a "$PASS" ttl "$KY")

$CLI -c -h $DSTIP -a "$PASS" hset "$KY" "$FLD" "$SRCVALUE"
if [ $SRCTTL -gt 0 ]
then
$CLI -c -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"list")
# list
$CLI -c -h $DSTIP -a "$PASS" del "$KY"
LSIZE=$($CLI -c -h $SRCIP -a "$PASS" llen "$KY")
SRCTTL=$($CLI -c -h $SRCIP -a "$PASS" ttl "$KY")

for ((i=0;i<$LSIZE;i++))
do
  LV=$($CLI -c -h $SRCIP -a "$PASS" lindex "$KY" $i)
  $CLI -c -h $DSTIP -a "$PASS" lpush "$KY" $LV
done

if [ $SRCTTL -gt 0 ]
then
$CLI -c -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"set")
# set
$CLI -c -h $DSTIP -a "$PASS" del "$KY"
COUNT=$($CLI -c -h $SRCIP -a "$PASS" scard "$KY")
SRCTTL=$($CLI -c -h $SRCIP -a "$PASS" ttl "$KY")

if [ $COUNT -gt 100 ]
then
SV=$($CLI -c -h $SRCIP -a "$PASS" SMEMBERS "$KY")
$CLI -c -h $DSTIP -a "$PASS" sadd "$KY" "$SV"
else
curnum=0
while true
do
$CLI -c -h $SRCIP -a "$PASS" sscan "$KY" $curnum count 1 > sk1
awk 'NR>1{print}' sk1 > sk2
while read skline
do
$CLI -c -h $DSTIP -a "$PASS" sadd "$KY" "$skline"
done < sk2
curnum=$(head -1 sk1)
if [ $curnum -eq 0 ]
then
break
fi
done
fi

if [ $SRCTTL -gt 0 ]
then
$CLI -c -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"zset")
# zset
$CLI -c -h $DSTIP -a "$PASS" del "$KY"
SRCTTL=$($CLI -c -h $SRCIP -a "$PASS" ttl "$KY")

curnum=0
while true
do
$CLI -c -h $SRCIP -a "$PASS" zscan "$KY" $curnum count 1 > zsk1
awk 'NR>1{print}' zsk1 > zsk2
sed -i ':a;N;s/\n/ /g;ta' zsk2
awk 'BEGIN{i=0}END{for(;i<=NF-1;i++){print $(NF-i)}}' zsk2 > zsk3
sed -i ':a;N;s/\n/ /g;ta' zsk3
ZV=$(cat zsk3)
$CLI -c -h $DSTIP -a "$PASS" zadd "$KY" $ZV

curnum=$(head -1 zsk1)
if [ $curnum -eq 0 ]
then
break
fi
done
if [ $SRCTTL -gt 0 ]
then
$CLI -c -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi

;;
esac

done < $1
