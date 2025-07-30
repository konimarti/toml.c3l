module toml;

import std::io;
import std::collections::object @public;

import toml::time;

struct TomlData (Printable)
{
	Object* table;
}

fn usz? TomlData.to_format(&self, Formatter* formatter) @dynamic
{
	Object *object = self.table;
	if (object == null) {
		object = &object::NULL_OBJECT;
	}
	return to_tagged_json(object, formatter);
}

fn String tescape_json(String s)
{
	DString buf = dstring::temp();
	foreach (c : s)
	{
		switch (c)
		{
		case '"': buf.append_char('\\');
		}
		buf.append_char(c);
	}
	return buf.str_view();
}

fn usz? to_tagged_json(Object *self, Formatter* formatter) => @pool()
{
	switch (self.type)
	{
		case void:
			return formatter.printf("{}")!;
		case void*:
			return formatter.printf("null")!;
		case String:
			if (try toml_date_time = time::parse(self.s))
			{
				switch (toml_date_time.kind)
				{
				case DATE_ONLY: return formatter.printf(`{"type":"date-local","value":"%s"}`, self.s)!;
				case TIME_ONLY: return formatter.printf(`{"type":"time-local","value":"%s"}`, self.s)!;
				case LOCAL_DATE_TIME: return formatter.printf(`{"type":"datetime-local","value":"%s"}`, self.s)!;
				case OFFSET_DATE_TIME: return formatter.printf(`{"type":"datetime","value":"%s"}`, self.s)!;
				}
			}
			else
			{
				return formatter.printf(`{"type":"string","value":"%s"}`, tescape_json(self.s))!;
			}
		case bool:
			return formatter.printf(`{"type":"bool","value":"%s"}`, self.b ? "true" : "false")!;
		case ObjectInternalList:
			usz n = formatter.printf("[")!;
			foreach (i, ol : self.array)
			{
				if (i > 0) n += formatter.printf(",")!;
				// n += ol.to_format(formatter)!;
				n += to_tagged_json(ol, formatter)!;
			}
			n += formatter.printf("]")!;
			return n;
		case ObjectInternalMap:
			usz n = formatter.printf("{")!;
			@stack_mem(1024; Allocator mem)
			{
				foreach (i, key : self.map.keys(mem))
				{
					if (i > 0) n += formatter.printf(",")!;
					n += formatter.printf(`"%s":`, tescape_json(key))!;
					// n += self.map.get(key).to_format(formatter)!;
					n += to_tagged_json(self.map.get(key), formatter)!;
				}
			};
			n += formatter.printf("}")!;
			return n;
		default:
			switch (self.type.kindof)
			{
				case SIGNED_INT:
					return formatter.printf(`{"type":"integer","value":"%d"}`, (int128)self.i)!;
				case UNSIGNED_INT:
					return formatter.printf(`{"type":"integer","value":"%d"}`, (uint128)self.i)!;
				case FLOAT:
					return formatter.printf(`{"type":"float","value":"%g"}`, self.f)!;
				case ENUM:
					return formatter.printf("%d", self.i)!;
				default:
					return formatter.printf("<>")!;
			}
	}
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
