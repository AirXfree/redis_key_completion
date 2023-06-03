#!/bin/bash
#
# sentinel

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
SRCVALUE=$($CLI -h $SRCIP -a "$PASS" get "$KY")
SRCTTL=$($CLI -h $SRCIP -a "$PASS" ttl "$KY")

if [ $SRCTTL -ne -2 ]
then
$CLI -h $DSTIP -a "$PASS" set "$KY" "$SRCVALUE"
fi

if [ $SRCTTL -gt 0 ]
then
$CLI -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"hash")
# hash
FLD=$(echo $line | awk '{print $3}')
SRCVALUE=$($CLI -h $SRCIP -a "$PASS" hget "$KY" "$FLD")
SRCTTL=$($CLI -h $SRCIP -a "$PASS" ttl "$KY")

if [ $SRCTTL -ne -2 ]
then
$CLI -h $DSTIP -a "$PASS" hset "$KY" "$FLD" "$SRCVALUE"
fi

if [ $SRCTTL -gt 0 ]
then
$CLI -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"list")
# list
$CLI -h $DSTIP -a "$PASS" del "$KY"
LSIZE=$($CLI -h $SRCIP -a "$PASS" llen "$KY")
SRCTTL=$($CLI -h $SRCIP -a "$PASS" ttl "$KY")

if [ $SRCTTL -ne -2 ]
then
for ((i=0;i<$LSIZE;i++))
do
  LV=$($CLI -h $SRCIP -a "$PASS" lindex "$KY" $i)
  $CLI -h $DSTIP -a "$PASS" lpush "$KY" $LV
done
fi

if [ $SRCTTL -gt 0 ]
then
$CLI -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"set")
# set
$CLI -h $DSTIP -a "$PASS" del "$KY"
COUNT=$($CLI -h $SRCIP -a "$PASS" scard "$KY")
SRCTTL=$($CLI -h $SRCIP -a "$PASS" ttl "$KY")

if [ $SRCTTL -ne -2 ]
then
if [ $COUNT -gt 100 ]
then
SV=$($CLI -h $SRCIP -a "$PASS" SMEMBERS "$KY")
$CLI -h $DSTIP -a "$PASS" sadd "$KY" "$SV"
else
curnum=0
while true
do
$CLI -h $SRCIP -a "$PASS" sscan "$KY" $curnum count 1 > sk1
awk 'NR>1{print}' sk1 > sk2
while read skline
do
$CLI -h $DSTIP -a "$PASS" sadd "$KY" "$skline"
done < sk2
curnum=$(head -1 sk1)
if [ $curnum -eq 0 ]
then
break
fi
done
fi
fi

if [ $SRCTTL -gt 0 ]
then
$CLI -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi
;;

"zset")
# zset
$CLI -h $DSTIP -a "$PASS" del "$KY"
SRCTTL=$($CLI -h $SRCIP -a "$PASS" ttl "$KY")

if [ $SRCTTL -ne -2 ]
then
curnum=0
while true
do
$CLI -h $SRCIP -a "$PASS" zscan "$KY" $curnum count 1 > zsk1
awk 'NR>1{print}' zsk1 > zsk2
sed -i ':a;N;s/\n/ /g;ta' zsk2
awk 'BEGIN{i=0}END{for(;i<=NF-1;i++){print $(NF-i)}}' zsk2 > zsk3
sed -i ':a;N;s/\n/ /g;ta' zsk3
ZV=$(cat zsk3)
$CLI -h $DSTIP -a "$PASS" zadd "$KY" $ZV

curnum=$(head -1 zsk1)
if [ $curnum -eq 0 ]
then
break
fi
done
fi

if [ $SRCTTL -gt 0 ]
then
$CLI -h $DSTIP -a "$PASS" expire "$KY" $SRCTTL
fi

;;
esac

done < $1
