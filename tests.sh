#!/bin/bash -e

# run unittest for druntime
cd ../druntime && make -j4 -f posix.mak BUILD=debug unittest

# run unittest for phobos
cd ../phobos && make -j4 -f posix.mak BUILD=debug unittest

# run druntime Martin's suite
cd ../druntime && make -j4 -f posix.mak BUILD=debug benchmark

# run dustmite
dmd dustmite/dustmite.d dustmite/splitter.d -I../druntime/import/ -L../phobos/generated/linux/debug/64/libphobos2.a -ofdm
rm -rf ../druntime.reduced && cd ../druntime && ../tests/dm --force . 'grep -nR HAVE_FORK'

# build vibe.d and test under stress
cd ./vibe.d/examples/bench-http-server && dub -f build
cd ./vibe.d/examples/bench-http-server/ && ./bench-http-server &
tokill=$!
sleep 1 # time for vibe to wakeup
# siege -b -c 50 -t1M  -f siege_urls.txt  --quiet
kill -15 $tokill
