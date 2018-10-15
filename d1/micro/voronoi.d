/*
Translated by Leonardo Fantascienza, downloaded from http://codepad.org/xGDCS3KO
Modified by Leandro Lucarella to be really quiet when -v is not used.

A D implementation of the Voronoi Olden benchmark. Voronoi
generates a random set of points and computes a Voronoi diagram for
the points.

L. Guibas and J. Stolfi. "General Subdivisions and Voronoi Diagrams"
ACM Trans. on Graphics 4(2):74-123, 1985.

The Java version of voronoi (slightly) differs from the C version
in several ways.  The C version allocates an array of 4 edges and
uses pointer addition to implement quick rotate operations.  The
Java version does not use pointer addition to implement these
operations.

Run it with:
time voronoi1_d -n 100000 -v
*/
import core.stdc.stdio: printf, fprintf, sprintf, stderr;
import std.math: sqrt, exp, log;
import core.stdc.stdlib: exit;
import core.stdc.time: CLOCKS_PER_SEC, clock;
import std.conv: to;
alias to!(int) toInt;


double myclock() {
    return clock() / cast(double)CLOCKS_PER_SEC;
}


class Stack(T) {
    T[] data;
    ulong length() { return data.length; }
    bool empty() { return data.length == 0; }
    void push(T item) { data ~= item; }
    T pop() {
        assert(data.length);
        T last = data[$-1];
        data.length = data.length - 1;
        return last;
    }
}


/**
* A class that represents a wrapper around a double value so
* that we can use it as an 'out' parameter.  The java.lang.Double
* class is immutable.
**/
final class MyDouble {
    public double value;

    this(double d) {
        value = d;
    }

    public char* toCString() {
        auto repr = new char[64];
        sprintf(repr.ptr, "%f", value);
        return repr.ptr;
    }
}


/**
* Vector Routines from CMU vision library.
* They are used only for the Voronoi Diagram, not the Delaunay Triagulation.
* They are slow because of large call-by-value parameters.
**/
class Vec2 {
    double x,y;
    double norm;

    this() {}

    this(double xx, double yy) {
        x = xx;
        y = yy;
        norm =  x * x + y * y;
    }

    final public double X() {
        return x;
    }

    final public double Y() {
        return y;
    }

    final public double Norm() {
        return norm;
    }

    final public void setNorm(double d) {
        norm = d;
    }

    final public char* toCString() {
        auto repr = new char[256];
        sprintf(repr.ptr, "%f %f", x, y);
        return repr.ptr;
    }

    final Vec2 circle_center(Vec2 b, Vec2 c) {
        Vec2 vv1 = b.sub(c);
        double d1 = vv1.magn();
        vv1 = sum(b);
        Vec2 vv2 = vv1.times(0.5);
        if (d1 < 0.0)
          // there is no intersection point, the bisectors coincide.
            return vv2;
        else {
            Vec2 vv3 = b.sub(this);
            Vec2 vv4 = c.sub(this);
            double d3 = vv3.cprod(vv4) ;
            double d2 = -2.0 * d3 ;
            Vec2 vv5 = c.sub(b);
            double d4 = vv5.dot(vv4);
            Vec2 vv6 = vv3.cross();
            Vec2 vv7 = vv6.times(d4 / d2);
            return vv2.sum(vv7);
        }
    }

    /**
    * cprod: forms triple scalar product of [u,v,k], where k = u cross v
    * (returns the magnitude of u cross v in space)
    **/
    final double cprod(Vec2 v) {
        return x * v.y - y * v.x;
    }

    /* V2_dot: vector dot product */
    final double dot(Vec2 v) {
        return x * v.x + y * v.y;
    }

    /* V2_times: multiply a vector by a scalar */
    final Vec2 times(double c) {
        return new Vec2(c * x, c * y);
    }

    /* V2_sum, V2_sub: Vector addition and subtraction */
    final Vec2 sum(Vec2 v) {
        return new Vec2(x + v.x, y + v.y);
    }

    final Vec2 sub(Vec2 v) {
        return new Vec2(x - v.x,y - v.y);
    }

    /* V2_magn: magnitude of vector */
    final double magn() {
        return sqrt(x * x + y * y);
    }

    /* returns k X v (cross product).  this is a vector perpendicular to v */
    final Vec2 cross() {
        return new Vec2(y, -x);
    }
} // Vec2 ends


/**
* A class that represents a voronoi diagram.  The diagram is represnted
* as a binary tree of points.
**/
final class Vertex : Vec2 {
    /**
    * The left and right child of the tree that represents the voronoi diagram.
    **/
    Vertex left, right;

    /**
    * Seed value used during tree creation.
    **/
    static int seed;

    this() { }

    this(double x, double y) {
        super(x, y);
        left = null;
        right = null;
    }

    public void setLeft(Vertex l) {
        left = l;
    }

    public void setRight(Vertex r) {
        right = r;
    }

    public Vertex getLeft() {
        return left;
    }

    public Vertex getRight() {
        return right;
    }

    /**
    * Generate a voronoi diagram
    **/
    static Vertex createPoints(int n, MyDouble curmax, int i) {
        if (n < 1 )
            return null;

        Vertex cur = new Vertex();
        Vertex right = Vertex.createPoints(n / 2, curmax, i);
        i -= n/2;
        cur.x = curmax.value * exp(log(Vertex.drand()) / i);
        cur.y = Vertex.drand();
        cur.norm = cur.x * cur.x + cur.y * cur.y;
        cur.right = right;
        curmax.value = cur.X();
        Vertex left = Vertex.createPoints(n / 2, curmax, i - 1);
        cur.left = left;
        return cur;
    }

    /**
    * Builds delaunay triangulation.
    **/
    Edge buildDelaunayTriangulation(Vertex extra) {
        EdgePair retVal = buildDelaunay(extra);
        return retVal.getLeft();
    }

    /**
    * Recursive delaunay triangulation procedure
    * Contains modifications for axis-switching division.
    **/
    EdgePair buildDelaunay(Vertex extra) {
        EdgePair retval = null;
        if (getRight() !is null && getLeft() !is null)  {
            // more than three elements; do recursion
            Vertex minx = getLow();
            Vertex maxx = extra;

            EdgePair delright = getRight().buildDelaunay(extra);
            EdgePair delleft = getLeft().buildDelaunay(this);

            retval = Edge.doMerge(delleft.getLeft(), delleft.getRight(),
            delright.getLeft(), delright.getRight());

            Edge ldo = retval.getLeft();
            while (ldo.orig() != minx) {
                ldo = ldo.rPrev();
            }
            Edge rdo = retval.getRight();
            while (rdo.orig() != maxx) {
                rdo = rdo.lPrev();
            }

            retval = new EdgePair(ldo, rdo);

        } else if (getLeft() is null) {
            // two points
            Edge a = Edge.makeEdge(this, extra);
            retval = new EdgePair(a, a.symmetric());
        } else {
            // left, !right  three points
            // 3 cases: triangles of 2 orientations, and 3 points on a line. */
            Vertex s1 = getLeft();
            Vertex s2 = this;
            Vertex s3 = extra;
            Edge a = Edge.makeEdge(s1, s2);
            Edge b = Edge.makeEdge(s2, s3);
            a.symmetric().splice(b);
            Edge c = b.connectLeft(a);
            if (s1.ccw(s3, s2)) {
                retval = new EdgePair(c.symmetric(), c);
            } else {
                retval = new EdgePair(a, b.symmetric());
                if (s1.ccw(s2, s3))
                    c.deleteEdge();
            }
        }

        return retval;
    }

    /**
    * Print the tree
    **/
    void print() {
        Vertex tleft, tright;

        printf("X=%f  Y=%f\n", X(), Y());
        if (left is null)
            printf("NULL\n");
        else
            left.print();
        if (right is null)
            printf("NULL\n");
        else
            right.print();
    }

    /**
    * Traverse down the left child to the end
    **/
    Vertex getLow() {
        Vertex temp;
        Vertex tree = this;

        while ((temp=tree.getLeft()) !is null)
            tree = temp;
        return tree;
    }

    /****************************************************************/
    /*    Geometric primitives
    ****************************************************************/
    bool incircle(Vertex b, Vertex c, Vertex d) {
        // incircle, as in the Guibas-Stolfi paper
        double adx, ady, bdx, bdy, cdx, cdy, dx, dy, anorm, bnorm, cnorm, dnorm;
        double dret;
        Vertex loc_a,loc_b,loc_c,loc_d;

        int donedx,donedy,donednorm;
        loc_d = d;
        dx = loc_d.X(); dy = loc_d.Y(); dnorm = loc_d.Norm();
        loc_a = this;
        adx = loc_a.X() - dx; ady = loc_a.Y() - dy; anorm = loc_a.Norm();
        loc_b = b;
        bdx = loc_b.X() - dx; bdy = loc_b.Y() - dy; bnorm = loc_b.Norm();
        loc_c = c;
        cdx = loc_c.X() - dx; cdy = loc_c.Y() - dy; cnorm = loc_c.Norm();
        dret =  (anorm - dnorm) * (bdx * cdy - bdy * cdx);
        dret += (bnorm - dnorm) * (cdx * ady - cdy * adx);
        dret += (cnorm - dnorm) * (adx * bdy - ady * bdx);
        return (0.0 < dret) ? true : false;
    }

    bool ccw(Vertex b, Vertex c) {
        // TRUE iff this, B, C form a counterclockwise oriented triangle
        double dret;
        double xa,ya, xb, yb, xc, yc;
        Vertex loc_a, loc_b, loc_c;
        int donexa, doneya, donexb, doneyb, donexc, doneyc;

        loc_a = this;
        xa = loc_a.X();
        ya = loc_a.Y();
        loc_b = b;
        xb = loc_b.X();
        yb = loc_b.Y();
        loc_c = c;
        xc = loc_c.X();
        yc = loc_c.Y();
        dret = (xa-xc) * (yb-yc) - (xb-xc) * (ya-yc);
        return (dret  > 0.0)? true : false;
    }

    /**
    * A routine used by the random number generator
    **/
    static int mult(int p,int q) {
        int p1, p0, q1, q0;
        int CONST_m1 = 10000;

        p1 = p / CONST_m1; p0 = p % CONST_m1;
        q1 = q / CONST_m1; q0 = q % CONST_m1;
        return ((p0 * q1 + p1 * q0) % CONST_m1) * CONST_m1 + p0 * q0;
    }

    /**
    * Generate the nth random number
    **/
    static int skiprand(int seed, int n) {
        for (; n != 0; n--)
            seed = random(seed);
        return seed;
    }

    static int random(int seed) {
        int CONST_b = 31415821;

        seed = mult(seed, CONST_b) + 1;
        return seed;
    }

    static double drand() {
        double retval = (cast(double)(Vertex.seed = Vertex.random(Vertex.seed))) /
                        cast(double)2147483647;
        return retval;
    }
} // Vertex ends


/**
* A class that represents the quad edge data structure which implements
* the edge algebra as described in the algorithm.
* <p>
* Each edge contains 4 parts, or other edges.  Any edge in the group may
* be accessed using a series of rotate and flip operations.  The 0th
* edge is the canonical representative of the group.
* <p>
* The quad edge class does not contain separate information for vertice
* or faces; a vertex is implicitly defined as a ring of edges (the ring
* is created using the next field).
**/
final class Edge {
    /**
    * Group of edges that describe the quad edge
    **/
    Edge[] quadList;

    /**
    * The position of this edge within the quad list
    **/
    int     listPos;

    /**
    * The vertex that this edge represents
    **/
    Vertex  vertex;

    /**
    * Contains a reference to a connected quad edge
    **/
    Edge    next;

    /**
    * Create a new edge which.
    **/
    this(Vertex v, Edge[] ql, int pos) {
        vertex = v;
        quadList = ql;
        listPos = pos;
    }

    /**
    * Create a new edge which.
    **/
    this(Edge[] ql, int pos) {
        this(null, ql, pos);
    }

    /**
    * Create a string representation of the edge
    **/
    public char* toCString() {
        if (vertex !is null)
            return vertex.toCString();
        else
            assert(false);
            // return "None";
    }

    public static Edge makeEdge(Vertex o, Vertex d) {
        Edge[] ql = new Edge[4];
        ql[0] = new Edge(ql, 0);
        ql[1] = new Edge(ql, 1);
        ql[2] = new Edge(ql, 2);
        ql[3] = new Edge(ql, 3);

        ql[0].next = ql[0];
        ql[1].next = ql[3];
        ql[2].next = ql[2];
        ql[3].next = ql[1];

        Edge base = ql[0];
        base.setOrig(o);
        base.setDest(d);
        return base;
    }

    public void setNext(Edge n) {
        next = n;
    }

    /**
    * Initialize the data (vertex) for the edge's origin
    **/
    public void setOrig(Vertex o) {
        vertex = o;
    }

    /**
    * Initialize the data (vertex) for the edge's destination
    **/
    public void setDest(Vertex d) {
        symmetric().setOrig(d);
    }

    Edge oNext() {
        return next;
    }

    Edge oPrev() {
        return this.rotate().oNext().rotate();
    }

    Edge lNext() {
        return this.rotateInv().oNext().rotate();
    }

    Edge lPrev() {
        return this.oNext().symmetric();
    }

    Edge rNext() {
        return this.rotate().oNext().rotateInv();
    }

    Edge rPrev() {
        return this.symmetric().oNext();
    }

    Edge dNext() {
        return this.symmetric().oNext().symmetric();
    }

    Edge dPrev() {
        return this.rotateInv().oNext().rotateInv();
    }

    Vertex orig() {
        return vertex;
    }

    Vertex dest() {
        return symmetric().orig();
    }

    /**
    * Return the symmetric of the edge.  The symmetric is the same edge
    * with the opposite direction.
    * @return the symmetric of the edge
    **/
    Edge symmetric() {
        return quadList[(listPos + 2) % 4];
    }

    /**
    * Return the rotated version of the edge.  The rotated version is a
    * 90 degree counterclockwise turn.
    * @return the rotated version of the edge
    **/
    Edge rotate() {
        return quadList[(listPos + 1) % 4];
    }

    /**
    * Return the inverse rotated version of the edge.  The inverse
    * is a 90 degree clockwise turn.
    * @return the inverse rotated edge.
    **/
    Edge rotateInv() {
        return quadList[(listPos + 3) % 4];
    }

    Edge nextQuadEdge() {
        return quadList[(listPos + 1) % 4];
    }

    Edge connectLeft(Edge b) {
        Vertex t1,t2;
        Edge ans, lnexta;

        t1 = dest();
        lnexta = lNext();
        t2 = b.orig();
        ans = Edge.makeEdge(t1, t2);
        ans.splice(lnexta);
        ans.symmetric().splice(b);
        return ans;
    }

    Edge connectRight(Edge b) {
        Vertex t1, t2;
        Edge ans, oprevb, q1;

        t1 = dest();
        t2 = b.orig();
        oprevb = b.oPrev();

        ans = Edge.makeEdge(t1, t2);
        ans.splice(symmetric());
        ans.symmetric().splice(oprevb);
        return ans;
    }

    /****************************************************************/
    /*    Quad-edge manipulation primitives
    ****************************************************************/
    void swapedge() {
        Edge a = oPrev();
        Edge syme = symmetric();
        Edge b = syme.oPrev();
        splice(a);
        syme.splice(b);
        Edge lnexttmp = a.lNext();
        splice(lnexttmp);
        lnexttmp = b.lNext();
        syme.splice(lnexttmp);
        Vertex a1 = a.dest();
        Vertex b1 = b.dest();
        setOrig(a1);
        setDest(b1);
    }

    void splice(Edge b) {
        Edge alpha = oNext().rotate();
        Edge beta = b.oNext().rotate();
        Edge t1 = beta.oNext();
        Edge temp = alpha.oNext();
        alpha.setNext(t1);
        beta.setNext(temp);
        temp = oNext();
        t1 = b.oNext();
        b.setNext(temp);
        setNext(t1);
    }

    bool valid(Edge basel) {
        Vertex t1 = basel.orig();
        Vertex t3 = basel.dest();
        Vertex t2 = dest();
        return t1.ccw(t2, t3);
    }

    void deleteEdge() {
        Edge f = oPrev();
        splice(f);
        f = symmetric().oPrev();
        symmetric().splice(f);
    }

    static EdgePair doMerge(Edge ldo, Edge ldi, Edge rdi, Edge rdo) {
        while (true) {
            Vertex t3 = rdi.orig();
            Vertex t1 = ldi.orig();
            Vertex t2 = ldi.dest();

            while (t1.ccw(t2, t3)) {
                ldi = ldi.lNext();

                t1=ldi.orig();
                t2=ldi.dest();
            }

            t2 = rdi.dest();

            if (t2.ccw(t3, t1))
                rdi = rdi.rPrev();
            else
                break;
        }

        Edge basel = rdi.symmetric().connectLeft(ldi);

        Edge lcand = basel.rPrev();
        Edge rcand = basel.oPrev();
        Vertex t1 = basel.orig();
        Vertex t2 = basel.dest();

        if (t1 == rdo.orig())
            rdo = basel;
        if (t2 == ldo.orig())
            ldo = basel.symmetric();

        while (true) {
            Edge t = lcand.oNext();
            if (t.valid(basel)) {
                Vertex v4 = basel.orig();

                Vertex v1 = lcand.dest();
                Vertex v3 = lcand.orig();
                Vertex v2 = t.dest();
                while (v1.incircle(v2,v3,v4)){
                    lcand.deleteEdge();
                    lcand = t;

                    t = lcand.oNext();
                    v1 = lcand.dest();
                    v3 = lcand.orig();
                    v2 = t.dest();
                }
            }

            t = rcand.oPrev();
            if (t.valid(basel)) {
                Vertex v4 = basel.dest();
                Vertex v1 = t.dest();
                Vertex v2 = rcand.dest();
                Vertex v3 = rcand.orig();
                while (v1.incircle(v2, v3, v4)) {
                    rcand.deleteEdge();
                    rcand = t;
                    t = rcand.oPrev();
                    v2 = rcand.dest();
                    v3 = rcand.orig();
                    v1 = t.dest();
                }
            }

            bool lvalid = lcand.valid(basel);

            bool rvalid = rcand.valid(basel);
            if ((!lvalid) && (!rvalid))
                return new EdgePair(ldo, rdo);

            Vertex v1 = lcand.dest();
            Vertex v2 = lcand.orig();
            Vertex v3 = rcand.orig();
            Vertex v4 = rcand.dest();
            if (!lvalid || (rvalid && v1.incircle(v2, v3, v4))) {
                basel = rcand.connectLeft(basel.symmetric());
                rcand = basel.symmetric().lNext();
            } else {
                basel = lcand.connectRight(basel).symmetric();
                lcand = basel.rPrev();
            }
        }

        assert(0);
    }


    /**
    * Print the voronoi diagram and its dual, the delaunay triangle for the
    * diagram.
    **/
    void outputVoronoiDiagram() {
        Edge nex = this;
        //  Plot voronoi diagram edges with one endpoint at infinity.
        do {
            Vec2 v21 = nex.dest();
            Vec2 v22 = nex.orig();
            Edge tmp = nex.oNext();
            Vec2 v23 = tmp.dest();
            Vec2 cvxvec = v21.sub(v22);
            Vec2 center = v22.circle_center(v21, v23);


            Vec2 vv1 = v22.sum(v22);
            Vec2 vv2 = vv1.times(0.5);
            Vec2 vv3 = center.sub(vv2);
            double ln = 1.0 + vv3.magn();
            double d1 = ln / cvxvec.magn();
            vv1 = cvxvec.cross();
            vv2 = vv1.times(d1) ;
            vv3 = center.sum(vv2);
            printf("Vedge %s %s\n", center.toCString(), vv3.toCString());
            nex = nex.rNext();
        } while (nex != this);

        // plot delaunay triangle edges and finite VD edges.
        Stack!(Edge) edges = new Stack!(Edge);
        bool[Edge] seen;
        pushRing(edges, seen);
        printf("no. of edges = %d\n", edges.length);
        while (!edges.empty()) {
            Edge edge = edges.pop();
            if (edge in seen && seen[edge]) {
                Edge prev = edge;
                nex = edge.oNext();
                do {
                    Vertex v1 = prev.orig();
                    double d1 = v1.X();
                    Vertex v2 = prev.dest();
                    double d2 = v2.X();
                    if (d1 >= d2) {
                        printf("Dedge %s %s\n", v1.toCString(), v2.toCString());
                        Edge sprev = prev.symmetric();
                        Edge snex = sprev.oNext();
                        v1 = prev.orig();
                        v2 = prev.dest();
                        Vertex v3 = nex.dest();
                        Vertex v4 = snex.dest();
                        if (v1.ccw(v2, v3) != v1.ccw(v2, v4)) {
                            Vec2 v21 = prev.orig();
                            Vec2 v22 = prev.dest();
                            Vec2 v23 = nex.dest();
                            Vec2 vv1 = v21.circle_center(v22, v23);
                            v21 = sprev.orig();
                            v22 = sprev.dest();
                            v23 = snex.dest();
                            Vec2 vv2 = v21.circle_center(v22, v23);
                            printf("Vedge %s %s\n", vv1.toCString(), vv2.toCString());
                        }
                    }
                    seen[prev] = false;
                    prev = nex;
                    nex = nex.oNext();
                } while (prev != edge);
            }
            edge.symmetric().pushRing(edges, seen);
        }
    }

    void pushRing(Stack!(Edge) stack, ref bool[Edge] seen) {
        Edge nex = oNext();
        while (nex != this) {
            if (!(nex in seen)) {
                seen[nex] = true;
                stack.push(nex);
            }
            nex = nex.oNext();
        }
    }

    void pushNonezeroRing(Stack!(Edge) stack, ref bool[Edge] seen) {
        Edge nex = oNext();
        while (nex != this) {
            if (nex in seen) {
                seen.remove(nex);
                stack.push(nex);
            }
            nex = nex.oNext();
        }
    }
}  // Edge ends


/**
* A class that represents an edge pair
**/
final class EdgePair {
    Edge left;
    Edge right;

    this(Edge l, Edge r) {
        left = l;
        right = r;
    }

    public Edge getLeft() {
        return left;
    }

    public Edge getRight() {
        return right;
    }
} // EdgePair ends


struct Voronoi {
    /**
    * The number of points in the diagram
    **/
    private static int points = 0;

    /**
    * Set to true to print informative messages
    **/
    private static bool printMsgs = false;

    /**
    * Set to true to print the voronoi diagram and its dual,
    * the delaunay diagram
    **/
    private static bool printResults = false;

    /**
    * The main routine which creates the points and then performs
    * the delaunay triagulation.
    * @param args the command line parameters
    **/
    public static void main(char[][] args) {
        parseCmdLine(args);

        if (printMsgs)
            printf("Getting %d points\n", points);

        auto start0 = myclock();
        Vertex.seed = 1023;
        Vertex extra = Vertex.createPoints(1, new MyDouble(1.0), points);
        Vertex point = Vertex.createPoints(points-1, new MyDouble(extra.X()),
        points-1);
        auto end0 = myclock();

        if (printMsgs)
            printf("Doing voronoi on %d nodes\n", points);

        auto start1 = myclock();
        Edge edge = point.buildDelaunayTriangulation(extra);
        auto end1 = myclock();

        if (printResults)
            edge.outputVoronoiDiagram();

        if (printMsgs) {
            printf("Build time %f\n", end0 - start0);
            printf("Compute  time %f\n", end1 - start1);
            printf("Total time %f\n", end1 - start0);
            printf("Done!\n");
        }
    }

    /**
    * Parse the command line options.
    * @param args the command line options.
    **/
    private static final void parseCmdLine(char[][] args) {
        int i = 1;

        while (i < args.length && args[i][0] == '-') {
            char[] arg = args[i++];

            if (arg == "-n") {
                if (i < args.length)
                    points = toInt(args[i++]);
                else
                    throw new Exception("-n requires the number of points");
            } else if (arg == "-p") {
                printResults = true;
            } else if (arg == "-v") {
                printMsgs = true;
            } else if (arg == "-h") {
                usage();
            }
        }

        if (points == 0)
            usage();
    }

    /**
    * The usage routine which describes the program options.
    **/
    private static final void usage() {
        fprintf(stderr, "usage: voronoi_d -n <points> [-p] [-m] [-h]\n");
        fprintf(stderr, "    -n the number of points in the diagram\n");
        fprintf(stderr, "    -p (print detailed results/messages - the voronoi diagram>)\n");
        fprintf(stderr, "    -v (print informative message)\n");
        fprintf(stderr, "    -h (this message)\n");
        exit(0);
    }
} // Voronoi ends


void main(char[][] args) {
    Voronoi.main(args);
}
