module tt.misc;

import
		std.traits;


mixin template publicProperty(T, string name, string value = null)
{
	mixin(`
		public ref ` ~ name ~ `() @property const { return _` ~ name ~ `; }
		T _` ~ name ~ (value.length ? `=` ~ value : null) ~ `;`
																);
}

auto as(T, E)(ref E data)
{
	static if(isArray!E)
	{
		return cast(T[])data;
	}
	else
	{
		return cast(T[])(&data)[0..1];
	}
}

auto toByte(T)(ref T data)
{
	return data.as!ubyte;
}
