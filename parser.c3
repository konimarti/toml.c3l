module toml::parser;

import std::io;
import std::collections::object;
import std::collections::list;

alias StringList = List {String};
alias TableList  = List {Object*};

faultdef DUPLICATED_KEY,
	DUPLICATED_TABLE,
	INVALID_BOOLEAN,
	INVALID_DATETIME,
	INVALID_QUOTE,
	INVALID_TERMINAL_QUOTES,
	INVALID_ESCAPE_UNICODE,
	INVALID_ESCAPE_SEQUENCE,
	INVALID_TOKEN_TYPE,
	INVALID_UNICODE,
	INVALID_NON_ASCII,
	INVALID_UNDERSCORE,
	INVALID_SCALAR_UNICODE,
 	INVALID_LINE_ENDING_BACKSLASH,
	INVALID_TABLE,
	INVALID_ARRAY_TABLE,
	INVALID_ARRAY,
	INVALID_KEY,
 	INVALID_LEADING_ZERO,
	INVALID_COMMA,
	INVALID_LITERAL,
	INVALID_STRING,
	INVALID_NEWLINE,
	UNCLOSED_INLINE_TABLE,
	UNCLOSED_STD_TABLE,
	UNCLOSED_ARRAY_TABLE,
	UNCLOSED_QUOTE,
	UNCLOSED_MULTILINE,
	MISSING_KEYVAL_SEPARATOR,
	MISSING_TABLE_NAME,
	MISSING_TERMINAL_QUOTE,
	MISSING_NEWLINE,
	MISSING_COMMA,
	MULTILINE_STRING_TOO_SHORT,
	UNMUTABLE_INLINE_TABLES,
	UNSIGNED_WITH_SIGN,
	MULTIPLE_ERRORS;

struct Parser
{
	String s;
	Allocator allocator;
	int start;
	int current;
	int line;
	Object* current_table;
	TableList inline_tables;
	TableList array_of_tables;
}

fn Parser* Parser.init(&self, String s, Allocator allocator)
{
	*self = {.s = s, .allocator = allocator, .start = 0, .current = 0,
		.line = 1, .current_table = null};
	return self;
}

fn char? Parser.advance(&self)
{
	if (self.at_end()) return io::EOF?;
	return self.s[self.current++];
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

fn void Parser.error(&self, String msg)
{
	io::eprintfn("TOML ERROR -- Line %d: %s", self.line, msg)!!;
}

fn bool is_ws(char c) => (c == 0x20 || c == 0x09);


// newline =  x0A     ; LF
// newline =/ x0D.0A  ; CRLF
// fn bool is_newline(char c) => (c == 0x0A || c == 0x0D);
fn bool is_lf(char c) => c == 0x0A;

// if CR, then a LF must follow!
fn bool is_cr(char c) => c == 0x0D;

// incomplete implementation of non_ascii; you still not to verify that the
// actual codepoint is a scalar unicode
fn bool non_ascii(char c) => (c >= 0x80);

// Note that the specs says that 0x7f should be allowed as non-eol; but the
// tomltest suite records it as invalid; follow the testsuite.
fn bool non_eol(char c)
{
	return (c == 0x09 || (c >= 0x20 && c < 0x7F) || non_ascii(c));
}

fn bool is_unquoted_key(char c)
{
	return (c.is_alpha() || c.is_digit() || c == '-' || c == '_');
}

fn void? Parser.skip_ws(&self)
{
	while (is_ws(self.peek())) self.advance()!;

	self.start = self.current;
}

// comment = comment-start-symbol *non-eol
// comment-start-symboel = #
// non-eol =  0x09 / 0x20 - 0x7f / non-ascii
// non-ascii = 0x80 - D7FF/ 0xE000 - 10FFFF
fn void? Parser.skip_comment(&self)
{
	if (!self.must('#')) return;

	char c;
	while (non_eol(c = self.peek()))
	{
		// non-ascii
		if (is_unicode(c))
		{
			Char32 codepoint = self.scan_unicode()!;
			if (!is_non_ascii(codepoint)) return INVALID_NON_ASCII?;
		}
		// non-eol
		else
		{
			self.advance()!;
		}
	}
}

// sw-comment-newline = *( wschar / [comment ] newline )
fn void? Parser.skip_ws_comment_newline(&self)
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
			case is_lf(c):
				self.advance()!;
			case is_cr(c):
				self.advance()!;
				if (!is_lf(self.peek())) return INVALID_NEWLINE?;
				self.advance()!;
			default:
				break LOOP;
		}
	}
}

fn String Parser.text(&self)
{
	return self.s[self.start..self.current-1];
}

fn bool Parser.must(&self, char c)
{
	if (self.peek() != c) return false;

	self.current++;

	return true;
}

fn bool? Parser.match(&self, String str)
{
	int backup = self.current;

	foreach (s : str)
	{
		if (!self.must(s))
		{
			self.current = backup;
			return false;
		}
	}

	return true;
}

fn Object*? Parser.boolean(&self)
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
		self.error("could not parse boolean; did you misspell 'true' or 'false'");
		return INVALID_BOOLEAN?;
	}

	return object::new_bool(value);
}

// inline-table = inline-table-open [ inline-table-keyvals ] inline-table-close
// inline-table-open = '[' ws
// inline-table-close = ws ']'
// inline-table-sep = ws ',' ws
// inline-table-keyvals = keyval [ inline-table-sep inline-table-keyvals ]
fn Object*? Parser.inline_table(&self)
{
	self.must('{');

	Object* table = object::new_obj(self.allocator);
	while LOOP: (1)
	{
		self.skip_ws()!;

		switch (self.peek())
		{
		case ',':
		case '}':
			return INVALID_COMMA?;
		}

		self.keyval(table)!;

		self.skip_ws()!;

		if (!self.must(',')) break LOOP;
	}

	if (!self.must('}'))
	{
		self.error("expected '}'");
		return UNCLOSED_INLINE_TABLE?;
	}

	// Store inline table
	self.inline_tables.push(table);

	return table;
}

fn Object*? Parser.value(&self)
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

// key = simple-key / dotted-key
// simple-key = quoted-key / unquoted-key
//
// unquoted-key = 1*( ALPHA / DIGIT / 0x2d / 0x5F); A-Z / a-z / 0-9 / - / _
// quoted-key = basic-string / literal-string
// dotted-key = simple-key 1*( dot-sep simple-key )
//
// Returns true when keys were parsed.
fn bool? Parser.key(&self, StringList *list)
{
	while (1)
	{
		self.skip_ws()!;

		self.start = self.current;

		bool dequote = false;
		if (self.must('"'))
		{
			// quoted-key: basic-string
			self.basic_string()!;
			dequote = true;
		}
		else if (self.must('\''))
		{
			// quoted-key: literal-string
			self.literal_string()!;
			dequote = true;
		}
		else
		{
			// unquoted-key
			while (is_unquoted_key(self.peek())) self.advance()!;
		}

		if (self.current <= self.start) return !list.is_empty();

		String text = self.text();
		if (dequote && text.len > 2) text = text[1 .. ^2];

		list.push(text);

		self.skip_ws()!;

		if (!self.must('.')) return !list.is_empty();
	}
}

fn void? Parser.insert(&self, Object *table, StringList k, Object* v)
{
	String key = k.pop()!;
	Object* target = self.create_table(k, table)!;
	if (!target.is_keyable())
	{
		self.error("Key does not point to a table");
		return INVALID_KEY?;
	}
	if (target.has_key(key))
	{
		self.error("key is already used; duplicated keys are not supported.");
		return DUPLICATED_KEY?;
	}
	else if (self.inline_tables.contains(target))
	{
		self.error("keys cannot be added to inline tables outside the braces");
		return UNMUTABLE_INLINE_TABLES?;
	}
	target.set(key, v);
}

// keyval = key keyval-sep val
// keyval-sep = ws '=' ws
fn void? Parser.keyval(&self, Object *obj)
{
	StringList key;
	key.init(self.allocator, 4);
	defer key.free();

	// parse key
	if (!self.key(&key)!) return;

	// consume ws '=' ws
	self.skip_ws()!;
	if (!self.must('='))
	{
		self.error("expected '='");
		return MISSING_KEYVAL_SEPARATOR?;
	}
	self.skip_ws()!;

	// parse value
	Object* val = self.value()!;

	self.insert(obj, key, val)!;
}

fn Object*? Parser.get_table(&self, StringList tables, Object *cur)
{
	foreach(table : tables)
	{
		if (!cur.is_keyable()) return INVALID_TABLE?;
		cur = cur.get(table)!;
	}
	return cur;
}

fn Object*? Parser.create_table(&self, StringList tables, Object *cur, bool array_of_table = false)
{
	foreach(table : tables)
	{
		if (!cur.is_keyable()) return INVALID_TABLE?;
		if (self.inline_tables.contains(cur))
		{
			self.error("create_table: keys cannot be added to inline tables outside the braces");
			return UNMUTABLE_INLINE_TABLES?;
		}
		cur = cur.get_or_create_obj(table);
	}
	if (array_of_table) {
		if (!cur.is_indexable()) return INVALID_ARRAY_TABLE?;
		if (cur.get_len() == 0) self.array_of_tables.push(cur);
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
fn Object*? Parser.table(&self, Object *obj)
{
	self.must('[');

	bool array_of_table = self.must('[');

	self.skip_ws()!;

	StringList key;
	key.init(self.allocator, 4);
	defer key.free();

	if (!self.key(&key)!)
	{
		self.error("you must specify a table name between [ and ]");
		return MISSING_TABLE_NAME?;
	}

	// Verfiy that table does not exist yet
	if (try tab = self.get_table(key, obj))
	{
		if (array_of_table)
		{
			// Array table already exists and now check that it
			// actually is an array (is_indexable())
			if (!tab.is_array()) return INVALID_ARRAY_TABLE?;

			// Array should be in the array_of_tables list
			if (!self.array_of_tables.contains(tab)) return INVALID_ARRAY_TABLE?;
		}
		else
		{
			// Regular table already exists
			self.error("table already exists");
			return DUPLICATED_TABLE?;
		}
	}

	Object *cur = self.create_table(key, obj, array_of_table)!;

	self.skip_ws()!;

	if (!self.must(']')) {
		io::printfn("line %d: expected ']' but got %c", self.line, self.peek());
		self.error("expected ']'; did you forget to add the closing bracket ']'?");
		return UNCLOSED_STD_TABLE?;
	}

	if (array_of_table && !self.must(']')) {
		self.error("expected ']]'; did you forget to add an additonal ']'?");
		return UNCLOSED_ARRAY_TABLE?;
	}

	return cur;
}

// expression =  ws [ comment ]
// expression =/ ws keyval ws [ comment ]
// expression =/ ws table ws [ comment ]
fn void? Parser.expression(&self, Object *obj)
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
fn Object*? Parser.toml(&self) => @pool()
{
	Object* obj = object::new_obj(self.allocator);
	self.current_table = obj;

	self.inline_tables.clear();
	self.inline_tables.tinit();

	self.array_of_tables.clear();
	self.array_of_tables.tinit();

	fault last_error;
	int max_lines = int.max;
	while LOOP: (max_lines--) {
		if (catch err = self.expression(obj))
		{
			if (err == io::EOF) break LOOP;

			self.error(string::tformat("%s", err));
			last_error = last_error ? MULTIPLE_ERRORS : err;

			// synchronize parser after error by moving to the next
			// newline.
			while (non_eol(self.peek()))
			{
				if (catch adv_err = self.advance())
				{
					if (adv_err == io::EOF) break LOOP;
				}
			}
		}

		self.must('\r');

		if (!self.must('\n'))
		{
			if (self.at_end()) break LOOP;
			io::printfn("remaining: %s", (String)self.s[self.current ..]);
			self.error("Missing Newline after an expression");
			return MISSING_NEWLINE?;
		}

		self.line += 1;
	}

	// If en error has been encountered, return it
	if (last_error) return last_error?;

	// Treat an empty table as an error
	if (obj.is_keyable() && obj.map.len() == 0) return INVALID_TABLE?;

	return obj;
}

