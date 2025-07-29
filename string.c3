module toml::parser;

import std::io;
import std::collections::object;

const ESCAPE = '\\';

fn bool escape_seq_char(char c) @inline
{
	switch(c)
	{
		case 0x22: // \
		case 0x5C: // "
		case 0x62: // b
		case 0x66: // f
		case 0x6E: // n
		case 0x72: // r
		case 0x74: // t
		case 0x75: // u 4HEXDIG
		case 0x55: // U 8HEXDIG
			return true;
		default:
			return false;
	}
}

fn bool basic_unescaped(char c) @inline
{
	return (is_ws(c) || c == 0x21 || (c >= 0x23 && c <= 0x5B) || (c >= 0x5D && c <= 0x7E));
}

fn bool literal_char(char c) @inline
{
	return (c == 0x09 || (c >= 0x20 && c <= 0x26) || (c >= 0x28 && c <= 0x7E));
}


// string = ml-basic-string / basic-string / ml-literal-string / literal-string
fn Object*? Parser.string(&self)
{
	self.start = self.current;

	// first quote
	char quote = self.advance()!;

	// second quote
	if (self.must(quote)) {

		// if no third quote is found, then return empty string.
		if (!self.must(quote)) return object::new_string("", self.allocator);

		if (quote == '"')
		{
			return self.ml_basic_string()!;
		}
		else if (quote == '\'')
		{
			return self.ml_literal_string()!;
		}
		else
		{
			self.error("invalid quote; only use \" and '");
			return parser::INVALID_QUOTE?;
		}

	}
	else
	{
		// handle single-quoted string "abc"
		// first quote was already consumed.

		// basic-string / basic-literal
		if (quote == '"')
		{
			self.basic_string()!;
		}
		else if (quote == '\'')
		{
			self.literal_string()!;
		}
		else
		{
			self.error("invalid quote; only use \" and '");
			return parser::INVALID_QUOTE?;
		}

		return object::new_string(self.text()[1..^2], self.allocator);
	}
}

// ml-basic-string = ml-basic-string-delim [ newline ] ml-basic-body
// 			ml-basic-string-delim
// ml-basic-string-delim = 3quotation-mark
// ml-basic-body = *mlb-content *( mlb-quotes 1*mlb-content ) [ mlb-quotes ]
// mlb-quotes = 1*2quotation-mark
fn Object*? Parser.ml_basic_string(&self)
{
	// ml-basic-string-delim has been read at this point.

	DString d;
	d.init(self.allocator, 16);
	defer d.free();

	// [ newline ]
	if (is_newline(self.peek())) self.advance()!;

	// ml-basic-body
	while LOOP: (1)
	{
		self.mlb_content(&d)!;

		// maximum much for quotes, but cannot have more than 5
		// terminal quotes
		int i = 0;
		while (!self.at_end() && self.must('"'))
		{
			i++;
			d.append_char('"');
		}
		switch
		{
			case i < 3:
				if (self.at_end()) return parser::UNCLOSED_MULTILINE?;
				continue;
			case i >= 3 && i < 6:
				break LOOP;
			case i >= 6:
				self.error("terminal quote sequence is invalid; there are too many..");
				return parser::INVALID_TERMINAL_QUOTES?;
		}
	}

	// must have at least 6 chars (""""""") in smallest ml string
	if (d.len() <= 3)
	{
		self.error("multi-line string is not long enough; did add three quotes on both sides?");
		return parser::MULTILINE_STRING_TOO_SHORT?;
	}

	return object::new_string(d.str_view().strip_end(`"""`), self.allocator);
}

// mlb-content = mlb-char / newline / mlb-escaped-nl
// mlb-char = mlb-unescaped / escaped
// mlb-unescaped = wschar / 0x21 / 0x23 - 0x5B / 0x5D - 0x7E / non-ascii
// mlb-escaped-nl = escape ws newline *( wschar / newline )
// TODO: non-ascii
fn void? Parser.mlb_content(&self, DString *d)
{
	// mlb-content = mlb-char / newline / mlb-escaped-nl
	char c;
	while LOOP: (1)
	{
		c = self.peek();

		// mlb-char = escaped
		if (is_ws(c) || c == 0x21 || (c >= 0x23 && c <= 0x5B) || (c >= 0x5D && c <= 0x7E)) {
			d.append_char(self.advance()!);
			continue;
		}

		// newline
		if (is_newline(c)) {
			d.append_char(self.advance()!);
			continue;
		}

		// mlb-char = escaped
		// mlb-escaped-nl = escape ws newline *( wschar / newline )
		if (self.must(ESCAPE))
		{
			if (escape_seq_char(self.peek()))
			{
				char u;
				d.append_char(ESCAPE);
				d.append_char(u = self.advance()!);

				int n = 0;
				switch (u)
				{
					case 0x75:
						n = 4;
					case 0x55:
						n = 8;
				}

				for (int i = 0; i < n; i++)
				{
					if (self.peek().is_xdigit())
					{
						d.append_char(self.advance()!);
					}
					else
					{
						self.error("invalid escaped unicode sequence");
						return parser::INVALID_ESCAPE_UNICODE?;
					}
				}

				continue;
			}
			else
			{
				// non-escaped-terminal \ must be the last
				// non-whitespace character
				while (is_ws(self.peek())) self.advance()!;
				if (!is_newline(self.peek())) return INVALID_LINE_ENDING_BACKSLASH?;
				while (is_ws(self.peek()) || is_newline(self.peek())) self.advance()!;
			}
		}

		break LOOP;
	}
}


// basic-string = quotation-mark *basic-char quotation-mark
// basic-char = basic-unescaped / escaped
// basic-unescaped = wschar / 0x21 / 0x23 - 0x5B / 0x5D - 0x-7E / non-ascii
// escaped = escape escape-seq-char
// escape = 0x5C ; \
// escape-seq-char = 0x22 / 0x5C / 0x62 / 0x66 / 0x6E / 0x72 / 0x72 / unicode??
// TODO: non-ascii
fn void? Parser.basic_string(&self)
{
	// beginning quote is already consumed.

	while LOOP: (1)
	{
		// basic-unescaped
		if (basic_unescaped(self.peek()))
		{
			self.advance()!;
			continue;
		}

		// escaped
		if (self.must(ESCAPE)) {
			if (escape_seq_char(self.peek()))
			{
				char u;
				u = self.advance()!;

				int n = 0;
				switch (u)
				{
					case 0x75:
						n = 4;
					case 0x55:
						n = 8;
				}

				for (int i = 0; i < n; i++)
				{
					if (self.peek().is_xdigit())
					{
						self.advance()!;
					}
					else
					{
						self.error("invalid escaped unicode sequence");
						return parser::INVALID_ESCAPE_UNICODE?;
					}
				}

				continue;
			}
			else
			{
				self.error("invalid escape sequence");
				return parser::INVALID_ESCAPE_SEQUENCE?;
			}
		}

		if (!self.must('"'))
		{
			self.error("missing closing quote \"");
			return parser::UNCLOSED_QUOTE?;
		}

		break LOOP;
	}
}

// ml-literal-string = ml-literal-string delim [ newline ] ml-literal-body
//			ml-literal-string-delim
// ml-literal-string-delim = 3apostrophe
// ml-literal-body = "mll-content *( mll-quotes 1*mll-content ) [ mll-quotes ]
fn Object*? Parser.ml_literal_string(&self)
{
	// ml-literal-string-delim has been read at this point.

	DString d;
	d.init(self.allocator, 16);
	defer d.free();

	// [ newline ]
	if (is_newline(self.peek())) self.advance()!;

	// ml-literal-body
	while LOOP: (1)
	{
		self.mll_content(&d)!;

		// maximum much for quotes, but cannot have more than 5
		// terminal quotes
		int i = 0;
		while (!self.at_end() && self.must('\''))
		{
			i++;
			d.append_char('\'');
		}
		switch
		{
			case i < 3:
				if (self.at_end()) return parser::UNCLOSED_MULTILINE?;
				continue;
			case i >= 3 && i < 6:
				break LOOP;
			case i >= 6:
				self.error("terminal apostrophe sequence is invalid; there are too many..");
				return parser::INVALID_TERMINAL_QUOTES?;
		}
	}

	// must have at least 3 chars (''') in smallest ml string
	if (d.len() <= 3)
	{
		self.error("multi-line string is not long enough; did add three apostrophes on both sides?");
		return parser::MULTILINE_STRING_TOO_SHORT?;
	}

	return object::new_string(d.str_view().strip_end(`'''`), self.allocator);
}

// mll-content = mll-char / newline
// mll-char = 0x09 / 0x20 - 0x26 / 0x28 - 0x7E / non-ascci
// mll-quotes = 1*2apstrophe
// TODO: non-ascii
fn void? Parser.mll_content(&self, DString *d)
{
	// mll-content = mll-char / newline
	char c;
	while LOOP: (1)
	{
		c = self.peek();

		// mll-char
		if (c == 0x09 || (c >= 0x20 && c <= 0x26) || (c >= 0x28 && c <= 0x7E)) {
			d.append_char(self.advance()!);
			continue;
		}

		// newline
		if (is_newline(c)) {
			d.append_char(self.advance()!);
			continue;
		}

		break LOOP;
	}
}

// literal-string = apostrophe *literal-char apostrophe
// literal-char = 0x09 / 0x20 - 0x26 / 0x28 - 0x7E / non-ascii
// TODO: non-ascii
fn void? Parser.literal_string(&self)
{
	// beginning apostrophe is already consumed.

	while (1)
	{
		if (!literal_char(self.peek()))
		{
			if (!self.must('\''))
			{
				self.error("missing closing apostrophe '");
				return parser::UNCLOSED_QUOTE?;
			}
			return;
		}
		self.advance()!;
	}
}
