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

fn bool is_newline(char c)
{
	return (c == 0x0A || c == 0x0D);
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

fn void! Scanner.skip_ws_comment_newline(&self)
{
	char c = self.peek()!;
	switch
	{
		case is_ws(c):
		case is_newline(c):
			self.read_byte()!;
			return self.skip_ws_comment_newline();
		case c == '#':
			self.skip_line()!;
	}
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

fn DString! Scanner.read_quoted_string(&self)
{
	char quote = self.read_byte()!;
	bool ml = false;

	if (try self.peek()!)
	{
		if (self.peek()! == quote)
		{
			self.read_byte()!;
			if (try self.peek()!)
			{
				if (self.peek()! == quote)
				{
					self.read_byte()!;
					ml = true;
				}
			}
		}
			
	}

	DString suffix;
	suffix.new_init(3, self.allocator);
	suffix.append_char(quote);
	if (ml) suffix.append_repeat(quote, 2);

	if (ml)
	{
		switch (self.peek()!)
		{
			case 0x0D:
				self.read_byte()!;
				nextcase;
			case 0x0A:
				self.read_byte()!;
		}
	}


	DString s;
	s.new_init(16, self.allocator);
	char! c;
	bool more;
	while LOOP: (1)
	{ 
		c = self.read_byte();
		if (catch err = c) 
		{
			if (err == IoError.EOF) return IoError.UNEXPECTED_EOF?;
			return err?;
		}
		more = false;
		if (try p = self.peek())
		{
			more = p == quote;
		}
		if (!more && s.str_view().ends_with(suffix.str_view())) {
			s.delete(s.len() - suffix.len(), suffix.len());
			break LOOP;
		}
		s.append_char(c);
	}

	return s;
}

fn bool! Scanner.match(&self, String str)
{
	char c;
	foreach (s : str)
	{
		c = self.read_byte()!;
		if (c != s) return false;
		
	}
	return true;
}

fn Object*! Scanner.parse_value(&self)
{
	self.skip_ws()!;

	DString s;
	defer { s.free(); }

	char c = self.peek()!;
	switch (c)
	{
		case '"':
		case '\'':
			/*
			self.read_byte()!;
			s = self.read_until_char(c)!;
			self.read_byte()!;
			*/
			s = self.read_quoted_string()!;
			String str = s.copy_str(self.allocator);
			return object::new_string(str, self.allocator);
		case 't':
			if (self.match("true")!)
			{
				return object::new_bool(true);
			}
			else
			{
				io::printfn("line %d: expected value 'true' but did not match", self.line);
				return object::new_null();
			}
		case 'f':
			if (self.match("false")!)
			{
				return object::new_bool(false);
			}
			else
			{
				io::printfn("line %d: expected value 'false' but did not match", self.line);
				return object::new_null();
			}
		case '[':
			// consume '['
			self.read_byte()!; 

			Object* e;
			Object* arr = object::new_obj(self.allocator);
			while LOOP: (1)
			{
				if (catch self.skip_ws_comment_newline()) break LOOP;

				e = self.parse_value()!;

				if (catch self.skip_ws_comment_newline()) break LOOP;

				switch (self.peek()!)
				{
					case ',':
						self.read_byte()!;
					case ']':
						if (!e.is_null()) arr.push_object(e);
						break LOOP;
				}
				arr.push_object(e);
			}

			// consume ']'
			self.read_byte()!;

			return arr;
		case '{':
			// consume '{'
			self.read_byte()!; 

			Object* table = object::new_obj(self.allocator);
			while LOOP: (1)
			{
				if (catch self.skip_ws()) break LOOP;

				self.parse_keyval(table)!;

				if (catch self.skip_ws()) break LOOP;

				switch (self.peek()!)
				{
					case ',':
						self.read_byte()!;
					case '}':
						break LOOP;
				}
			}

			// consume '}'
			self.read_byte()!;

			return table;
		default:
			while LOOP: (1)
			{
				c = self.peek()!;
				if (is_ws(c) || is_newline(c)) break LOOP;
				switch (c)
				{
				 case '#':
				 case ',':
				 case ']':
					 break LOOP;
				}

				self.read_byte()!;
				s.append_char(c);
			}
			String str = s.copy_str(self.allocator);
			if (str.len == 0) return object::new_null();

			// io::printfn("convertin string '%s'", str);

			int! i = str.to_int();
			if (try i)
			{
				return object::new_int(i, self.allocator);
			}
			if (catch err = i)
			{
				// io::printfn("convertin to int failed: %s", err);
			}

			double! f = str.to_double();
			if (try f) return object::new_float(f, self.allocator);

			// TODO: read date-time

			return object::new_string(str, self.allocator);
	}
}


fn StringList! Scanner.parse_key(&self)
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
	if (k.len() == 0)
	{
		io::printn("no keys!!");
		return IoError.GENERAL_ERROR?;
	} 
	String key = k.pop()!;
	Object *cur = self.create_table(k, obj)!;
	cur.set(key, v);
}

fn void! Scanner.parse_keyval(&self, Object *obj)
{
	// key is a list of table
	StringList key = self.parse_key()!;

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

	Object* val = self.parse_value()!;

	self.add_keyval(obj, key, val)!;
}

fn Object*! Scanner.create_table(&self, StringList tables, Object *cur)
{
	foreach(table : tables)
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
	return cur;
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
	StringList key = self.parse_key()!;

	Object *cur = self.create_table(key, obj)!;

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


