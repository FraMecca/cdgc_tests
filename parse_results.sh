set -e
for f in $(ls benchmark/ | grep stats);
    do
    echo $f
    python3.6 parse.py benchmark/$f > results/$f.pd; rm benchmark/$f;
done
for f in $(ls benchmark/d1bin | grep stats);
    do
    echo $f
    python3.6 parse.py benchmark/d1bin/$f > results/$f.pd; rm benchmark/d1bin/$f;
done
