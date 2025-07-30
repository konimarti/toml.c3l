module toml::parser;

import std::io, std::math;
import std::encoding::hex;
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
fn Object*? Parser.ml_basic_string(&self) => @pool()
{
	// ml-basic-string-delim has been read at this point.

	DString buf;
	buf.tinit(16);

	// [ newline ]
	if (is_lf(self.peek()))
	{
		self.advance()!;
	}
	else if (is_cr(self.peek()))
	{
		self.advance()!;
		if (!is_lf(self.peek())) return INVALID_NEWLINE?;
		self.advance()!;
	}

	// ml-basic-body
	while LOOP: (1)
	{
		self.mlb_content(&buf)!;

		// Maximum munch for quotes, but cannot have more than 5
		int len = 0;
		while (!self.at_end() && self.must('"'))
		{
			buf.append_char('"');
			len++;
		}
		switch
		{
			case len > 5:
				self.error("terminal quote sequence is invalid; there are too many..");
				return parser::INVALID_TERMINAL_QUOTES?;
			case len >= 3:
				break LOOP;
			default:
				if (self.at_end()) return parser::UNCLOSED_MULTILINE?;
		}
	}

	// must have at least 6 chars (""""""") in smallest ml string
	if (buf.len() < 3)
	{
		self.error("multi-line string is not long enough; did add three quotes on both sides?");
		return parser::MULTILINE_STRING_TOO_SHORT?;
	}

	return object::new_string(buf.str_view().strip_end(`"""`), self.allocator);
}

// mlb-content = mlb-char / newline / mlb-escaped-nl
// mlb-char = mlb-unescaped / escaped
// mlb-unescaped = wschar / 0x21 / 0x23 - 0x5B / 0x5D - 0x7E / non-ascii
// mlb-escaped-nl = escape ws newline *( wschar / newline )
// non-ascii = 0x80-D7FF / 0xE000-10FFFF
fn void? Parser.mlb_content(&self, DString *buf)
{
	// mlb-content = mlb-char / newline / mlb-escaped-nl
	char c;
	while LOOP: (1)
	{
		c = self.peek();

		// mlb-unescaped = wschar / 0x21 / 0x23 - 0x5B / 0x5D - 0x7E
		if (is_ws(c) || c == 0x21 || (c >= 0x23 && c <= 0x5B) || (c >= 0x5D && c <= 0x7E)) {

			buf.append_char(self.advance()!);
			continue;
		}
		// mlb-unescaped = non-ascii
		else if (is_unicode(c))
		{
			Char32 codepoint = self.scan_unicode()!;
			if (!is_non_ascii(codepoint)) return INVALID_NON_ASCII?;
			buf.append_char32(codepoint);
			continue;
		}

		// newline
		if (is_lf(c))
		{
			buf.append_char(self.advance()!);
			continue;
		}
		else if (is_cr(c))
		{
			buf.append_char(self.advance()!);
			if (!is_lf(self.peek())) return INVALID_NEWLINE?;
			buf.append_char(self.advance()!);
			continue;
		}

		// mlb-char = escaped
		// mlb-escaped-nl = escape ws newline *( wschar / newline )
		if (self.must(ESCAPE))
		{
			if (escape_seq_char(self.peek()))
			{
				char u;
				usz n, start;

				buf.append_char(ESCAPE);

				u = self.advance()!;
				buf.append_char(u);

				switch (u)
				{
					case 0x75: n = 4; // \u
					case 0x55: n = 8; // \U
					default: continue;
				}

				start = self.current;
				for (usz i = 0; i < n; i++)
				{
					if (self.peek().is_xdigit())
					{
						buf.append_char(self.advance()!);
					}
					else
					{
						self.error("invalid escaped unicode sequence");
						return parser::INVALID_ESCAPE_UNICODE?;
					}
				}

				validate_unicode(self.s[start:n])!;

			}
			else
			{
				// non-escaped-terminal \ must be the last
				// non-whitespace character
				while (is_ws(self.peek())) self.advance()!;
				if (!is_lf(self.peek()) && !is_cr(self.peek())) return INVALID_LINE_ENDING_BACKSLASH?;
				while (is_ws(self.peek()) || is_lf(self.peek()) || is_cr(self.peek()))
				{
					if (is_cr(self.peek()))
					{
						self.advance()!;
						if (!is_lf(self.peek())) return INVALID_NEWLINE?;
					}
					self.advance()!;
				}

			}

			continue;
		}

		if (c == '"') {
			break LOOP;;
		}
		else
		{
			return INVALID_STRING?;
		}
	}
}


// basic-string = quotation-mark *basic-char quotation-mark
// basic-char = basic-unescaped / escaped
// basic-unescaped = wschar / 0x21 / 0x23 - 0x5B / 0x5D - 0x-7E / non-ascii
// escaped = escape escape-seq-char
// escape = 0x5C ; \
// escape-seq-char = 0x22 / 0x5C / 0x62 / 0x66 / 0x6E / 0x72 / 0x72 / unicode??
// non-ascii = 0x80-D7FF / 0xE000-10FFFF
fn void? Parser.basic_string(&self)
{
	// beginning quote is already consumed.

	while LOOP: (1)
	{
		// basic-unescaped = wschar / 0x21 / 0x23 - 0x5B / 0x5D - 0x-7E
		if (basic_unescaped(self.peek()))
		{
			self.advance()!;
			continue;
		}

		// basic-unescaped = non-ascii
		if (is_unicode(self.peek()))
		{
			Char32 codepoint = self.scan_unicode()!;
			if (!is_non_ascii(codepoint)) return INVALID_NON_ASCII?;
			continue;
		}

		// escaped = escape escape-seq-char
		if (self.must(ESCAPE))
		{
			if (escape_seq_char(self.peek()))
			{
				char u;
				usz n, start;

				u = self.advance()!;
				switch (u)
				{
					case 0x75: n = 4;
					case 0x55: n = 8;
					default: continue;
				}

				start = self.current;
				for (usz i = 0; i < n; i++)
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

				validate_unicode(self.s[start:n])!;

				continue;
			}
			else
			{
				self.error("invalid escape sequence");
				return parser::INVALID_ESCAPE_SEQUENCE?;
			}
		}

		if (self.must('"')) break LOOP;

		self.error("missing closing quote \"");
		return parser::UNCLOSED_QUOTE?;
	}
}

// ml-literal-string = ml-literal-string delim [ newline ] ml-literal-body
//			ml-literal-string-delim
// ml-literal-string-delim = 3apostrophe
// ml-literal-body = "mll-content *( mll-quotes 1*mll-content ) [ mll-quotes ]
fn Object*? Parser.ml_literal_string(&self) => @pool()
{
	// ml-literal-string-delim has been read at this point.

	DString buf;
	buf.tinit(16);

	// [ newline ]
	if (is_lf(self.peek()))
	{
		self.advance()!;
	}
	else if (is_cr(self.peek()))
	{
		self.advance()!;
		if (!is_lf(self.peek())) return INVALID_NEWLINE?;
		self.advance()!;
	}

	// ml-literal-body
	while LOOP: (1)
	{
		self.mll_content(&buf)!;

		// maximum much for quotes, but cannot have more than 5
		// terminal quotes
		int len = 0;
		while (!self.at_end() && self.must('\''))
		{
			buf.append_char('\'');
			len++;
		}
		switch
		{
			case len > 5:
				self.error("terminal apostrophe sequence is invalid; there are too many..");
				return parser::INVALID_TERMINAL_QUOTES?;
			case len >= 3:
				break LOOP;
			default:
				if (self.at_end()) return parser::UNCLOSED_MULTILINE?;
		}
	}

	// must have at least 3 chars (''') in smallest ml string
	if (buf.len() < 3)
	{
		self.error("multi-line string is not long enough; did add three apostrophes on both sides?");
		return parser::MULTILINE_STRING_TOO_SHORT?;
	}

	return object::new_string(buf.str_view().strip_end(`'''`), self.allocator);
}

// mll-content = mll-char / newline
// mll-char = 0x09 / 0x20 - 0x26 / 0x28 - 0x7E / non-ascii
// mll-quotes = 1*2apstrophe
// non-ascii = 0x80-D7FF / 0xE000-10FFFF
fn void? Parser.mll_content(&self, DString *buf)
{
	// mll-content = mll-char / newline
	char c;
	while LOOP: (1)
	{
		c = self.peek();

		// mll-char
		if (c == 0x09 || (c >= 0x20 && c <= 0x26) || (c >= 0x28 && c <= 0x7E))
		{
			buf.append_char(self.advance()!);
			continue;
		}
		else if (is_unicode(c))
		{
			Char32 codepoint = self.scan_unicode()!;
			if (!is_non_ascii(codepoint)) return INVALID_NON_ASCII?;
			buf.append_char32(codepoint);
			continue;
		}
		else if (is_lf(c))
		{
			buf.append_char(self.advance()!);
			continue;
		}
		else if (is_cr(c))
		{
			buf.append_char(self.advance()!);
			if (!is_lf(self.peek())) return INVALID_NEWLINE?;
			buf.append_char(self.advance()!);
			continue;
		}

		else if (c == '\'') {
			break LOOP;;
		}
		else
		{
			return INVALID_LITERAL?;
		}
	}
}

// literal-string = apostrophe *literal-char apostrophe
// literal-char = 0x09 / 0x20 - 0x26 / 0x28 - 0x7E / non-ascii
// non-ascii = 0x80-D7FF / 0xE000-10FFFF
fn void? Parser.literal_string(&self)
{
	// beginning apostrophe is already consumed.
	char c;

	while (1)
	{
		c = self.peek();

		if (literal_char(c))
		{
			self.advance()!;
		}
		else if (is_unicode(c))
		{
			Char32 codepoint = self.scan_unicode()!;
			if (!is_non_ascii(codepoint)) return INVALID_NON_ASCII?;
		} else {
			if (!self.must('\''))
			{
				self.error("missing closing apostrophe '");
				return parser::UNCLOSED_QUOTE?;
			}
			return;
		}
	}
}

fn Char32? Parser.scan_unicode(&self)
{
	usz len = math::min(4, (int)(self.s.len - self.current));
	Char32 codepoint = conv::utf8_to_char32(&self.s[self.current], &len)!;
	while (len--) self.advance()!;
	return codepoint;
}

<*
 Check if top two bits are set
 With 0xc0 (b11_00_00_00) we check if it is a starting byte for a multi-byte utf8 sequence
 0b10_ would be continuation byte
 0b0*_ is a regular ASCII
*>
fn bool is_unicode(char c) @inline => (c & 0xc0) == 0xc0;

<*
 scalar-unicode = 0x0000-D7FF / 0xE000-10FFFF
*>
fn bool is_scalar_unicode(Char32 u) @inline => u <= 0xD7FF || (u >= 0xE000 && u <= 0x10FFFF);

<*
 non-ascii = 0x80-D7FF / 0xE000-10FFFF
*>
fn bool is_non_ascii(Char32 u) @inline => u >= 0x80 && is_scalar_unicode(u);

<*
 Validate escaped (encoded) unicode values (\u and \U).
*>
fn void? validate_unicode(String hex) => @pool()
{
	// Decode from hex
	char[] decoded = hex::tdecode(hex)!;

	// Trim any leading zeros
	while (decoded.len && decoded[0] == 0) decoded = decoded[1 .. ];

	// Convert to unicode (uint)
	usz nbytes = decoded.len;
	Char32 code_point = conv::utf8_to_char32(decoded, &nbytes)!;

	// Check that codepoint is a scalar unicode
	if (!is_scalar_unicode(code_point)) return parser::INVALID_SCALAR_UNICODE?;
}
