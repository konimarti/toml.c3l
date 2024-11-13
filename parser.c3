module toml::parser;

import std::io;
import std::collections::object;
import std::collections::list;

import toml::rfc3339;

def StringList = List(<String>);

fault ParserError
{
	ERROR
}

struct Parser
{
	String s;
	Allocator allocator;
	int start;
	int current;
	int line;
	Object* current_table;
}

fn Parser* Parser.init(&self, String s, Allocator allocator)
{
	*self = {.s = s, .allocator = allocator, .start = 0, .current = 0, 
		.line = 1, .current_table = null};
	return self;
}

fn char! Parser.advance(&self) => self.read_byte();

fn char! Parser.read_byte(&self)
{
	if (self.at_end()) return IoError.EOF?;
	return self.s[self.current++];
}

fn void Parser.unread_byte(&self)
{
	self.current--;
}

fn char Parser.peek(&self)
{
	if (self.at_end()) return '\0';
	return self.s[self.current];
}

fn bool Parser.at_end(&self)
{
	return self.current >= self.s.len;
}

fn bool is_ws(char c) => (c == 0x20 || c == 0x09);
fn bool is_newline(char c) => (c == 0x0A || c == 0x0D);
fn bool non_ascii(char c) => (c >= 0x80);
fn bool non_eol(char c)
{
	return (c == 0x09 || (c >= 0x20 && c <= 0x7F) || non_ascii(c));
}

fn void! Parser.skip_ws(&self)
{
	while (is_ws(self.peek())) self.advance()!;
	self.start = self.current;
}

// comment = comment-start-symbol *non-eol
// comment-start-symboel = #
// non-eol =  0x09 / 0x20 - 0x7f / non-ascii
// non-ascii = 0x80 - D7FF/ 0xE000 - 10FFFF
fn void! Parser.skip_comment(&self)
{
	if (!self.must('#')) return;
	while (non_eol(self.peek())) self.advance()!;
	self.start = self.current;
}

// sw-comment-newline = *( wschar / [comment ] newline )
fn void! Parser.skip_ws_comment_newline(&self)
{
	while LOOP: (1)
	{
		char c = self.peek();
		switch
		{
			case is_ws(c):
				self.skip_ws()!;
			case c == '#':
				self.skip_comment()!;
			case is_newline(c):
				self.advance()!;
			default:
				break LOOP;
		}
	}
	self.start = self.current;
}

fn String! Parser.text(&self)
{
	return self.s[self.start..self.current-1];
}

fn bool Parser.must(&self, char c)
{
	if (self.peek() != c) return false;
	self.current++;
	return true;
}

fn bool! Parser.match(&self, String str)
{
	int backup = self.current;
	foreach (s : str)
	{
		if (!self.must(s)) {
			self.current = backup;
			return false;
		}
		
	}
	return true;
}

fn Object*! Parser.boolean(&self)
{
	bool value;
	if (self.match("true")!)
	{
		value = true;
	}
	else if (self.match("false")!)
	{
		value = false;
	}
	else
	{
		io::printfn("line %d: could not parse boolean", self.line);
		return object::new_null();
	}
	return object::new_bool(value);
}

// inline-table = inline-table-open [ inline-table-keyvals ] inline-table-close
// inline-table-open = '[' ws
// inline-table-close = ws ']'
// inline-table-sep = ws ',' ws
// inline-table-keyvals = keyval [ inline-table-sep inline-table-keyvals ]
fn Object*! Parser.inline_table(&self)
{
	self.must('{');

	Object* table = object::new_obj(self.allocator);
	while LOOP: (1)
	{
		self.skip_ws()!;

		self.keyval(table)!;

		self.skip_ws()!;

		if (!self.must(',')) break LOOP;
	}

	if (!self.must('}'))
	{
		io::printfn("parser error: expected '}'");
		return ParserError.ERROR?;
	}

	return table;
}

fn Object*! Parser.value(&self)
{
	switch (self.peek())
	{
		case '"':
		case '\'':
			return self.string()!;
		case 't':
		case 'f':
			return self.boolean()!;
		case '[':
			return self.array();
		case '{':
			return self.inline_table();
		default:
			return self.number_or_datetime();
	}
}

fn bool is_unquoted_key(char c)
{
	return (c.is_alpha() || c.is_digit() || c == '-' || c == '_');
}

// key = simple-key / dotted-key
// simple-key = quoted-key / unquoted-key
//
// unquoted-key = 1*( ALPHA / DIGIT / 0x2d / 0x5F); A-Z / a-z / 0-9 / - / _
// quoted-key = basic-string / literal-string
// dotted-key = simple-key 1*( dot-sep simple-key )
fn void! Parser.key(&self, StringList *list)
{
	int start, end;
	char c;
	while (1)
	{
		start = self.current;

		self.skip_ws()!;
		c = self.peek();

		if (c == '"' || c == '\'') {
			// quoted key
			char quote = self.advance()!;
			while (self.peek() != quote) self.advance()!;
			self.must(quote);
			start = start + 1;
			end = self.current - 2;
		} else {
			// unquoted key
			while (is_unquoted_key(self.peek())) self.advance()!;
			end = self.current-1;
		}

		if (end <= start) {
			// io::printn("no keys found?");
			return;
		}

		// io::printfn("adding to list: %s", self.s[start..end]);
		list.push(self.s[start..end]);

		self.skip_ws()!;
		if (!self.must('.')) return;
	}
}

fn void! Parser.insert(&self, Object *table, StringList k, Object* v)
{
	if (k.len() == 0)
	{
		io::printn("parser error: cannot insert object: empty key");
		return IoError.GENERAL_ERROR?;
	} 
	String key = k.pop()!;
	self.get_table(k, table)!.set(key, v);
}

// keyval = key keyval-sep val
// keyval-sep = ws '=' ws
fn void! Parser.keyval(&self, Object *obj)
{
	// parse key

	// key is a list of table
	StringList key;
	key.new_init(4, self.allocator);
	defer { key.free(); }

	self.key(&key)!;

	if (key.len() == 0) {
		// io::printn("empty keys..");
		return;
	}

	// consume ws '=' ws
	self.skip_ws()!;
	if (!self.must('='))
	{
		io::printfn("line %d: expected '=' but got '%c'", self.line, self.peek());
		return IoError.GENERAL_ERROR?;
	}
	self.skip_ws()!;

	// parse value
	Object* val = self.value()!;

	self.insert(obj, key, val)!;
}

fn Object*! Parser.get_table(&self, StringList tables, Object *cur, bool create_as_array = false)
{
	foreach(table : tables) cur = cur.get_or_create_obj(table);
	if (create_as_array) {
		cur.push_object(object::new_obj(self.allocator));
	}
	if (cur.is_array()) {
		return cur.get_at(cur.get_len()-1);
	}
	
	return cur;
}

// table = std-table / array-table
//
// std-table = std-table-open key std-table-close
//
// std-table-open = '[' ws
// std-table-close = ws ']'
//
// array-table = array-table-open key array-table-close
//
// array-table-open = '[[' ws
// array-table-close = ws ']]' ws
fn Object*! Parser.table(&self, Object *obj)
{
	if (!self.must('[')) {
		io::printfn("line %d: expected '[' but got %c", self.line, self.peek());
		return ParserError.ERROR?;
	}

	bool create_as_array = self.must('[');

	self.skip_ws()!;

	StringList key;
	key.new_init(4, self.allocator);
	defer key.free();

	self.key(&key)!;

	Object *cur = self.get_table(key, obj, create_as_array)!;

	self.skip_ws()!;

	if (!self.must(']')) {
		io::printfn("line %d: expected ']' but got %c", self.line, self.peek());
		return ParserError.ERROR?;
	}

	if (create_as_array && !self.must(']')) {
		io::printfn("line %d: expected ']' but got %c", self.line, self.peek());
		return ParserError.ERROR?;
	}

	return cur;
}

// expression =  ws [ comment ]
// expression =/ ws keyval ws [ comment ]
// expression =/ ws table ws [ comment ]
fn void! Parser.expression(&self, Object *obj)
{
	self.skip_ws()!;
	self.skip_comment()!;

	if (self.peek() == '[')
	{
		self.current_table = self.table(obj)!;
	}
	else
	{
		self.keyval(self.current_table)!;
	}

	self.skip_ws()!;
	self.skip_comment()!;
}

// toml = expression *( newline expression )
// newline =  0x0A
// newline =/ 0x0D.0x0A
fn Object*! Parser.toml(&self)
{
	Object* obj = object::new_obj(self.allocator);
	self.current_table = obj;
	while LOOP: (1) {
		if (catch err = self.expression(obj))
		{
			if (err == IoError.EOF) break LOOP;
			return err?;
		}
		self.must('\r');
		if (self.must('\n'))
		{
			self.line++;
		}
		else
		{
			io::printn("parser: expected newline");
			if (self.at_end()) break LOOP;
		}
	}
	return obj;
}

