// Written by Leandro Lucarella
//
// The goal of this program is to do very CPU intensive work in threads

import core.thread: Thread;
import core.atomic;
import std.stdio;
import std.file;
import std.digest.sha;
import std.conv: to;

auto N = 100;
auto NT = 2;
ubyte[] BYTES;
shared(int) running; // Atomic

void main(char[][] args)
{
	auto fname = args[0];
	if (args.length > 3)
		fname = args[3];
	if (args.length > 2)
		NT = to!(int)(args[2]);
	if (args.length > 1)
		N = to!(int)(args[1]);
	N /= NT;
	atomicStore!(MemoryOrder.seq)(running, NT);
	BYTES = cast(ubyte[]) readText(fname);
	auto threads = new Thread[NT];
	foreach(ref thread; threads) {
		thread = new Thread(&doSha);
		thread.start();
	}
	while (atomicLoad(running)) {
		auto a = new void[](BYTES.length / 4);
		a[] = cast(void[]) BYTES[];
		Thread.yield();
	}
	foreach(thread; threads)
		thread.join();
}

void doSha()
{
	for (size_t i = 0; i < N; i++) {
		auto sha = new SHA512Digest();
		sha.put(BYTES);
	}
	atomicOp!("+=", shared(int), int) (running, -1);
}

