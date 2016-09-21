module tt.logger;

import
		std.stdio,
		std.range,
		std.string,

		consoled;


struct Logger
{
	void info(A...)(auto ref A args)
	{
		log(Color.lightGreen, args);
	}

	void info2(A...)(auto ref A args)
	{
		log(Color.lightMagenta, args);
	}

	void info3(A...)(auto ref A args)
	{
		log(Color.white, args);
	}

	void error(A...)(auto ref A args)
	{
		log(Color.lightRed, args);
	}

	void warning(A...)(auto ref A args)
	{
		log(Color.lightYellow, args);
	}

	void opCall(A...)(auto ref A args)
	{
		log(Color.lightCyan, args);
	}

	ubyte ident;
private:
	void log(A...)(Color c, auto ref A args)
	{
		static if(args.length == 1)
		{
			foreground = c;

			"\t".repeat(ident).join.write;
			args[0].writeln;

			resetColors;
		}
		else
		{
			log(c, format(args));
		}
	}
}

__gshared Logger log;
