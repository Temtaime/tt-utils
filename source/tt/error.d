module tt.error;

import
		std.string,
		std.format;

bool throwError(string file = __FILE__, uint line = __LINE__, A...)(string fmt, auto ref A args)
{
	static if(args.length)
	{
		fmt = format(fmt, args);
	}

	throw new Exception(fmt, file, line);
}

/*bool throwErrorImpl(A...)(string f, uint l, A args)
{
	static if(args.length == 1)
	{
		throw new Exception(format(`[%s, %u]: %s`, f, l, args));
	}
	else
	{
		return throwErrorImpl(f, l, format(args));
	}
}*/

//bool throwError(string f = __FILE__, uint l = __LINE__, A...)(A args) { return throwErrorImpl(f, l, args); }
