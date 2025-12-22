module toml;

import std::io, std::math;
import std::collections::object @public;

import toml::time;

struct TomlData (Printable)
{
	Object* table;
	String input;
	Allocator allocator;
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
	foreach (c : s.to_temp_utf32()!!)
	{
		switch (c)
		{
		case '"':  buf.append_char('\\'); buf.append_char('"');
		case '\b': buf.append_char('\\'); buf.append_char('b');
		case '\n': buf.append_char('\\'); buf.append_char('n');
		case '\f': buf.append_char('\\'); buf.append_char('f');
		case '\r': buf.append_char('\\'); buf.append_char('r');
		case '\t': buf.append_char('\\'); buf.append_char('t');
		case '/':  buf.append_char('\\'); buf.append_char('/');
		case '\\': buf.append_char('\\'); buf.append_char('\\');
		default:
			// Encode to utf
			if (c <= 0x08 || (c >= 0x0A && c <= 0x1F) || c == 0x7F)
			{
				// Needs to be encoded
				Char16[2] tmp;
				Char16 *p= &tmp[0];
				conv::char32_to_utf16_unsafe(c, &p);
				buf.append_string(`\u`);
				buf.append_string(string::tformat("%04x", tmp[0]));
				if (tmp[1] > 0)
				{
					buf.append_string(`\u`);
					buf.append_string(string::tformat("%04x", tmp[1]));
				}
			}
			else
			{
				buf.append_char32(c);
			}
		}
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
					return formatter.printf(`{"type":"float","value":"%.16e"}`, (double)self.f)!;
				case ENUM:
					return formatter.printf("%d", self.i)!;
				default:
					return formatter.printf("<>")!;
			}
	}
}

fn Object*? TomlData.get(&self, String dotted_keys) @operator([])
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
	allocator::free(self.allocator, self.input);
}

fn TomlData? from_file(String filename, Allocator allocator = mem, bool verbose = true)
{
	File f = file::open(filename, "r")!;
	defer (void)f.close();
	return from_stream(&f, allocator, verbose)!;
}

fn TomlData? from_stream(InStream reader, Allocator allocator = mem, bool verbose = true) => @pool()
{
	ByteWriter writer;
	io::copy_to(reader, writer.tinit())!;
	String input = writer.str_view().copy(allocator);
	return {
		.input     = input,
		.table     = (toml::parser::Parser){}.init(input, allocator, verbose).toml()!,
		.allocator = allocator
	};
}

fn TomlData? from_string(String s, Allocator allocator = mem, bool verbose = true)
{
	String input = s.copy(allocator);
	return {
		.input     = input,
		.table     = (toml::parser::Parser){}.init(input, allocator, verbose).toml()!,
		.allocator = allocator
	};
}

macro void? TomlData.unmarshal(&self, t) => unmarshal_obj(t, self.table);
