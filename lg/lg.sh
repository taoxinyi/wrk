#!/bin/bash
# usage ./lg.sh -c 100 -t 1 -d 1 -f q2.txt -h http://example.com
while getopts "c:t:d:f:h:" optname; do
  case "$optname" in
  'c') connections="$OPTARG" ;;
  't') threads="$OPTARG" ;;
  'd') duration="$OPTARG" ;;
  'f') playback_file="$OPTARG" ;;
  'h') host="$OPTARG" ;;
  '?')
    echo "Unknown option $OPTARG"
    exit
    ;;
  ':')
    echo "No argument value for option $OPTARG"
    exit
    ;;
  *)
    echo 'Unknown error while processing options'
    exit
    ;;
  esac
done
echo "wrk -c ${connections} -t ${threads} -d ${duration} -s lg.lua ${host} with ${playback_file}"
export FILE="$playback_file"
export THREADS="$threads"
export CONNECTIONS="$connections"

wrk -c "${connections}" -t "${threads}" -d "${duration}" -s lg.lua "${host}"

#OUT=$(wrk -c "${connections}" -t "${threads}" -d "${duration}" -s lg.lua "${host}" 2> errFile)
#ERR=$(<errFile)
#echo "OUT----"
#echo "$OUT"
#echo "ERR----"
#echo "$ERR"
