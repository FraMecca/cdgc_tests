cd .. && make -C ../phobos/ BUILD=debug  -f posix.mak  && dmd -I../druntime/import/ -I../phobos/ -L-L../phobos/generated/linux/debug/64 -g rand_large.d
cd benchmark

# compile small benchmark programs
for fp in $(ls aabench)
do
    dmd -debug -L-L../../phobos/generated/linux/debug/64/  -I../../druntime/import/ -I../../phobos/ -g aabench/$fp -ofbin/$(basename $fp .d)
    echo compilato $fp
done
for fp in $(ls gcbench)
do
    dmd -debug -L-L../../phobos/generated/linux/debug/64/  -I../../druntime/import/ -I../../phobos/ -g gcbench/$fp -ofbin/$(basename $fp .d)
    echo compilato $fp
done

rm bin/*.o -f
rm bin/rand_*
for fp in $(ls bin | grep -v stats | grep -v small)
do
    echo exec: $fp
    ./bin/$fp --DRT-gcopt=fork:1
    mv collect.stats cdgc.$fp.fork:1.stats
done
for fp in $(ls bin | grep -v stats)
do
    echo exec: $fp
    ./bin/$fp --DRT-gcopt=fork:0
    mv collect.stats cdgc.$fp.fork:0.stats
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
