set -e

# the layout of my working directory is the following:
# .
# |-- cdgc_tests (this folder)
# |-- dmd 
# |-- druntime_cdgc (contains my WIP implementation)
# |-- druntime_master (the mainline GC, HEAD @ 14bd877bc51014baf9090175f2e690d8e1ec3a4a)
# |-- phobos (it needs to be recompiled and linked to the desired runtime)

branch=$1
cwd=$(pwd)

# point druntime folder to the correct branch
cd ~/dlang && rm -f druntime && ln -s druntime_$branch druntime
cd $cwd

# run druntime Martin's suite
cd ../druntime && make -j1 -f posix.mak > /dev/null
make -C ../phobos/ -f posix.mak -B > /dev/null # always recompile
cd ../druntime && make -j1 -f posix.mak benchmark | grep MIN # grep only the results

# compile all the converted d1 files and profile them
GCARGS=--DRT-gcopt=profile:1
echo "compiling d1 programs..."
cd $cwd/d1/micro
for f in $(ls *.d)
do
    dmd -I../../../phobos/ \
        -I../../../druntime/import/ \
        -L-L../../../phobos/generated/linux/release/64/\
        $f
done

# conalloc and concpu are included in Martin's benchmarks
echo "voronoi -n 30000" && ./voronoi -n 30000 $GCARGS
echo 'sbtree "16":' && ./sbtree 16 $GCARGS
echo 'split "bible.txt 2":' && ./split bible.txt 2 $GCARGS
echo 'em3d "-n 4000 -d 300 -i 74":' && ./em3d -n 4000 -d 300 -i 74 $GCARGS
# echo 'bh "4000":' &&  ./bh -b 4000 $GCARGS # very slow
echo 'tsp "-c 1000000":' && ./tsp -c 1000000 $GCARGS
echo 'bisort "-s 2000000":' && ./bisort -s 2000000 $GCARGS
cd $cwd
