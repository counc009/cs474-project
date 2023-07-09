#!/usr/bin/bash
# This script should be run from the vcgen directory

PATH_TO_BENCHMARK_REPO=../../cs474-project/

for f in $PATH_TO_BENCHMARK_REPO/verified/*/*
do
  echo $f
  time ./verify.sh $f
done
