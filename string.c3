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
fn Object*! Parser.string(&self)
{
	self.start = self.current;

	char quote = self.read_byte()!; // first quote

	if (self.must(quote)) { // second quote

		// if no third quote is around, then return
		if (!self.must(quote)) return object::new_string("", self.allocator);

		if (quote == '"')
		{
			return self.ml_basic_string()!;
		}
		else if (quote == '\'')
		{
			// TODO
			// return self.ml_literal_string()!;
		}

		io::printfn("parser error: invalid quote: %c", quote);
		return object::new_string("", self.allocator);
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
			io::printfn("parser error: invalid quote: %c", quote);
		}

		return object::new_string(self.text()[1..^2], self.allocator);
	}
}

// ml-basic-string = ml-basic-string-delim [ newline ] ml-basic-body
// 			ml-basic-string-delim
// ml-basic-string-delim = 3quotation-mark
// ml-basic-body = *mlb-content *( mlb-quotes 1*mlb-content ) [ mlb-quotes ]
// mlb-quotes = 1*2quotation-mark
fn Object*! Parser.ml_basic_string(&self)
{
	// ml-basic-string-delim has been read at this point.

	DString d;
	d.new_init(16, self.allocator);
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
				continue;
			case i >= 3 && i < 6:
				break LOOP;
			case i >= 6:
				io::printn("parser error: too many terminal quotes");
				break LOOP;
		}
	}

	// must have at least 6 chars (""""""") in smallest ml string
	if (d.len() <= 3)
	{
		io::printn("parser error: not enough chars in multiline string");
		return object::new_string("", self.allocator);
	}

	return object::new_string(d.str_view().strip_end(`"""`), self.allocator);
}

// mlb-content = mlb-char / newline / mlb-escaped-nl
// mlb-char = mlb-unescaped / escaped 
// mlb-unescaped = wschar / 0x21 / 0x23 - 0x5B / 0x5D - 0x7E / non-ascii
// mlb-escaped-nl = escape ws newline *( wschar / newline )
// TODO: non-ascii
fn void! Parser.mlb_content(&self, DString *d)
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
				d.append_char(ESCAPE);
				d.append_char(self.advance()!);
				continue;
			}
			else
			{
				self.skip_ws()!;
				while (is_newline(self.peek())) self.advance()!;
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
// TODO: escaped unicode
fn void! Parser.basic_string(&self)
{
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
				self.advance()!;
				continue;
			}
			else
			{
				io::printf("parser error: invalid escape sequence");
			}
		}

		if (!self.must('"')) 
		{
			io::printf("parser error: missing terminating quote");
		}

		break LOOP;
	}
}

// literal-string = apostrophe *literal-char apostrophe
// literal-char = 0x09 / 0x20 - 0x26 / 0x28 - 0x7E / non-ascii
// TODO: non-ascii
fn void! Parser.literal_string(&self)
{
	while (1)
	{
		if (!literal_char(self.peek()))
		{
			if (!self.must('\'')) 
			{
				io::printf("parser error: missing terminating quote");
			}
			return;
		}
		self.advance()!;	
	}
}

