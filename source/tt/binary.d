module tt.binary;

import
		std.file,
		std.conv,
		std.stdio,
		std.range,
		std.mmfile,
		std.string,
		std.traits,
		std.algorithm,
		std.typetuple,
		std.exception,

		tt.misc,
		tt.error;


struct BinaryReader(Reader)
{
	this(A...)(auto ref A args)
	{
		reader = Reader(args);
	}

	auto read(T)(string f = __FILE__, uint l = __LINE__) if(is(T == struct))
	{
		_l = l;
		_f = f;
		_info = T.stringof;

		T t;
		process(t, t, t);
		return t;
	}

	ref write(T)(auto ref in T t, string f = __FILE__, uint l = __LINE__) if(is(T == struct))
	{
		_l = l;
		_f = f;
		_info = T.stringof;

		process!true(t, t, t);
		return this;
	}

	Reader reader;
private:
	debug
	{
		enum errorRead = `throwErrorImpl(_f, _l, "can't read %s.%s variable", _info, name)`;
		enum errorWrite = `throwErrorImpl(_f, _l, "can't write %s.%s variable", _info, name)`;
		enum errorRSkip = `throwErrorImpl(_f, _l, "can't skip when reading %s.%s variable", _info, name)`;
		enum errorWSkip = `throwErrorImpl(_f, _l, "can't skip when writing %s.%s variable", _info, name)`;
		enum errorCheck = `throwErrorImpl(_f, _l, "variable %s.%s mismatch(%s when %s expected)", _info, name, tmp, *p)`;
		enum errorValid = `throwErrorImpl(_f, _l, "variable %s.%s has invalid value %s", _info, name, *p)`;
	}
	else
	{
		enum errorRead = `throwErrorImpl(_f, _l, "can't read %s", _info)`;
		enum errorWrite = `throwErrorImpl(_f, _l, "can't write %s", _info)`;
		enum errorRSkip = errorRead;
		enum errorWSkip = errorWrite;
		enum errorCheck = errorRead;
		enum errorValid = errorRead;
	}

	void process(bool isWrite = false, T, S, P)(ref T data, ref S st, ref P parent)
	{
		foreach(name; FieldsToProcess!T)
		{
			enum Elem = T.stringof ~ `.` ~ name;
			alias attrs = TypeTuple!(__traits(getAttributes, __traits(getMember, T, name)));

			debug
			{
				//static assert(allSatisfy!(isSomeString, attrs.Types), Elem ~ ` has not a string attribute`);

				enum att = checkAttrs(attrs);
				static assert(!att.length, Elem ~ ` has invalid attribute ` ~ att);
			}

			auto p = &__traits(getMember, data, name);
			alias R = typeof(*p);

			{
				enum idx = staticIndexOf!(`skip`, attrs);

				static if(idx >= 0)
				{
					size_t cnt = StructExecuter!(attrs[idx + 1])(data, st, parent, reader);

					static if(isWrite)
					{
						reader.wskip(cnt) || mixin(errorWSkip);
					}
					else
					{
						reader.rskip(cnt) || mixin(errorRSkip);
					}
				}
			}

			{
				enum idx = staticIndexOf!(`ignoreif`, attrs);

				static if(idx >= 0)
				{
					auto v = StructExecuter!(attrs[idx + 1])(data, st, parent, reader);

					if(v)
					{
						static if(!isWrite)
						{
							enum def = staticIndexOf!(`default`, attrs);

							static if(def >= 0)
							{
								*p = StructExecuter!(attrs[def + 1])(data, st, parent, reader);
							}
						}

						continue;
					}
				}
			}

			static if(!isWrite)
			{
				static if(is(R == immutable))
				{
					Unqual!R tmp;
					auto varPtr = &tmp;
				}
				else
				{
					alias varPtr = p;
				}
			}

			static if(isDataSimple!R)
			{
				static if(isWrite)
				{
					reader.write(toByte(*p)) || mixin(errorWrite);
				}
				else
				{
					reader.read(toByte(*varPtr)) || mixin(errorRead);
				}
			}
			else static if(isArray!R)
			{
				alias E = ElementEncodingType!R;

				enum isElemSimple = isDataSimple!E;
				enum lenIdx = staticIndexOf!(`length`, attrs);

				static assert(isElemSimple || is(E == struct), `can't serialize ` ~ Elem);

				static if(lenIdx >= 0)
				{
					uint elemsCnt = StructExecuter!(attrs[lenIdx + 1])(data, st, parent, reader);

					static if(isWrite)
					{
						assert(p.length == elemsCnt);
					}

					enum isRest = false;
				}
				else
				{
					static if(staticIndexOf!(`ubyte`, attrs) >= 0)			alias L = ubyte;
					else static if(staticIndexOf!(`ushort`, attrs) >= 0)	alias L = ushort;
					else static if(staticIndexOf!(`uint`, attrs) >= 0)		alias L = uint;
					else static if(staticIndexOf!(`ulong`, attrs) >= 0)		alias L = ulong;

					static if(is(L))
					{
						L elemsCnt;

						static if(isWrite)
						{
							assert(p.length <= L.max);

							elemsCnt = cast(L)p.length;
							reader.write(elemsCnt.toByte) || mixin(errorWrite);
						}
						else
						{
							reader.read(elemsCnt.toByte) || mixin(errorRead);
						}

						enum isRest = false;
					}
					else
					{
						enum isRest = staticIndexOf!(`rest`, attrs) >= 0;
					}
				}

				enum isStr = is(R : string);
				enum isLen = is(typeof(elemsCnt));
				enum isDyn = isDynamicArray!R;

				static if(isDyn)
				{
					static assert(isStr || isLen || isRest, `length of ` ~ Elem ~ ` is unknown`);
				}
				else
				{
					static assert(!(isLen || isRest), `static array ` ~ Elem ~ ` can't have a length`);
				}

				static if(isElemSimple)
				{
					static if(isWrite)
					{
						reader.write(toByte(*p)) || mixin(errorWrite);

						static if(isStr && !isLen)
						{
							reader.wskip(1) || mixin(errorWSkip);
						}
					}
					else
					{
						static if(isStr && !isLen)
						{
							reader.readstr(*varPtr) || mixin(errorRead);
						}
						else
						{
							ubyte[] arr;

							static if(isRest)
							{
								!(reader.length % E.sizeof) && reader.read(arr, cast(uint)reader.length) || mixin(errorRead);
							}
							else
							{
								reader.read(arr, elemsCnt * cast(uint)E.sizeof) || mixin(errorRead);
							}

							*varPtr = (cast(E *)arr.ptr)[0..arr.length / E.sizeof];
						}
					}
				}
				else
				{
					debug
					{
						auto old = _info;
						_info ~= `.` ~ name;
					}

					static if(isWrite)
					{
						foreach(ref v; *p)
						{
							process!isWrite(v, st, data);
						}
					}
					else
					{
						static if(isRest)
						{
							while(reader.length)
							{
								E v;
								process!isWrite(v, st, data);

								*varPtr ~= v;
							}
						}
						else
						{
							static if(isDyn)
							{
								*varPtr = new E[elemsCnt];
							}

							foreach(ref v; *varPtr)
							{
								process!isWrite(v, st, data);
							}
						}
					}

					debug
					{
						_info = old;
					}
				}
			}
			else
			{
				debug
				{
					auto old = _info;
					_info ~= `.` ~ name;
				}

				process!isWrite(*p, st, data);

				debug
				{
					_info = old;
				}
			}

			static if(!isWrite)
			{
				static if(is(typeof(tmp)))
				{
					tmp == *p || mixin(errorCheck);
				}

				enum idx = staticIndexOf!(`validif`, attrs);

				static if(idx >= 0)
				{
					StructExecuter!(attrs[idx + 1])(data, st, parent, reader) || mixin(errorValid);
				}
			}
		}
	}

	uint _l;
	string _info, _f;
}

// ----------------------------------------- READERS -----------------------------------------

struct MemoryReader(bool UseDup = false)
{
	this(in void[] data)
	{
		_p = cast(ubyte *)data.ptr;
		_end = _p + data.length;
	}

	bool read(ubyte[] v)
	{
		if(length < v.length) return false;

		v[] = _p[0..v.length];
		_p += v.length;

		return true;
	}

	bool read(ref ubyte[] v, uint len)
	{
		if(length < len) return false;

		v = _p[0..len];
		_p += len;

		static if(UseDup)
		{
			v = v.dup;
		}

		return true;
	}

	bool readstr(ref string v)
	{
		auto t = _p;
		auto r = length;

		while(r && *t) r--, t++;

		if(!r)
		{
			return false;
		}

		v = cast(string)_p[0..t - _p];
		_p = t + 1;

		static if(UseDup)
		{
			v = v.dup;
		}

		return true;
	}

	bool write(in ubyte[] v)
	{
		if(length < v.length) return false;

		_p[0..v.length] = v;
		_p += v.length;

		return true;
	}

	bool rskip(size_t cnt)
	{
		if(length < cnt) return false;

		_p += cnt;
		return true;
	}

	bool wskip(size_t cnt)
	{
		if(length < cnt) return false;

		//_p[0..cnt] = 0; // SKIP WHEN WRITING TO BUFFER DOESN'T WRITE ZEROS
		_p += cnt;

		return true;
	}

	const data() { return _p[0..length]; }
	const length() { return cast(size_t)(_end - _p); }
private:
	ubyte *	_p,
			_end;
}

struct AppendWriter
{
	bool write(in ubyte[] v)
	{
		_data ~= v;
		return true;
	}

	bool wskip(size_t cnt)
	{
		_data.length += cnt;
		return true;
	}

	const length() { return _data.length; }
private:
	mixin publicProperty!(ubyte[], `data`);
}

// ----------------------------------------- READ FUNCTIONS -----------------------------------------

auto binaryRead(T, bool UseDup = false)(in void[] data, bool canRest = false, string f = __FILE__, uint l = __LINE__)
{
	auto r = data.BinaryReader!(MemoryReader!UseDup);
	auto v = r.read!T(f, l);

	!r.reader.length || canRest || throwErrorImpl(f, l, `not all the buffer was parsed, %u bytes rest`, r.reader.length);
	return v;
}

auto binaryReadFile(T)(string name, string f = __FILE__, uint l = __LINE__)
{
	auto m = new MmFile(name);

	try
	{
		return m[].binaryRead!(T, true)(false, f, l);
	}
	finally
	{
		m.destroy;
	}
}

// ----------------------------------------- WRITE FUNCTIONS -----------------------------------------

const(void)[] binaryWrite(T)(auto ref in T data, string f = __FILE__, uint l = __LINE__)
{
	return BinaryReader!AppendWriter().write(data, f, l).reader.data;
}

void binaryWrite(T)(void[] buf, auto ref in T data, bool canRest = false, string f = __FILE__, uint l = __LINE__)
{
	auto r = buf.BinaryReader!(MemoryReader!());
	r.write(data, f, l);

	!r.reader.length || canRest || throwErrorImpl(f, l, `not all the buffer was used, %u bytes rest`, r.reader.length);
}

void binaryWriteFile(T)(string name, auto ref in T data, string f = __FILE__, uint l = __LINE__)
{
	auto len = binaryWriteLen(data, f, l);
	auto m = new MmFile(name, MmFile.Mode.readWriteNew, len, null);

	try
	{
		binaryWrite(m[], data, false, f, l);
	}
	finally
	{
		m.destroy;
	}
}

auto binaryWriteLen(T)(auto ref in T data, string f = __FILE__, uint l = __LINE__)
{
	struct LengthCalc
	{
		bool write(in ubyte[] v)
		{
			length += v.length;
			return true;
		}

		bool wskip(uint cnt)
		{
			length += cnt;
			return true;
		}

		uint length;
	}

	return BinaryReader!LengthCalc().write(data, f, l).reader.length;
}

private:

auto checkAttrs(string[] arr...)
{
	while(arr.length)
	{
		switch(arr.front)
		{
		case `default`, `skip`, `length`, `ignoreif`, `validif`:
			arr.popFront;
			goto case;

		case `rest`, `ubyte`, `ushort`, `uint`:
			arr.popFront;
			break;

		default:
			return arr.front;
		}
	}

	return null;
}

template isDataSimple(T)
{
	static if(isBasicType!T)
	{
		enum isDataSimple = true;
	}
	else static if(isStaticArray!T)
	{
		enum isDataSimple = isDataSimple!(ElementEncodingType!T);
	}
	else
	{
		enum isDataSimple = false;
	}
}

auto StructExecuter(alias _expr, D, S, P, R)(ref D CUR, ref S STRUCT, ref P PARENT, ref R READER)
{
	with(CUR)
	{
		return mixin(_expr);
	}
}

template FieldsToProcess(T)
{
	auto gen()
	{
		int k, sz;

		string u;
		string[] res;

		void add()
		{
			if(u.length)
			{
				res ~= u;
				u = null;
			}
		}

		foreach(name; __traits(allMembers, T))
		{
			static if(__traits(getProtection, mixin(`T.` ~ name)) == `public`)
			{
				alias E = Alias!(__traits(getMember, T, name));

				static if(!(is(FunctionTypeOf!E == function) || hasUDA!(E, `ignore`)))
				{
					static if(is(typeof(E.offsetof)) && isAssignable!(typeof(E)))
					{
						uint x = E.offsetof, s = E.sizeof;

						if(k != x)
						{
							add;
							u = name;

							k = x;
							sz = s;
						}
						else if(s > sz)
						{
							u = name;
							sz = s;
						}
					}
					else static if(__traits(compiles, &E) && is(typeof(E) == immutable))
					{
						add;
						res ~= name;
					}
				}
			}
		}

		add;
		return res;
	}

	enum FieldsToProcess = aliasSeqOf!(gen());
}

unittest
{
	static struct Test
	{
		enum X = 10;

		enum Y
		{
			i = 12
		}

		static struct S
		{
			uint k = 4;
		}

		static int sx = 1;
		__gshared int gx = 2;

		Y y;
		static Y sy;

		static void f() {}
		static void f2() pure nothrow @nogc @safe {}

		shared void g() {}

		static void function() fp;
		__gshared void function() gfp;
		void function() fpm;

		void delegate() dm;
		static void delegate() sd;

		void m() {}
		final void m2() const pure nothrow @nogc @safe {}

		inout(int) iom() inout { return 10; }
		static inout(int) iosf(inout int x) { return x; }

		@property int p() { return 10; }
		static @property int sp() { return 10; }

		union
		{
			int a = 11;
			float b;
			long u;
			double gg;
		}

		S s;
		static immutable char[4] c = `ABCD`;
		string d = `abc`;

		@(`uint`) int[] e = [ 1, 2, 3 ];
		@(`length`, 3) int[] r = [ 4, 5, 6 ];
	}

	static assert(FieldsToProcess!Test == AliasSeq!(`y`, `u`, `s`, `c`, `d`, `e`, `r`));

	ubyte[] data =
	[
		12, 0, 0, 0,				// y
		11, 0, 0, 0, 0, 0, 0, 0,	// a
		4, 0, 0, 0,					// S.k
		65, 66, 67, 68,				// c
		97, 98, 99, 0,				// d, null terminated
		3, 0, 0, 0,					// e.length
		1, 0, 0, 0,					// e[0]
		2, 0, 0, 0,					// e[1]
		3, 0, 0, 0,					// e[3]
		4, 0, 0, 0,					// r[0], length is set by the user
		5, 0, 0, 0,					// r[1]
		6, 0, 0, 0					// r[2]
	];

	Test t;

	assert(t.binaryWrite == data);
	assert(data.binaryRead!Test == t);

	auto name = `__tmp`;
	binaryWriteFile(name, t);

	assert(std.file.read(name) == data);
	assert(binaryReadFile!Test(name) == t);

	std.file.remove(name);
}
