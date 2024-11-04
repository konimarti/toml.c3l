module toml::scanner;

import std::io;
import std::collections::object;
import std::collections::list;

def StringList = List(<String>);

struct Scanner
{
	InStream s;
	Allocator allocator;
	bool unread;
	char current;
	int line;
	Object* table;
}

fn void Scanner.init(&self, InStream s, Allocator allocator)
{
	*self = {s, allocator, false, '\0', 1, null};
}

fn char! Scanner.read_byte(&self)
{
	if (self.unread)
	{
		self.unread = false;
		return self.current;
	}
	self.current = self.s.read_byte()!;
	return self.current;
}

fn void Scanner.unread_byte(&self)
{
	self.unread = true; 
}

fn char! Scanner.peek(&self)
{
	if (self.unread)
	{
		return self.current;
	}
	char c = self.read_byte()!;
	self.unread_byte();
	return c;
}

fn bool is_ws(char c)
{
	return (c == 0x20 || c == 0x09);
}

fn void! Scanner.skip_ws(&self)
{
	char c;
	while ((c = self.peek()!) && is_ws(c)) self.read_byte()!;
}

fn void! Scanner.skip_line(&self)
{
	char c;
	do {
		c = self.read_byte()!;
	}
	while (c != 0x0A);
}

fn Object*! Scanner.toml(&self)
{
	Object* obj = object::new_obj(self.allocator);
	self.table = obj;
	while LOOP: (1) {
		if (catch err = self.expr(obj))
		{
			if (err == IoError.EOF) break LOOP;
			return err?;
		}
	}
	return obj;
}

fn DString! Scanner.read_until_char(&self, char stop)
{
	DString s;
	s.new_init(16, self.allocator);

	char! c;
	while LOOP: (1)
	{ 
		c = self.read_byte();
		if (catch err = c) 
		{
			if (err == IoError.EOF) return IoError.UNEXPECTED_EOF?;
			return err?;
		}
		if (c == stop) break LOOP;
		s.append_char(c);
	}
	return s;
}


fn StringList! Scanner.read_key(&self)
{
	StringList list;
	list.new_init(6, self.allocator);

	DString s;
	s.new_init(16, self.allocator);

	char c;
	while LOOP: (1)
	{
		c = self.read_byte()!;

		if (c == '=' || c == ']' || c == '\n' || c == '#') {
			self.unread_byte();
			String key = s.copy_str(self.allocator);
			if (key.len > 0)
			{
				list.push(key);
			}
			else
			{
				io::printfn("line %d: empty key", self.line);
			}
			s.free();
			break LOOP;
		}

		if (c == '"' || c == '\'') {
			self.read_byte()!;
			s = self.read_until_char(c)!;
			continue;
		}

		if (is_ws(c)) {
			self.skip_ws()!;
			continue;
		}

		 if (c == '.') {
			String key = s.copy_str(self.allocator);
			if (key.len > 0)
			{
				list.push(key);
			}
			else
			{
				io::printfn("line %d: empty key", self.line);
			}
			s.clear();
			self.skip_ws()!;
		} else {
			s.append_char(c);
		}
	}

	return list;
}

fn void! Scanner.add_keyval(&self, Object *obj, StringList k, Object* v)
{
	Object* cur = obj;
	if (k.len() == 0)
	{
		io::printn("no keys!!");
		return IoError.GENERAL_ERROR?;
	} 
	String key = k.pop()!;
	foreach(table : k)
	{
		if (cur.has_key(table)) {
			io::printfn("found table: %s", table);
		} else {
			io::printfn("create new table: %s", table);
			Object* new_table = object::new_obj(self.allocator);
			cur.set(table, new_table);
		}
		cur = cur.get(table)!;
	}
	cur.set(key, v);
}

fn void! Scanner.parse_keyval(&self, Object *obj)
{
	// key is a list of table
	StringList key = self.read_key()!;

	if (key.len() == 0) {
		io::printn("empty keys..");
		return;
	}

	// consume ws '=' ws
	self.skip_ws()!;
	if (self.peek()! != '=') {
		io::printfn("line %d: expected '=' but got '%c'", self.line, self.peek()!);
		return IoError.GENERAL_ERROR?;
	}
	self.read_byte()!;
	self.skip_ws()!;

	// FIXME: Object* val = self.read_value()!;
	Object* val = object::new_null();

	self.add_keyval(obj, key, val)!;
}

fn Object*! Scanner.parse_table(&self, Object *obj)
{
	char c;
	c = self.read_byte()!;
	if (c != '[') {
		io::printfn("line %d: expected '[' but got %c", self.line, self.peek()!);
		return IoError.GENERAL_ERROR?;
	}

	// key is a list of table
	StringList key = self.read_key()!;

	Object *cur = obj;
	foreach(table : key)
	{
		if (cur.has_key(table)) {
			io::printfn("found table: %s", table);
		} else {
			io::printfn("create new table: %s", table);
			Object* new_table = object::new_obj(self.allocator);
			cur.set(table, new_table);
		}
		cur = cur.get(table)!;
	}

	self.skip_ws()!;
	c = self.read_byte()!;
	if (c != ']') {
		io::printfn("expected ']' but got %c", self.peek()!);
		return IoError.GENERAL_ERROR?;
	}

	return cur;
}

fn void! Scanner.expr(&self, Object *obj)
{
	char c;

	self.skip_ws()!;

	c = self.peek()!;
	switch (c) {
		case '#':
			self.skip_line()!;
			self.line++;
			return;
		case '[':
			self.table = self.parse_table(obj)!;
		default:
			self.parse_keyval(self.table)!;
	}

	self.skip_ws()!;

	c = self.peek()!;
	switch (c)
	{
		case '#':
			self.skip_line()!;
		case 0x0D:
			self.read_byte()!;
			self.read_byte()!;
			self.line++;
		case 0x0A:
			self.read_byte()!;
			self.line++;
	}
}


