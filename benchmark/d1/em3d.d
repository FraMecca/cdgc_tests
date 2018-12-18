/**
 * Java implementation of the <tt>em3d</tt> Olden benchmark.  This Olden
 * benchmark models the propagation of electromagnetic waves through
 * objects in 3 dimensions. It is a simple computation on an irregular
 * bipartite graph containing nodes representing electric and magnetic
 * field values.
 *
 * <p><cite>
 * D. Culler, A. Dusseau, S. Goldstein, A. Krishnamurthy, S. Lumetta, T. von
 * Eicken and K. Yelick. "Parallel Programming in Split-C".  Supercomputing
 * 1993, pages 262-273.
 * </cite>
 *
 * Java code converted to D by leonardo maffi, V.1.0, Oct 25 2009.
 *
 * Removed output unless an option is passed by Leandro Lucarella, 2010-08-04.
 * Downloaded from http://www.fantascienza.net/leonardo/js/
 *                 http://www.fantascienza.net/leonardo/js/dolden_em3d.zip
 **/


import core.stdc.stdio: printf, sprintf;
import core.stdc.stdlib: exit;
import core.stdc.time: CLOCKS_PER_SEC, clock;
import std.conv: to;
alias to!(int) toInt;


double myclock() {
    return clock() / cast(double)CLOCKS_PER_SEC;
}


/**
Basic uniform random generator: Minimal Standard in Park and
Miller (1988): "Random Number Generators: Good Ones Are Hard to
Find", Comm. of the ACM, 31, 1192-1201.
Parameters: m = 2^31-1, a=48271.

Adapted from Pascal code by Jesper Lund:
http://www.gnu-pascal.de/crystal/gpc/en/mail1390.html
*/
final class Random {
    const int m = int.max;
    const int a = 48_271;
    const int q = m / a;
    const int r = m % a;
    public long seed;

    this(long the_seed) {
        this.seed = the_seed;
    }

    public double nextDouble() {
        int k = to!int(seed / q);
        seed = a * (seed - k * q) - r * k;
        if (seed < 1)
            seed += m;
        return cast(double)seed / m;
    }

    public int nextInt(long max) {
        long n = max + 1;
        int k = cast(int)(n * this.nextDouble());
        return (k == n) ? k - 1 : k;
    }
}


/**
 * This class implements nodes (both E- and H-nodes) of the EM graph. Sets
 * up random neighbors and propagates field values among neighbors.
 */
final class Node
{
  /**
   * The value of the node.
   **/
  double value;
  /**
   * The next node in the list.
   **/
  private Node next;
  /**
   * Array of nodes to which we send our value.
   **/
  Node[] toNodes;
  /**
   * Array of nodes from which we receive values.
   **/
  Node[] fromNodes;
  /**
   * Coefficients on the fromNodes edges
   **/
  double[] coeffs;
  /**
   * The number of fromNodes edges
   **/
  int fromCount;
  /**
   * Used to create the fromEdges - keeps track of the number of edges that have
   * been added
   **/
  int fromLength;

  /**
   * A random number generator.
   **/
  private static Random rand;

  /**
   * Initialize the random number generator
   **/
  public static void initSeed(long seed)
  {
    rand = new Random(seed);
  }

  /**
   * Constructor for a node with given `degree'.   The value of the
   * node is initialized to a random value.
   **/
  this(int degree)
  {
    value = rand.nextDouble();
    // create empty array for holding toNodes
    toNodes = new Node[degree];

    next = null;
    fromNodes = null;
    coeffs = null;
    fromCount = 0;
    fromLength = 0;
  }

  /**
   * Create the linked list of E or H nodes.  We create a table which is used
   * later to create links among the nodes.
   * @param size the no. of nodes to create
   * @param degree the out degree of each node
   * @return a table containing all the nodes.
   **/
  static Node[] fillTable(int size, int degree)
  {
    Node[] table = new Node[size];

    Node prevNode = new Node(degree);
    table[0] = prevNode;
    for (int i = 1; i < size; i++) {
      Node curNode = new Node(degree);
      table[i] = curNode;
      prevNode.next = curNode;
      prevNode = curNode;
    }
    return table;
  }

  /**
   * Create unique `degree' neighbors from the nodes given in nodeTable.
   * We do this by selecting a random node from the give nodeTable to
   * be neighbor. If this neighbor has been previously selected, then
   * a different random neighbor is chosen.
   * @param nodeTable the list of nodes to choose from.
   **/
  void makeUniqueNeighbors(Node[] nodeTable)
  {
    for (int filled = 0; filled < toNodes.length; filled++) {
      int k;
      Node otherNode;

      do {
    // generate a random number in the correct range
    int index = rand.nextInt(nodeTable.length - 1);

    // find a node with the random index in the given table
    otherNode = nodeTable[index];

    for (k = 0; k < filled; k++) {
      if (otherNode == toNodes[k]) break; // fixed a bug of the original Java code
    }
      } while (k < filled);

      // other node is definitely unique among "filled" toNodes
      toNodes[filled] = otherNode;

      // update fromCount for the other node
      otherNode.fromCount++;
    }
  }

  /**
   * Allocate the right number of FromNodes for this node. This
   * step can only happen once we know the right number of from nodes
   * to allocate. Can be done after unique neighbors are created and known.
   *
   * It also initializes random coefficients on the edges.
   **/
  void makeFromNodes()
  {
    fromNodes = new Node[fromCount]; // nodes fill be filled in later
    coeffs = new double[fromCount];
  }

  /**
   * Fill in the fromNode field in "other" nodes which are pointed to
   * by this node.
   **/
  void updateFromNodes()
  {
    for (int i = 0; i < toNodes.length; i++) {
      Node otherNode = toNodes[i];
      int count = otherNode.fromLength++;
      otherNode.fromNodes[count] = this;
      otherNode.coeffs[count] = rand.nextDouble();
    }
  }

  /**
   * Get the new value of the current node based on its neighboring
   * from_nodes and coefficients.
   **/
  void computeNewValue()
  {
    for (int i = 0; i < fromCount; i++) {
      value -= coeffs[i] * fromNodes[i].value;
    }
  }

  int opApply(int delegate(ref Node) dg) {
    int result;
    for (Node current = this; current !is null; current = current.next) {
      result = dg(current);
      if (result)
        break;
    }
    return result;
  }

  public char* toCString()
  {
    static char[256] repr;
    sprintf(repr.ptr, "value %.17f, from_count %d", value, fromCount);
    return repr.ptr;
  }
}


/**
 * A class that represents the irregular bipartite graph used in
 * EM3D.  The graph contains two linked structures that represent the
 * E nodes and the N nodes in the application.
 **/
final class BiGraph
{
  /**
   * Nodes that represent the electrical field.
   **/
  Node eNodes;
  /**
   * Nodes that representhe the magnetic field.
   **/
  Node hNodes;

  /**
   * Construct the bipartite graph.
   * @param e the nodes representing the electric fields
   * @param h the nodes representing the magnetic fields
   **/
  this(Node e, Node h)
  {
    eNodes = e;
    hNodes = h;
  }

  /**
   * Create the bi graph that contains the linked list of
   * e and h nodes.
   * @param numNodes the number of nodes to create
   * @param numDegree the out-degree of each node
   * @param verbose should we print out runtime messages
   * @return the bi graph that we've created.
   **/
  static BiGraph create(int numNodes, int numDegree, bool verbose)
  {
    Node.initSeed(783);

    // making nodes (we create a table)
    if (verbose) printf("making nodes (tables in orig. version)\n");
    Node[] hTable = Node.fillTable(numNodes, numDegree);
    Node[] eTable = Node.fillTable(numNodes, numDegree);

    // making neighbors
    if (verbose) printf("updating from and coeffs\n");
    foreach (n; hTable[0])
      n.makeUniqueNeighbors(eTable);
    foreach (n; eTable[0])
      n.makeUniqueNeighbors(hTable);

    // Create the fromNodes and coeff field
    if (verbose) printf("filling from fields\n");
    foreach (n; hTable[0])
      n.makeFromNodes();
    foreach (n; eTable[0])
      n.makeFromNodes();

    // Update the fromNodes
    foreach (n; hTable[0])
      n.updateFromNodes();
    foreach (n; eTable[0])
      n.updateFromNodes();

    BiGraph g = new BiGraph(eTable[0], hTable[0]);
    return g;
  }

  /**
  * Update the field values of e-nodes based on the values of
  * neighboring h-nodes and vice-versa.
  **/
  void compute() {
    foreach (n; eNodes)
      n.computeNewValue();
    foreach (n; hNodes)
      n.computeNewValue();
  }

  /**
  * Print out the values of the e and h nodes.
  **/
  public void print() {
    foreach (n; eNodes)
      printf("E: %s\n", n.toCString());
    foreach (n; hNodes)
      printf("H: %s\n", n.toCString());
    printf("\n");
  }
}

public class Em3d1
{
  /**
   * The number of nodes (E and H)
   **/
  private static int numNodes = 0;
  /**
   * The out-degree of each node.
   **/
  private static int numDegree = 0;
  /**
   * The number of compute iterations
   **/
  private static int numIter = 1;
  /**
   * Should we print the results and other runtime messages
   **/
  private static bool printResult = false;
  /**
   * Print information messages?
   **/
  private static bool printMsgs = false;

  /**
   * The main roitine that creates the irregular, linked data structure
   * that represents the electric and magnetic fields and propagates the
   * waves through the graph.
   * @param args the command line arguments
   **/
  public static final void main(char[][] args)
  {
    parseCmdLine(args);

    if (printMsgs)
      printf("Initializing em3d random graph...\n");
    auto start0 = myclock();
    BiGraph graph = BiGraph.create(numNodes, numDegree, printResult);
    auto end0 = myclock();

    // compute a single iteration of electro-magnetic propagation
    if (printMsgs)
      printf("Propagating field values for %d iteration(s)...\n", numIter);
    auto start1 = myclock();
    for (int i = 0; i < numIter; i++) {
      graph.compute();
    }
    auto end1 = myclock();

    // print current field values
    if (printResult)
      graph.print();

    if (printMsgs) {
      printf("EM3D build time %.2f\n", end0 - start0);
      printf("EM3D compute time %.2f\n", end1 - start1);
      printf("EM3D total time %.2f\n", end1 - start0);
      printf("Done!\n");
    }
  }


  /**
   * Parse the command line options.
   * @param args the command line options.
   **/
  private static final void parseCmdLine(char[][] args)
  {
    int i = 1;
    char[] arg;

    while (i < args.length && args[i][0] == '-') {
      arg = args[i++];

      // check for options that require arguments
      if (arg == "-n") {
        if (i < args.length) {
          numNodes = toInt(args[i++]);
        } else throw new Exception("-n requires the number of nodes");
      } else if (arg == "-d") {
    if (i < args.length) {
      numDegree = toInt(args[i++]);
    } else throw new Exception("-d requires the out degree");
      } else if (arg == "-i") {
    if (i < args.length) {
      numIter = toInt(args[i++]);
    } else throw new Exception("-i requires the number of iterations");
      } else if (arg == "-p") {
        printResult = true;
      } else if (arg == "-m") {
        printMsgs = true;
      } else if (arg == "-h") {
    usage();
      }
    }
    if (numNodes == 0 || numDegree == 0) usage();
  }

  /**
  * The usage routine which describes the program options.
  **/
    private static final void usage() {
    printf("usage: em3d -n <nodes> -d <degree> [-p] [-m] [-h]\n");
    printf("    -n the number of nodes\n");
    printf("    -d the out-degree of each node\n");
    printf("    -i the number of iterations\n");
    printf("    -p (print detailed results)\n");
    printf("    -m (print informative messages)\n");
    printf("    -h (this message)\n");
    exit(0);
  }
}


void main(char[][] args) {
    Em3d1.main(args);
}
