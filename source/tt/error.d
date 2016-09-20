module tt.error;

import
		std.string,
		std.format;


auto throwError(string F = __FILE__, uint L = __LINE__, A...)(auto ref A args)
{
	return throwErrorImpl(F, L, args);
}

bool throwErrorImpl(A...)(string f, uint l, string fmt, auto ref A args)
{
	static if(args.length)
	{
		fmt = format(fmt, args);
	}

	throw new Exception(fmt, f, l);
}
