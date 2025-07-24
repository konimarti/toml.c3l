module toml;

import std::io;
import std::collections::object;

struct TomlData (Printable)
{
	Object* table;
}

fn usz? TomlData.to_format(&self, Formatter* formatter) @dynamic
{
	Object *obj = self.table;
	if (obj == null) {
		obj = &object::NULL_OBJECT;
	}
	return obj.to_format(formatter);
}

fn Object*? TomlData.get(&self, String dotted_keys)
{
	String[] keys = dotted_keys.tsplit(".", 0);
	Object* value = self.table;
	foreach (key : keys)
	{
		value = value.get(key)!;
	}
	return value;
}

fn void TomlData.free(&self)
{
	if (self.table)
	{
		self.table.free();
	}
}

fn TomlData? from_file(String filename, Allocator allocator = mem)
{
	File f = file::open(filename, "r")!;
	defer (void)f.close();
	TomlData? cfg = from_stream(&f, allocator)!;
	return cfg;
}

fn TomlData? from_stream(InStream reader, Allocator allocator = mem)
{
	ByteWriter writer;
	io::copy_to(reader, writer.tinit())!;
	return (TomlData){(toml::parser::Parser){}.init(writer.str_view(), allocator).toml()!};
}

fn TomlData? from_string(String s, Allocator allocator = mem)
{
	return (TomlData){(toml::parser::Parser){}.init(s, allocator).toml()!};
}

macro void? TomlData.unmarshal(&self, t) => unmarshal_obj(t, self.table);
