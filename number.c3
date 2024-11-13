module toml::parser;

import std::ascii;
import std::collections::object;

// integer = dec-int / hex-int / oct-int / bin-int
// minus = 0x2D
// plus = 0x2B
// underscore = 0x5F
// hex-prefix = 0x
// oct-prefix = 0o
// bin-prefix = 0b
//
// dec-int = [ minus / plus ] unsigned-dec-int
// unsigned-dec-int = DIGIT / digit1-9 1*( DIGIT / underscore DIGIT )
//
// hex-int = hex-prefix HEXDIG *( HEXDIG / underscore HEXDIG )
// oct-int = oct-prefix digit0-7 *( digit0-7 / underscore digit0-7 )
// bin-int = bin-prefix digit0-1 *( digit0-1 / underscore digit0-1 )
//
// float = float-int-part ( exp / frac [ exp ] )
// float = special-float
//
// float-int-part = dec-int
// frac = decimal-point zero-prefixable-int
// decimal-point = 0x2E ; .
// zero-prefixable-int = DIGIT *( DIGIT / underscore DIGIT )
//
// exp = "e" float-exp-par
// float-exp-part = [ minux / plus ] zero-prefixable-int
//
// special-float = [ minus / plus ] ( inf / nan )

enum TokenType
{
	INTEGER,
	FLOAT,
	DATETIME
}

struct Token
{
	TokenType type;
	DString s;
}

fn Object*! Parser.number_or_datetime(&self)
{
	Token tok;

	tok.s.new_init(16, self.allocator);
	defer tok.s.free();

	self.integer(&tok)!;

	String str = tok.s.str_view();
	switch (tok.type)
	{
		case INTEGER:
			return object::new_int(str.to_int()!, self.allocator);
		case FLOAT:
			return object::new_float(str.to_double()!, self.allocator);
		case DATETIME:
			return object::new_string(str, self.allocator);
		default:
			self.error("invalid token type in parsing a number of a datetime.");
			return ParserError.INVALID_TOKEN_TYPE?;
	}
}

fn void! Parser.integer(&self, Token *tok)
{
	tok.type = TokenType.INTEGER;
	switch (self.peek())
	{
		case '_':
			self.advance()!;
			self.integer(tok)!;
		case '+':
		case '0'..'9':
			tok.s.append_char(self.advance()!);
			self.integer(tok)!;
		case 'x':
		case 'X':
			tok.s.append_char(self.advance()!);
			self.hex_int(tok.s)!;
		case 'o':
		case 'O':
			tok.s.append_char(self.advance()!);
			self.oct_int(tok.s)!;
		case 'b':
		case 'B':
			tok.s.append_char(self.advance()!);
			self.bin_int(tok.s)!;
		case 'n':
		case 'i':
		case 'e':
		case '.':
			self.parse_float(tok)!;
		case 't':
		case 'T':
		case ':':
			self.date_time(tok)!;
		case '-':
			// can be either int or date_time
			tok.s.append_char(self.advance()!);
			if (tok.s.len() > 4)
			{
				self.date_time(tok)!;
			}
			else
			{
				self.integer(tok)!;
			}
	}

	return;
}

// float = float-int-part ( exp / frac [ exp ] )
// float = special-float
//
// float-int-part = dec-int
// frac = decimal-point zero-prefixable-int
// decimal-point = 0x2E ; .
// zero-prefixable-int = DIGIT *( DIGIT / underscore DIGIT )
//
// exp = "e" float-exp-par
// float-exp-part = [ minux / plus ] zero-prefixable-int
//
// special-float = [ minus / plus ] ( inf / nan )
//
fn void! Parser.parse_float(&self, Token *tok)
{
	tok.type = FLOAT;

	// at this point, dec-int part already parsed in tok.s
	switch (self.peek())
	{
		case '_':
			self.advance()!;
		case '+':
		case '-':
		case 'e':
		case '.':
		case '0'..'9':
			tok.s.append_char(self.advance()!);
		case 'n':
			if (self.match("nan")!) tok.s.append_chars("nan");
			return;
		case 'i':
			if (self.match("inf")!) tok.s.append_chars("infinity");
			return;
		default:
			return;
	}
	self.parse_float(tok)!;
}

fn void! Parser.date_time(&self, Token *tok)
{
	tok.type = DATETIME;
	switch (self.peek())
	{
		case '0'..'9':
		case 't':
		case 'T':
		case ':':
		case '+':
		case '-':
			tok.s.append_char(self.advance()!);
			self.date_time(tok)!;
		default:
			return;
	}
}

def Accept = fn bool(char);

fn void! Parser.parse_int(&self, DString s, Accept accept)
{
	char c;
	while LOOP: (1)
	{
		c = self.peek();
		switch
		{
			case accept(c): 
				s.append_char(self.advance()!);
			case c == '_':
				self.advance()!;
			default:
				break LOOP;
		}
	}
}

fn void! Parser.hex_int(&self, DString s) => self.parse_int(s, &ascii::is_xdigit)!;
fn void! Parser.oct_int(&self, DString s) => self.parse_int(s, &ascii::is_odigit)!;
fn void! Parser.bin_int(&self, DString s) => self.parse_int(s, &ascii::is_bdigit)!;

