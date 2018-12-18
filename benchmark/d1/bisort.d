/*
A Java implementation of the bisort Olden benchmark.
The Olden benchmark implements a Bitonic Sort as described in:

G. Bilardi and A. Nicolau, "Adaptive Bitonic Sorting: An optimal parallel
algorithm for shared-memory machines." SIAM J. Comput. 18(2):216-228, 1998.

The benchmarks sorts N numbers where N is a power of 2. If the user provides
an input value that is not a power of 2, then we use the nearest power of
2 value that is less than the input value.

Converted to D and obtimized by leonardo maffi, V.1.0, Oct 31 2009.

Removed output unless an option is passed by Leandro Lucarella, 2010-08-04.
Downloaded from http://www.fantascienza.net/leonardo/js/
                http://www.fantascienza.net/leonardo/js/dolden_bisort.zip
*/

import core.stdc.stdio: printf, fprintf, stderr;
import core.stdc.stdlib: exit;
import core.stdc.time: CLOCKS_PER_SEC, clock;
import std.conv: to;
alias to!(int) toInt;


double myclock() {
    return clock() / cast(float)CLOCKS_PER_SEC;
}


/**
 * A class that represents a value to be sorted by the <tt>BiSort</tt>
 * algorithm.    We represents a values as a node in a binary tree.
 **/
final class Value {
    private int value;
    private Value left, right;

    static immutable bool FORWARD = false;
    static immutable bool BACKWARD = true;

    // These are used by the Olden benchmark random no. generator
    static immutable int CONST_m1 = 10000;
    static immutable int CONST_b = 31415821;
    static immutable int RANGE = 100;

    /**
     * Constructor for a node representing a value in the bitonic sort tree.
     * @param v the integer value which is the sort key
     **/
    this(int v) {
        value = v;
        left = right = null;
    }


    /**
     * Create a random tree of value to be sorted using the bitonic sorting algorithm.
     *
     * @param size the number of values to create.
     * @param seed a random number generator seed value
     * @return the root of the (sub) tree.
     **/
    static Value createTree(int size, int seed) {
        if (size > 1) {
            seed = random(seed);
            int next_val = seed % RANGE;

            Value retval = new Value(next_val);
            retval.left = createTree(size/2, seed);
            retval.right = createTree(size/2, skiprand(seed, size+1));
            return retval;
        } else {
            return null;
        }
    }


    /**
     * Perform a bitonic sort based upon the Bilardi and Nicolau algorithm.
     *
     * @param spr_val the "spare" value in the algorithm.
     * @param direction the direction of the sort (forward or backward)
     * @return the new "spare" value.
     **/
    int bisort(int spr_val, bool direction) {
        if (left is null) {
            if ((value > spr_val) ^ direction) {
                int tmpval = spr_val;
                spr_val = value;
                value = tmpval;
            }
        } else {
            int val = value;
            value = left.bisort(val, direction);
            bool ndir = !direction;
            spr_val = right.bisort(spr_val, ndir);
            spr_val = bimerge(spr_val, direction);
        }
        return spr_val;
    }


    /**
     * Perform the merge part of the bitonic sort. The merge part does
     * the actualy sorting.
     * @param spr_val the "spare" value in the algorithm.
     * @param direction the direction of the sort (forward or backward)
     * @return the new "spare" value
     **/
    int bimerge(int spr_val, bool direction) {
        int rv = value;
        Value pl = left;
        Value pr = right;

        bool rightexchange = (rv > spr_val) ^ direction;
        if (rightexchange) {
            value = spr_val;
            spr_val = rv;
        }

        while (pl !is null) {
            int lv = pl.value;
            Value pll = pl.left;
            Value plr = pl.right;
            rv = pr.value;
            Value prl = pr.left;
            Value prr = pr.right;

            bool elementexchange = (lv > rv) ^ direction;
            if (rightexchange) {
                if (elementexchange) {
                    pl.swapValRight(pr);
                    pl = pll;
                    pr = prl;
                } else {
                    pl = plr;
                    pr = prr;
                }
            } else {
                if (elementexchange) {
                    pl.swapValLeft(pr);
                    pl = plr;
                    pr = prr;
                } else {
                    pl = pll;
                    pr = prl;
                }
            }
        }

        if (left !is null) {
            value = left.bimerge(value, direction);
            spr_val = right.bimerge(spr_val, direction);
        }
        return spr_val;
    }


    /**
     * Swap the values and the right subtrees.
     * @param n the other subtree involved in the swap.
     **/
    void swapValRight(Value n) {
        int tmpv = n.value;
        Value tmpr = n.right;

        n.value = value;
        n.right = right;

        value = tmpv;
        right = tmpr;
    }


    /**
     * Swap the values and the left subtrees.
     * @param n the other subtree involved in the swap.
     **/
    void swapValLeft(Value n) {
        int tmpv = n.value;
        Value tmpl = n.left;

        n.value = value;
        n.left = left;

        value = tmpv;
        left = tmpl;
    }


    /**
     * Print out the nodes in the binary tree in infix order.
     **/
    void inOrder() {
        if (left !is null)
            left.inOrder();
        printf("%d\n", value);
        if (right !is null)
            right.inOrder();
    }


    /**
     * A random generator.    The original Olden benchmark uses its
     * own random generator.    We use the same one in the Java version.
     * @return the next random number in the sequence.
     **/
    private static int mult(int p, int q) {
        int p1 = p / CONST_m1;
        int p0 = p % CONST_m1;
        int q1 = q / CONST_m1;
        int q0 = q % CONST_m1;
        return ((p0 * q1 + p1 * q0) % CONST_m1) * CONST_m1 + p0 * q0;
    }


    /**
     * A routine to skip the next <i>n</i> random numbers.
     * @param seed the current random no. seed
     * @param n the number of numbers to skip
     **/
    private static int skiprand(int seed, int n) {
        for (; n != 0; n--)
            seed = random(seed);
        return seed;
    }


    /**
     * Return a random number based upon the seed value.
     * @param seed the random number seed value
     * @return a random number based upon the seed value.
     **/
    static int random(int seed) {
        int tmp = mult(seed, CONST_b) + 1;
        return tmp;
    }
}


final public class BiSort {
    private static int size = 0; // The number of values to sort.
    private static bool printMsgs = false; // Print information messages
    private static bool printResults = false; // Print the tree after each step


    /**
     * The main routine which creates a tree and sorts it a couple of times.
     * @param args the command line arguments
     **/
    public static final void main(char[][] args) {
        parseCmdLine(args);

        if (printMsgs)
            printf("Bisort with %d values\n", nextPow2(size+1) - 1);

        auto start2 = myclock();
        Value tree = Value.createTree(size, 12345768);
        auto end2 = myclock();
        int sval = Value.random(245867) % Value.RANGE;

        if (printResults) {
            tree.inOrder();
            printf("%d\n", sval);
        }

        if (printMsgs)
            printf("Beginning bitonic sort\n");

        auto start0 = myclock();
        sval = tree.bisort(sval, Value.FORWARD);
        auto end0 = myclock();

        if (printResults) {
            tree.inOrder();
            printf("%d\n", sval);
        }

        auto start1 = myclock();
        sval = tree.bisort(sval, Value.BACKWARD);
        auto end1 = myclock();

        if (printResults) {
            tree.inOrder();
            printf("%d\n", sval);
        }

        if (printMsgs) {
            printf("Creation time: %f\n", end2 - start2);
            printf("Time to sort forward = %f\n", end0 - start0);
            printf("Time to sort backward = %f\n", end1 - start1);
            printf("Total: %f\n", end1 - start0);
            printf("Done!\n");
        }
    }


    /**
     * Parse the command line options.
     * @param args the command line options.
     **/
    private static final void parseCmdLine(char[][] args) {
        int i = 1;
        char[] arg;

        while (i < args.length && args[i][0] == '-') {
            arg = args[i++];

            // check for options that require arguments
            if (arg == "-s") {
                if (i < args.length) {
                    size = toInt(args[i++]);
                } else {
                    throw new Exception("-l requires the number of levels");
                }
            } else if (arg == "-m") {
                printMsgs = true;
            } else if (arg == "-p") {
                printResults = true;
            } else if (arg == "-h") {
                usage();
            }
        }
        if (size == 0)
            usage();
    }


    /**
     * The usage routine which describes the program options.
     **/
    private static final void usage() {
        fprintf(stderr, "usage: bisort_d -s <size> [-p] [-i] [-h]\n");
        fprintf(stderr, "  -s the number of values to sort\n");
        fprintf(stderr, "  -m (print informative messages)\n");
        fprintf(stderr, "  -p (print the binary tree after each step)\n");
        fprintf(stderr, "  -h (print this message)\n");
        exit(0);
    }


    private static /*unsigned*/ int nextPow2(/*unsigned*/ int x) {
        if (x < 0)
            throw new Exception("x must be >= 0");
        x -= 1;
        x |= x >>  1;
        x |= x >>  2;
        x |= x >>  4;
        x |= x >>  8;
        x |= x >> 16;
        return x + 1;
    }
}


void main(char[][] args) {
    BiSort.main(args);
}
