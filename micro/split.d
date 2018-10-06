// Written by bearophile <bearophileHUGS@lycos.com>
// Fount at http://www.digitalmars.com/webnews/newsgroups.php?art_group=digitalmars.D&article_id=67673
// Sightly modified by Leandro Lucarella <llucax@gmail.com>
// (removed timings)

import std.file : readText;
import std.range;
import std.algorithm;
import std.conv: to;

// https://github.com/SiegeLord/Tango-D2/blob/d2port/tango/text/Util.d

T[][] delimit(T, M) (T[] src, const(M)[] set)
{
    T[][] result;

    foreach (segment; delimiters (src, set))
        result ~= segment;
    return result;
}
DelimFruct!(T, M) delimiters(T, M) (T[] src, const(M)[] set)
{
    DelimFruct!(T, M) elements;
    elements.set = set;
    elements.src = src;
    return elements;
}

private struct DelimFruct(T, M)
{
    private T[] src;
    private const(M)[] set;

    int opApply (scope int delegate (ref T[] token) dg)
    {
        int     ret;
        size_t  pos,
            mark;
        T[]     token;

        // optimize for single delimiter case
        if (set.length is 1)
            while ((pos = countUntil (src, set[0])) < src.length)
                {
                    token = src [mark .. pos];
                    if ((ret = dg (token)) != 0)
                        return ret;
                    mark = pos + 1;
                }
        else
            if (set.length > 1)
                foreach (i, elem; src)
                    if (canFind (set, elem))
                        {
                            token = src [mark .. i];
                            if ((ret = dg (token)) != 0)
                                return ret;
                            mark = i + 1;
                        }

        token = src [mark .. $];
        if (mark <= src.length)
            ret = dg (token);

        return ret;
    }
}

int main(char[][] args) {
	if (args.length < 2)
		return 1;
	auto txt = cast(byte[]) readText(args[1]);
	auto n = (args.length > 2) ? to!(uint)(args[2]) : 1;
	if (n < 1)
		n = 1;
	while (--n)
		txt ~= txt;
	auto words = delimit!(byte)(txt, cast(byte[]) " \t\n\r");
	return !words.length;
}

