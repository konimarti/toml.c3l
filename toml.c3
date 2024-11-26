module toml;

import std::io;
import std::collections::object;

struct Config (Printable)
{
	Object* table;
}

fn usz! Config.to_format(&self, Formatter* formatter) @dynamic
{
	Object *obj = self.table;
	if (obj == null) {
		obj = &object::NULL_OBJECT;
	}
	return obj.to_format(formatter);
}

fn Object*! Config.get(&self, String dotted_keys)
{
	String[] keys = dotted_keys.split(".", 0, allocator::temp());
	Object* value = self.table;
	foreach (key : keys)
	{
		value = value.get(key)!;
	}
	return value;
}

fn void Config.free(&self)
{
	if (self.table)
	{
		self.table.free();
	}
}

fn Config! from_file(String filename, Allocator allocator = allocator::heap())
{
	File f = file::open(filename, "r")!;
	defer (void)f.close();
	Config! cfg = from_stream(&f, allocator)!;
	return cfg;
}

fn Config! from_stream(InStream reader, Allocator allocator = allocator::heap())
{
	ByteWriter writer;
	io::copy_to(reader, writer.temp_init())!;
	return Config{toml::parser::Parser{}.init(writer.str_view(), allocator).toml()!};
}

fn Config! from_string(String s, Allocator allocator = allocator::heap())
{
	return Config{toml::parser::Parser{}.init(s, allocator).toml()!};
}

macro void! Config.@unmarshal(&self, &t) => @unmarshal_obj(*t, self.table);


