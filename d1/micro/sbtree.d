// Written by Andrey Khropov <andkhropov_nosp@m_mtu-net.ru>
// Found at http://www.digitalmars.com/webnews/newsgroups.php?art_group=digitalmars.D&article_id=43991
// Modified by Leandro Lucarella
// (ported to Tango, fixed some stylistic issues)

import std.conv;

alias char[] string;

int main(string[] args)
{
   int N = args.length > 1 ? to!(int)(args[1]) : 1;

   int minDepth = 4;
   int maxDepth = (minDepth + 2) > N ? minDepth + 2 : N;
   int stretchDepth = maxDepth + 1;

   int check = TreeNode.BottomUpTree(0, stretchDepth).ItemCheck;
   TreeNode longLivedTree = TreeNode.BottomUpTree(0, maxDepth);

   for (int depth = minDepth; depth <= maxDepth; depth += 2) {
      int iterations = 1 << (maxDepth - depth + minDepth);
      check = 0;

      for (int i = 1; i <= iterations; i++) {
         check += TreeNode.BottomUpTree(i, depth).ItemCheck;
         check += TreeNode.BottomUpTree(-i, depth).ItemCheck;
      }

   }

   return 0;
}

class TreeNode
{
   TreeNode left, right;
   int item;

   this(int item, TreeNode left = null, TreeNode right = null)
   {
      this.item = item;
      this.left = left;
      this.right = right;
   }

   static TreeNode BottomUpTree(int item, int depth)
   {
      if (depth > 0)
         return new TreeNode(item,
               BottomUpTree(2 * item - 1, depth - 1),
               BottomUpTree(2 * item, depth - 1));
      return new TreeNode(item);
   }

   int ItemCheck()
   {
      if (left)
         return item + left.ItemCheck() - right.ItemCheck();
      return item;
   }
}

