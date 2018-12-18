set -e
cd .. && make -C ../phobos/ BUILD=debug  -f posix.mak # recompile runtime if needed
cd benchmark

# compile small benchmark programs
for fp in $(ls aabench)
do
    dmd -debug -L-L../../phobos/generated/linux/debug/64/  -I../../druntime/import/ -I../../phobos/ -g aabench/$fp -ofbin/$(basename $fp .d)
    echo compiled $fp
done
for fp in $(ls gcbench)
do
    dmd -debug -L-L../../phobos/generated/linux/debug/64/  -I../../druntime/import/ -I../../phobos/ -g gcbench/$fp -ofbin/$(basename $fp .d)
    echo compiled $fp
done
for fp in $(ls d1)
do
    dmd -debug -L-L../../phobos/generated/linux/debug/64/  -I../../druntime/import/ -I../../phobos/ -g d1/$fp -ofd1bin/$(basename $fp .d)
    echo compiled $fp
done

rm bin/*.o -f
rm bin/rand_*
for fp in $(ls bin | grep -v stats | grep -v small) # not enough ram for rand_small
do
    echo exec: $fp
    ./bin/$fp --DRT-gcopt=fork:1
    mv collect.stats $fp.fork:1.stats
done
for fp in $(ls bin | grep -v stats)
do
    echo exec: $fp
    ./bin/$fp --DRT-gcopt=fork:0
    mv collect.stats $fp.fork:0.stats
done

# now dustmite
cd ../dustmite && dmd -debug -L-L../../phobos/generated/linux/debug/64/  -I../../druntime/import/ -I../../phobos/ -g dustmite.d splitter.d
echo "dustmite compiled"
rm ../../druntime/src.reduced/ -rf
./dustmite --force ../../druntime/src/ 'grep -nR HAVE_FORK' --DRT-gcopt=fork:0
mv collect.stats ../benchmark/cdgc.dustmite.fork:0.stats
rm ../../druntime/src.reduced/ -rf
./dustmite --force ../../druntime/src/ 'grep -nR HAVE_FORK' --DRT-gcopt=fork:1
mv collect.stats ../benchmark/cdgc.dustmite.fork:1.stats

# d1 programs have cli switches
cd ../d1bin
GCARGS=--DRT-gcopt=fork:0
echo "voronoi -n 30000" && ./voronoi -n 30000 $GCARGS && mv collect.stats voronoi.collect.fork:0.stats
echo 'sbtree "16":' && ./sbtree 16 $GCARGS && mv collect.stats sbtree.collect.fork:0.stats
echo 'split "bible.txt 2":' && ./split bible.txt 2 $GCARGS && mv collect.stats split.collect.fork:0.stats
echo 'em3d "-n 4000 -d 300 -i 74":' && ./em3d -n 4000 -d 300 -i 74 $GCARGS && mv collect.stats em3d.collect.fork:0.stats
echo 'tsp "-c 1000000":' && ./tsp -c 1000000 $GCARGS && mv collect.stats tsp.collect.fork:0.stats
echo 'bisort "-s 2000000":' && ./bisort -s 2000000 $GCARGS && mv collect.stats bisort.collect.fork:0.stats
GCARGS=--DRT-gcopt=fork:1
echo "voronoi -n 30000" && ./voronoi -n 30000 $GCARGS && mv collect.stats voronoi.collect.fork:1.stats
echo 'sbtree "16":' && ./sbtree 16 $GCARGS && mv collect.stats sbtree.collect.fork:1.stats
echo 'split "bible.txt 2":' && ./split bible.txt 2 $GCARGS && mv collect.stats split.collect.fork:1.stats
echo 'em3d "-n 4000 -d 300 -i 74":' && ./em3d -n 4000 -d 300 -i 74 $GCARGS && mv collect.stats em3d.collect.fork:1.stats
echo 'tsp "-c 1000000":' && ./tsp -c 1000000 $GCARGS && mv collect.stats tsp.collect.fork:1.stats
echo 'bisort "-s 2000000":' && ./bisort -s 2000000 $GCARGS && mv collect.stats bisort.collect.fork:1.stats
