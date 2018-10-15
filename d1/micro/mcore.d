// Written by David Schima:
// http://www.digitalmars.com/webnews/newsgroups.php?art_group=digitalmars.D&article_id=103563
//
// Modified by Leandro Lucarella:
// * Removed initial "pause"
// * Removed performance counter
// * Adapted to D1/Tango
//
// Compiled with: -O -inline -release
//
// Timing with affinity for all 4 CPUs:  28390 milliseconds
// Timing with affinity for only 1 CPU:  533 milliseconds
//
// More about contention killing multi-core:
//
// import std.stdio, std.perf, core.thread;
//
// void main() {
//    writeln("Set affinity, then press enter.");
//    readln();
//
//    auto pc = new PerformanceCounter;
//    pc.start;
//
//    enum nThreads = 4;
//    auto threads = new Thread[nThreads];
//    foreach(ref thread; threads) {
//        thread = new Thread(&doStuff);
//        thread.start();
//    }
//
//    foreach(thread; threads) {
//        thread.join();
//    }
//
//    pc.stop;
//    writeln(pc.milliseconds);
// }
//
// void doStuff() {
//     foreach(i; 0..1_000_000) {
//        synchronized {}
//     }
// }
//
// Timing with affinity for all CPUs:  20772 ms.
// Timing with affinity for 1 CPU:  156 ms.
//
// Post on using spin locks in the GC to avoid contention:
// http://www.digitalmars.com/d/archives/digitalmars/D/More_on_GC_Spinlocks_80485.html

import core.thread: Thread;

void main() {
	enum nThreads = 4 ;
	auto threads = new Thread[nThreads];
	foreach(ref thread; threads) {
		thread = new Thread(&doAppending);
		thread.start();
	}

	foreach(thread; threads)
		thread.join();
}

void doAppending() {
	ulong[] arr;
	for (size_t i = 0; i < 1_000_000; i++)
		arr ~= i;
}

