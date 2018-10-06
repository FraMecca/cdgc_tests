/**
A D implementation of the _bh_ Olden benchmark.
The Olden benchmark implements the Barnes-Hut benchmark
that is decribed in:

J. Barnes and P. Hut, "A hierarchical o(N log N) force-calculation algorithm",
Nature, 324:446-449, Dec. 1986

The original code in the Olden benchmark suite is derived from the
ftp://hubble.ifa.hawaii.edu/pub/barnes/treecode
source distributed by Barnes.

Java code converted to D by leonardo maffi, V.1.0, Dec 25 2009.

Removed output unless an option is passed by Leandro Lucarella, 2010-08-04.
Downloaded from http://www.fantascienza.net/leonardo/js/
                http://www.fantascienza.net/leonardo/js/dolden_bh.zip
*/
import core.stdc.stdio: printf, sprintf, fprintf, stderr;
import core.stdc.stdlib: exit, malloc, free;
import core.stdc.time: CLOCKS_PER_SEC, clock;
import std.math: sqrt, floor, PI, pow;

import std.conv: to;
alias to!(int) toInt;


double myclock() {
    return clock() / cast(double)CLOCKS_PER_SEC;
}


/*
Basic uniform random generator: Minimal Standard in Park and
Miller (1988): "Random Number Generators: Good Ones Are Hard to
Find", Comm. of the ACM, 31, 1192-1201.
Parameters: m = 2^31-1, a=48271.

Adapted from Pascal code by Jesper Lund:
http://www.gnu-pascal.de/crystal/gpc/en/mail1390.html
*/
struct Random {
    const int m = int.max;
    const int a = 48_271;
    const int q = m / a;
    const int r = m % a;
    int seed;

    public double uniform(double min, double max) {
        int k = seed / q;
        seed = a * (seed - k * q) - r * k;
        if (seed < 1)
            seed += m;
        double r = cast(double)seed / m;
        return r * (max - min) + min;
    }
}


interface Enumeration {
    bool hasMoreElements();
    Object nextElement();
}


/**
A class representing a three dimensional vector that implements
several math operations.  To improve speed we implement the
vector as an array of doubles rather than use the exising
code in the java.util.Vec3 class.
*/
final class Vec3 {
    /// The number of dimensions in the vector
    // Can't be changed because of crossProduct()
    static immutable int NDIM = 3;

    /// An array containing the values in the vector.
    private double[] data;

    /// Construct an empty 3 dimensional vector for use in Barnes-Hut algorithm.
    this() {
        data.length = NDIM;
        data[] = 0.0;
    }

    /// Create a copy of the vector. Return a clone of the math vector
    public Vec3 clone() {
        Vec3 v = new Vec3;
        v.data.length = NDIM;
        v.data[] = this.data[];
        return v;
    }

    /**
    Return the value at the i'th index of the vector.
    @param i the vector index
    @return the value at the i'th index of the vector.
    */
    final double value(int i) {
        return data[i];
    }

    /**
    Set the value of the i'th index of the vector.
    @param i the vector index
    @param v the value to store
    */
    final void value(int i, double v) {
        data[i] = v;
    }

    /**
    Set one of the dimensions of the vector to 1.0
    param j the dimension to set.
    */
    final void unit(int j) {
        for (int i = 0; i < NDIM; i++)
            data[i] = (i == j) ? 1.0 : 0.0;
    }

    /**
    Add two vectors and the result is placed in this vector.
    @param u the other operand of the addition
    */
    final void addition(Vec3 u) {
        for (int i = 0; i < NDIM; i++)
            data[i] += u.data[i];
    }

    /**
   * Subtract two vectors and the result is placed in this vector.
   * This vector contain the first operand.
   * @param u the other operand of the subtraction.
   **/
    final void subtraction(Vec3 u) {
        for (int i = 0; i < NDIM; i++)
            data[i] -= u.data[i];
    }

    /**
    Subtract two vectors and the result is placed in this vector.
    @param u the first operand of the subtraction.
    @param v the second opernd of the subtraction
    */
    final void subtraction(Vec3 u, Vec3 v) {
        for (int i = 0; i < NDIM; i++)
            data[i] = u.data[i] - v.data[i];
    }

    /**
    Multiply the vector times a scalar.
    @param s the scalar value
    **/
    final void multScalar(double s) {
        for (int i = 0; i < NDIM; i++)
            data[i] *= s;
    }

    /**
    * Multiply the vector times a scalar and place the result in this vector.
    * @param u the vector
    * @param s the scalar value
    **/
    final void multScalar(Vec3 u, double s) {
        for (int i = 0; i < NDIM; i++)
            data[i] = u.data[i] * s;
    }

    /**
    * Divide each element of the vector by a scalar value.
    * @param s the scalar value.
    **/
    final void divScalar(double s) {
        for (int i = 0; i < NDIM; i++)
            data[i] /= s;
    }

    /**
    * Return the dot product of a vector.
    * @return the dot product of a vector.
    **/
    final double dotProduct() {
        double s = 0.0;
        for (int i = 0; i < NDIM; i++)
            s += data[i] * data[i];
        return s;
    }

    final double absolute() {
        double tmp = 0.0;
        for (int i = 0; i < NDIM; i++)
            tmp += data[i] * data[i];
        return sqrt(tmp);
    }

    final double distance(Vec3 v) {
        double tmp = 0.0;
        for (int i = 0; i < NDIM; i++)
            tmp += ((data[i] - v.data[i]) * (data[i] - v.data[i]));
        return sqrt(tmp);
    }

    final void crossProduct(Vec3 u, Vec3 w) {
        data[0] = u.data[1] * w.data[2] - u.data[2] * w.data[1];
        data[1] = u.data[2] * w.data[0] - u.data[0] * w.data[2];
        data[2] = u.data[0] * w.data[1] - u.data[1] * w.data[0];
    }

    final void incrementalAdd(Vec3 u) {
        for (int i = 0; i < NDIM; i++)
            data[i] += u.data[i];
    }

    final void incrementalSub(Vec3 u) {
        for (int i = 0; i < NDIM; i++)
            data[i] -= u.data[i];
    }

    final void incrementalMultScalar(double s) {
        for (int i = 0; i < NDIM; i++)
            data[i] *= s;
    }

    final void incrementalDivScalar(double s) {
        for (int i = 0; i < NDIM; i++)
            data[i] /= s;
    }

    final void addScalar(Vec3 u, double s) {
        for (int i = 0; i < NDIM; i++)
            data[i] = u.data[i] + s;
    }

    public char* toCString() {
        // this is not generic code at all
        char* result = cast(char*)malloc(100);
        if (result == null) exit(1);
        sprintf(result, "%.17f %.17f %.17f ", data[0], data[1], data[2]);
        return result;
    }
}


/// A class that represents the common fields of a cell or body data structure.
abstract class Node {
    // mass of the node
    double mass;

    // Position of the node
    Vec3 pos;

    // highest bit of int coord
    static immutable int IMAX = 1073741824;

    // potential softening parameter
    static immutable double EPS = 0.05;

    /// Construct an empty node
    protected this() {
        mass = 0.0;
        pos = new Vec3();
    }

    abstract Node loadTree(Body p, Vec3 xpic, int l, Tree root);

    abstract double hackcofm();

    abstract HG walkSubTree(double dsq, HG hg);

    static final int oldSubindex(Vec3 ic, int l) {
        int i = 0;
        for (int k = 0; k < Vec3.NDIM; k++)
            if ((cast(int)ic.value(k) & l) != 0)
                i += Cell.NSUB >> (k + 1);
        return i;
    }

    public char* toCString() {
        char* result = cast(char*)malloc(130);
        if (result == null) exit(1);
        char* pos_str = pos.toCString();
        sprintf(result, "%f : %s", mass, pos_str);
        free(pos_str);
        return result;
    }

    /// Compute a single body-body or body-cell interaction
    final HG gravSub(HG hg) {
        Vec3 dr = new Vec3();
        dr.subtraction(pos, hg.pos0);

        double drsq = dr.dotProduct() + (EPS * EPS);
        double drabs = sqrt(drsq);

        double phii = mass / drabs;
        hg.phi0 -= phii;
        double mor3 = phii / drsq;
        dr.multScalar(mor3);
        hg.acc0.addition(dr);
        return hg;
    }

    /**
    * A sub class which is used to compute and save information during the
    * gravity computation phase.
    **/
    static protected final class HG {
        /// Body to skip in force evaluation
        Body pskip;

        /// Point at which to evaluate field
        Vec3 pos0;

        /// Computed potential at pos0

        double phi0;

        /// computed acceleration at pos0
        Vec3 acc0;

        /**
        * Create a HG  object.
        * @param b the body object
        * @param p a vector that represents the body
        **/
        this(Body b, Vec3 p) {
            pskip = b;
            pos0 = p.clone();
            phi0 = 0.0;
            acc0 = new Vec3();
        }
    }
}


/// A class used to representing particles in the N-body simulation.
final class Body : Node {
    Vec3 vel, acc, newAcc;
    double phi = 0.0;
    private Body next, procNext;

    /// Create an empty body.
    this() {
        vel = new Vec3();
        acc = new Vec3();
        newAcc = new Vec3();
    }

    /**
    * Set the next body in the list.
    * @param n the body
    **/
    final void setNext(Body n) {
        next = n;
    }

    /**
    * Get the next body in the list.
    * @return the next body
    **/
    final Body getNext() {
        return next;
    }

    /**
    * Set the next body in the list.
    * @param n the body
    **/
    final void setProcNext(Body n) {
        procNext = n;
    }

    /**
    * Get the next body in the list.
    * @return the next body
    **/
    final Body getProcNext() {
        return procNext;
    }

    /**
    * Enlarge cubical "box", salvaging existing tree structure.
    * @param tree the root of the tree.
    * @param nsteps the current time step
    **/
    final void expandBox(Tree tree, int nsteps) {
        Vec3 rmid = new Vec3();

        bool inbox = icTest(tree);
        while (!inbox) {
            double rsize = tree.rsize;
            rmid.addScalar(tree.rmin, 0.5 * rsize);

            for (int k = 0; k < Vec3.NDIM; k++)
                if (pos.value(k) < rmid.value(k)) {
                    double rmin = tree.rmin.value(k);
                    tree.rmin.value(k, rmin - rsize);
                }

            tree.rsize = 2.0 * rsize;
            if (tree.root !is null) {
                Vec3 ic = tree.intcoord(rmid);
                if (ic is null)
                    throw new Exception("Value is out of bounds");
                int k = oldSubindex(ic, IMAX >> 1);
                Cell newt = new Cell();
                newt.subp[k] = tree.root;
                tree.root = newt;
                inbox = icTest(tree);
            }
        }
    }

    /**
    * Check the bounds of the body and return true if it isn't in the
    * correct bounds.
    **/
    final bool icTest(Tree tree) {
        double pos0 = pos.value(0);
        double pos1 = pos.value(1);
        double pos2 = pos.value(2);

        // by default, it is in bounds
        bool result = true;

        double xsc = (pos0 - tree.rmin.value(0)) / tree.rsize;
        if (!(0.0 < xsc && xsc < 1.0))
            result = false;

        xsc = (pos1 - tree.rmin.value(1)) / tree.rsize;
        if (!(0.0 < xsc && xsc < 1.0))
            result = false;

        xsc = (pos2 - tree.rmin.value(2)) / tree.rsize;
        if (!(0.0 < xsc && xsc < 1.0))
            result = false;

        return result;
    }

    /**
    * Descend Tree and insert particle.  We're at a body so we need to
    * create a cell and attach this body to the cell.
    * @param p the body to insert
    * @param xpic
    * @param l
    * @param tree the root of the data structure
    * @return the subtree with the new body inserted
    **/
    override Node loadTree(Body p, Vec3 xpic, int l, Tree tree) {
        // create a Cell
        Cell retval = new Cell();
        int si = subindex(tree, l);
        // attach this Body node to the cell
        retval.subp[si] = this;

        // move down one level
        si = oldSubindex(xpic, l);
        Node rt = retval.subp[si];
        if (rt !is null)
            retval.subp[si] = rt.loadTree(p, xpic, l >> 1, tree);
        else
            retval.subp[si] = p;
        return retval;
    }

    /**
    * Descend tree finding center of mass coordinates
    * @return the mass of this node
    **/
    override double hackcofm() {
        return mass;
    }

    /// iteration of the bodies
    int opApply(int delegate(ref Body) dg) {
        int result;
        Body current = this;
        while (current !is null) {
            result = dg(current);
            current = current.next;
            if (result)
                break;
        }
        return result;
    }

    /// inverse iteration of the bodies
    int opApplyReverse(int delegate(ref Body) dg) {
        int result;
        Body current = this;
        while (current !is null) {
            result = dg(current);
            current = current.procNext;
            if (result)
                break;
        }
        return result;
    }


    /**
    * Return an enumeration of the bodies
    * @return an enumeration of the bodies
    **/
    final Enumeration elements() {
        // a local class that implements the enumerator
        static final class Enumerate : Enumeration {
            private Body current;
            public this(Body outer) {
                //this.current = Body.this;
                this.current = outer;
            }
            public bool hasMoreElements() {
                return current !is null;
            }
            public Object nextElement() {
                Object retval = current;
                current = current.next;
                return retval;
            }
        }

        return new Enumerate(this);
    }

    final Enumeration elementsRev() {
        // a local class that implements the enumerator
        static class Enumerate : Enumeration {
            private Body current;
            public this(Body outer) {
                //this.current = Body.this;
                this.current = outer;
            }
            public bool hasMoreElements() {
                return current !is null;
            }
            public Object nextElement() {
                Object retval = current;
                current = current.procNext;
                return retval;
            }
        }

        return new Enumerate(this);
    }

    /**
    * Determine which subcell to select.
    * Combination of intcoord and oldSubindex.
    * @param t the root of the tree
    **/
    final int subindex(Tree tree, int l) {
        Vec3 xp = new Vec3();

        double xsc = (pos.value(0) - tree.rmin.value(0)) / tree.rsize;
        xp.value(0, floor(IMAX * xsc));

        xsc = (pos.value(1) - tree.rmin.value(1)) / tree.rsize;
        xp.value(1, floor(IMAX * xsc));

        xsc = (pos.value(2) - tree.rmin.value(2)) / tree.rsize;
        xp.value(2, floor(IMAX * xsc));

        int i = 0;
        for (int k = 0; k < Vec3.NDIM; k++)
            if ((cast(int)xp.value(k) & l) != 0)
                i += Cell.NSUB >> (k + 1);
        return i;
    }

    /**
    * Evaluate gravitational field on the body.
    * The original olden version calls a routine named "walkscan",
    * but we use the same name that is in the Barnes code.
    **/
    final void hackGravity(double rsize, Node root) {
        Vec3 pos0 = pos.clone();
        HG hg = new HG(this, pos);
        hg = root.walkSubTree(rsize * rsize, hg);
        phi = hg.phi0;
        newAcc = hg.acc0;
    }

    /// Recursively walk the tree to do hackwalk calculation
    override HG walkSubTree(double dsq, HG hg) {
        if (this != hg.pskip)
            hg = gravSub(hg);
        return hg;
    }

    /**
    * Return a string represenation of a body.
    * @return a string represenation of a body.
    **/
    override char* toCString() {
        char* result = cast(char*)malloc(140);
        if (result == null) exit(1);
        char* super_str = super.toCString();
        sprintf(result, "Body %s", super_str);
        free(super_str);
        return result;
    }
}



/// A class used to represent internal nodes in the tree
final class Cell : Node {
    // subcells per cell
    static immutable int NSUB = 1 << Vec3.NDIM;

    /**
    * The children of this cell node.  Each entry may contain either
    * another cell or a body.
    **/
    Node[] subp;
    Cell next;

    this() {
        subp.length = NSUB;
    }

    /**
    * Descend Tree and insert particle.  We're at a cell so
    * we need to move down the tree.
    * @param p the body to insert into the tree
    * @param xpic
    * @param l
    * @param tree the root of the tree
    * @return the subtree with the new body inserted
    **/
    override Node loadTree(Body p, Vec3 xpic, int l, Tree tree) {
        // move down one level
        int si = oldSubindex(xpic, l);
        Node rt = subp[si];
        if (rt !is null)
            subp[si] = rt.loadTree(p, xpic, l >> 1, tree);
        else
            subp[si] = p;
        return this;
    }

    /**
    * Descend tree finding center of mass coordinates
    * @return the mass of this node
    **/
    override double hackcofm() {
        double mq = 0.0;
        Vec3 tmpPos = new Vec3();
        Vec3 tmpv = new Vec3();
        for (int i = 0; i < NSUB; i++) {
            Node r = subp[i];
            if (r !is null) {
                double mr = r.hackcofm();
                mq = mr + mq;
                tmpv.multScalar(r.pos, mr);
                tmpPos.addition(tmpv);
            }
        }
        mass = mq;
        pos = tmpPos;
        pos.divScalar(mass);

        return mq;
    }

    /// Recursively walk the tree to do hackwalk calculation
    override HG walkSubTree(double dsq, HG hg) {
        if (subdivp(dsq, hg)) {
            for (int k = 0; k < Cell.NSUB; k++) {
                Node r = subp[k];
                if (r !is null)
                    hg = r.walkSubTree(dsq / 4.0, hg);
            }
        } else {
            hg = gravSub(hg);
        }
        return hg;
    }

    /**
    * Decide if the cell is too close to accept as a single term.
    * @return true if the cell is too close.
    **/
    bool subdivp(double dsq, HG hg) {
        Vec3 dr = new Vec3();
        dr.subtraction(pos, hg.pos0);
        double drsq = dr.dotProduct();

        // in the original olden version drsp is multiplied by 1.0
        return drsq < dsq;
    }

    /**
    * Return a string represenation of a cell.
    * @return a string represenation of a cell.
    **/
    override public char* toCString() {
        char* result = cast(char*)malloc(140);
        if (result == null) exit(1);
        char* super_str = super.toCString();
        sprintf(result, "Cell %s", super_str);
        free(super_str);
        return result;
    }
}


/**
* A class that represents the root of the data structure used
* to represent the N-bodies in the Barnes-Hut algorithm.
**/
final class Tree {
    Vec3 rmin;
    double rsize;

    /// A reference to the root node.
    Node root;

    /// The complete list of bodies that have been created.
    private Body bodyTab;

    /// The complete list of bodies that have been created - in reverse.
    private Body bodyTabRev;

    /// Construct the root of the data structure that represents the N-bodies.
    this() {
        rmin = new Vec3();
        rsize = -2.0 * -2.0;
        root = null;
        bodyTab = null;
        bodyTabRev = null;
        rmin.value(0, -2.0);
        rmin.value(1, -2.0);
        rmin.value(2, -2.0);
    }

    /**
    * Return an enumeration of the bodies.
    * @return an enumeration of the bodies.
    **/
    final Enumeration bodies() {
        return bodyTab.elements();
    }

    /**
    * Return an enumeration of the bodies - in reverse.
    * @return an enumeration of the bodies - in reverse.
    **/
    final Enumeration bodiesRev() {
        return bodyTabRev.elementsRev();
    }

    /**
    * Create the testdata used in the benchmark.
    * @param nbody the number of bodies to create
    **/
    final void createTestData(int nbody) {
        Vec3 cmr = new Vec3();
        Vec3 cmv = new Vec3();
        Body head = new Body();
        Body prev = head;

        double rsc = 3.0 * PI / 16.0;
        double vsc = sqrt(1.0 / rsc);
        int seed = 123;
        Random rnd = Random(seed);

        for (int i = 0; i < nbody; i++) {
            Body p = new Body();

            prev.setNext(p);
            prev = p;
            p.mass = 1.0 / cast(double)nbody;

            double t1 = rnd.uniform(0.0, 0.999);
            t1 = pow(t1, (-2.0 / 3.0)) - 1.0;
            double r = 1.0 / sqrt(t1);

            double coeff = 4.0;
            for (int k = 0; k < Vec3.NDIM; k++) {
                r = rnd.uniform(0.0, 0.999);
                p.pos.value(k, coeff * r);
            }

            cmr.addition(p.pos);

            double x, y;
            do {
                x = rnd.uniform(0.0, 1.0);
                y = rnd.uniform(0.0, 0.1);
            } while (y > (x * x * pow(1.0 - x * x, 3.5)));

            double v = sqrt(2.0) * x / pow(1 + r * r, 0.25);

            double rad = vsc * v;
            double rsq;
            do {
                for (int k = 0; k < Vec3.NDIM; k++)
                    p.vel.value(k, rnd.uniform(-1.0, 1.0));
                rsq = p.vel.dotProduct();
            } while (rsq > 1.0);
            double rsc1 = rad / sqrt(rsq);
            p.vel.multScalar(rsc1);
            cmv.addition(p.vel);
        }

        // mark end of list
        prev.setNext(null);

        // toss the dummy node at the beginning and set a reference to the first element
        bodyTab = head.getNext();

        cmr.divScalar(cast(double)nbody);
        cmv.divScalar(cast(double)nbody);

        prev = null;

        for (Enumeration e = bodyTab.elements(); e.hasMoreElements();) {
            Body b = cast(Body)e.nextElement();
            b.pos.subtraction(cmr);
            b.vel.subtraction(cmv);
            b.setProcNext(prev);
            prev = b;
        }

        // set the reference to the last element
        bodyTabRev = prev;
    }


    /**
    * Advance the N-body system one time-step.
    * @param nstep the current time step
    **/
    void stepSystem(int nstep) {
        // free the tree
        root = null;

        makeTree(nstep);

        // compute the gravity for all the particles
        for (Enumeration e = bodyTabRev.elementsRev(); e.hasMoreElements();) {
            Body b = cast(Body)e.nextElement();
            b.hackGravity(rsize, root);
        }
        vp(bodyTabRev, nstep);
    }

    /**
    * Initialize the tree structure for hack force calculation.
    * @param nsteps the current time step
    **/
    private void makeTree(int nstep) {
        for (Enumeration e = bodiesRev(); e.hasMoreElements();) {
            Body q = cast(Body)e.nextElement();
            if (q.mass != 0.0) {
                q.expandBox(this, nstep);
                Vec3 xqic = intcoord(q.pos);
                if (root is null) {
                    root = q;
                } else {
                    root = root.loadTree(q, xqic, Node.IMAX >> 1, this);
                }
            }
        }
        root.hackcofm();
    }

    /**
    * Compute integerized coordinates.
    * @return the coordinates or null if rp is out of bounds
    **/
    final Vec3 intcoord(Vec3 vp) {
        Vec3 xp = new Vec3();

        double xsc = (vp.value(0) - rmin.value(0)) / rsize;
        if (0.0 <= xsc && xsc < 1.0)
            xp.value(0, floor(Node.IMAX * xsc));
        else
            return null;

        xsc = (vp.value(1) - rmin.value(1)) / rsize;
        if (0.0 <= xsc && xsc < 1.0)
            xp.value(1, floor(Node.IMAX * xsc));
        else
            return null;

        xsc = (vp.value(2) - rmin.value(2)) / rsize;
        if (0.0 <= xsc && xsc < 1.0)
            xp.value(2, floor(Node.IMAX * xsc));
        else
            return null;

        return xp;
    }

    static final private void vp(Body p, int nstep) {
        Vec3 dacc = new Vec3();
        Vec3 dvel = new Vec3();
        double dthf = 0.5 * BH.DTIME;

        for (Enumeration e = p.elementsRev(); e.hasMoreElements();) {
            Body b = cast(Body)e.nextElement();
            Vec3 acc1 = b.newAcc.clone();
            if (nstep > 0) {
                dacc.subtraction(acc1, b.acc);
                dvel.multScalar(dacc, dthf);
                dvel.addition(b.vel);
                b.vel = dvel.clone();
            }

            b.acc = acc1.clone();
            dvel.multScalar(b.acc, dthf);

            Vec3 vel1 = b.vel.clone();
            vel1.addition(dvel);
            Vec3 dpos = vel1.clone();
            dpos.multScalar(BH.DTIME);
            dpos.addition(b.pos);
            b.pos = dpos.clone();
            vel1.addition(dvel);
            b.vel = vel1.clone();
        }
    }
}


final class BH {
    /// The user specified number of bodies to create.
    private static int nbody = 0;

    /// The maximum number of time steps to take in the simulation
    private static int nsteps = 10;

    /// Should we print information messsages
    private static bool printMsgs = false;

    /// Should we print detailed results
    private static bool printResults = false;

    static immutable double DTIME = 0.0125;
    static immutable double TSTOP = 2.0;

    public static final void main(char[][] args) {
        parseCmdLine(args);

        if (printMsgs)
            printf("nbody = %d\n", nbody);

        auto start0 = myclock();
        Tree root = new Tree();
        root.createTestData(nbody);
        auto end0 = myclock();
        if (printMsgs)
              printf("Bodies created\n");

        auto start1 = myclock();
        double tnow = 0.0;
        int i = 0;
        while ((tnow < TSTOP + 0.1 * DTIME) && (i < nsteps)) {
            root.stepSystem(i++);
            tnow += DTIME;
        }
        auto end1 = myclock();

        if (printResults) {
            int j = 0;
            for (Enumeration e = root.bodies(); e.hasMoreElements();) {
                Body b = cast(Body)e.nextElement();
                char* str_ptr = b.pos.toCString();
                printf("body %d: %s\n", j++, str_ptr);
                free(str_ptr);
            }
        }

        if (printMsgs) {
            printf("Build time %.2f\n", end0 - start0);
            printf("Compute Time %.2f\n", end1 - start1);
            printf("Total Time %.2f\n", end1 - start0);
            printf("Done!\n");
        }
    }

    private static final void parseCmdLine(char[][] args) {
        int i = 1;
        while (i < args.length && args[i][0] == '-') {
            char[] arg = args[i++];

            // check for options that require arguments
            if (arg == "-b") {
                if (i < args.length)
                    nbody = toInt(args[i++]);
                else
                    throw new Exception("-l requires the number of levels");
            } else if (arg == "-s") {
                if (i < args.length)
                    nsteps = toInt(args[i++]);
                else
                    throw new Exception("-l requires the number of levels");
            } else if (arg == "-m") {
                printMsgs = true;
            } else if (arg == "-p") {
                printResults = true;
            } else if (arg == "-h") {
                usage();
            }
        }

        if (nbody == 0)
            usage();
    }

    /// The usage routine which describes the program options.
    private static final void usage() {
        fprintf(stderr, "usage: BH -b <size> [-s <steps>] [-p] [-m] [-h]\n");
        fprintf(stderr, "  -b the number of bodies\n");
        fprintf(stderr, "  -s the max. number of time steps (default=10)\n");
        fprintf(stderr, "  -p (print detailed results)\n");
        fprintf(stderr, "  -m (print information messages\n");
        exit(0);
    }
}


void main(char[][] args) {
    BH.main(args);
}
