module tt.sqlite;

import
		std.conv,
		std.array,
		std.string,
		std.typecons,
		etc.c.sqlite3,
		tt.error;

public import std.typecons : Tuple;


final class SQLite
{
	this(string name)
	{
		!sqlite3_open(name.toStringz, &_db) || throwError(error);
	}

	~this()
	{
		sqlite3_close(_db);
	}

	static escape(string s)
	{
		return format(`'%s'`, s.replace(`'`, `''`));
	}

	auto query(T = void, A...)(string q, auto ref in A args)
	{
		static if(A.length)
		{
			q = format(q, staticMap!(argWrap, args));
		}

		static if(is(T == void))
		{
			enum cb = null;
			enum data = null;
		}
		else
		{
			alias R = T[];
			R res;

			extern(C) int func(void *data, int n, char **fields, char **cols)
			{
				auto r = cast(R *)data;
				r.length++;

				foreach(k, U; T.Types)
				{
					(*r).back[k] = fields[k].fromStringz.to!U;
				}

				return 0;
			}

			auto cb = &func;
			auto data = &res;
		}

		sqlite3_exec(_db, q.toStringz, cb, data, null) == SQLITE_OK || throwError(`can't execute query: %s - %s`, q, error);

		static if(is(typeof(res)))
		{
			return res;
		}
	}

	auto lastId()
	{
		return cast(uint)sqlite3_last_insert_rowid(_db);
	}

	auto affected()
	{
		return cast(uint)sqlite3_changes(_db);
	}

private:
	static argWrap(T)(T v)
	{
		static if(is(T : string)) return escape(v);
		return v;
	}

	auto error()
	{
		return cast(string)sqlite3_errmsg(_db).fromStringz;
	}

	sqlite3 *_db;
}
