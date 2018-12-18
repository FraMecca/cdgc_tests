// Written by Oskar Linde <oskar.lindeREM@OVEgmail.com>
// Found at http://www.digitalmars.com/webnews/newsgroups.php?art_group=digitalmars.D&article_id=46407
// Sightly modified by Leandro Lucarella <llucax@gmail.com>
// (changed the main loop not to be endless and ported to Tango)

import std.random;
import core.stdc.stdlib;

const IT = 125; // number of iterations, each creates an object
const BYTES = 1_000_000; // ~1MiB per object
const N = 50; // ~50MiB of initial objects


class C
{
	C c; // makes the compiler not set NO_SCAN
	long[BYTES/long.sizeof] data;
}

void main() {
    // Mt19937 rand;
	C[] objs;
       	objs.length = N;
	foreach (ref o; objs) {
		o = new C;
		foreach (ref x; o.data)
			x = rand(); // maybe not what was implied in the original D1 source
	}
	for (int i = 0; i < IT; ++i) {
		C o = new C;
		foreach (ref x; o.data)
            x = rand; // see above
		// do something with the data...
	}
}

