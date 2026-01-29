module toml::parser;

import std::ascii;
import std::collections::object;

import std::io; // debugging
import std::math;

import toml::time;

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
	bool has_sign;
}

fn Object*? Parser.number_or_datetime(&self) => @pool()
{
	Token tok = {
		.type = TokenType.INTEGER,
		.s = dstring::temp(),
		.has_sign = self.peek() == '+' || self.peek() == '-'
	};

	self.integer(&tok)!;

	String str = tok.s.str_view();

	if (tok.type == INTEGER || tok.type == FLOAT)
	{
		// Leading zeros
		if (tok.has_sign)
		{
			if (str.len >= 3 && str[1] == '0' && ascii::is_digit(str[2]))
			{
				return INVALID_LEADING_ZERO~;
			}
		}
		else
		{
			if (str.len >= 2 && str[0] == '0' && ascii::is_digit(str[1]))
			{
				return INVALID_LEADING_ZERO~;
			}
		}
	}

	switch (tok.type)
	{
		case INTEGER:
			return object::new_int(str.to_int128()!, self.allocator);
		case FLOAT:
			return object::new_float(str.to_double()!, self.allocator);
		case DATETIME:
			if (try dt = toml::time::parse(str) && dt.valid_ranges())
			{
				return object::new_string(str, self.allocator);
			}
			return INVALID_DATETIME~;
		default:
			self.report_error("invalid token type in parsing a number of a datetime.");
			return parser::INVALID_TOKEN_TYPE~;
	}
}

<*
 Checks if the char is surrounded by two appropriate digits; applies to '_' and
 '.'
*>
fn bool Parser.valid_surround(&self, char c, Accept is_valid = &ascii::is_digit) @local
{
	String str @noinit;
	usz i, n;

	str = self.s;
	i = self.current;
	n = str.len;

	assert(str[i] == c);

	if (i < 1 || i + 1 >= n) return false;
	if (is_valid(str[i - 1]) && is_valid(str[i + 1])) return true;
	return false;
}

fn void? Parser.integer(&self, Token *tok)
{
	switch (self.peek())
	{
		case '_':
			if (!self.valid_surround(self.peek())) return INVALID_UNDERSCORE~;
			self.advance()!;
			self.integer(tok)!;
		case '+':
		case '0'..'9':
			tok.s.append_char(self.advance()!);
			self.integer(tok)!;
		case 'x':
			if (tok.has_sign) return UNSIGNED_WITH_SIGN~;
			tok.s.append_char(self.advance()!);
			self.hex_int(tok.s)!;
		case 'o':
			if (tok.has_sign) return UNSIGNED_WITH_SIGN~;
			tok.s.append_char(self.advance()!);
			self.oct_int(tok.s)!;
		case 'b':
			if (tok.has_sign) return UNSIGNED_WITH_SIGN~;
			tok.s.append_char(self.advance()!);
			self.bin_int(tok.s)!;
		case 'n':
		case 'i':
		case 'e':
		case 'E':
		case '.':
			self.parse_float(tok)!;
		case 't':
		case 'T':
		case ':':
			self.date_time(tok)!;
		case '-':
			// Either int or date_time
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
fn void? Parser.parse_float(&self, Token *tok)
{
	tok.type = FLOAT;

	// at this point, dec-int part already parsed in tok.s
	switch (self.peek())
	{
		case '_':
			if (!self.valid_surround(self.peek())) return INVALID_UNDERSCORE~;
			self.advance()!;
		case '.':
		case '+':
		case '-':
		case 'e':
		case 'E':
		case '0'..'9':
			if (self.peek() == '.' && !self.valid_surround(self.peek())) return INVALID_UNDERSCORE~;
			tok.s.append_char(self.advance()!);
		case 'n':
			if (self.match("nan")!) tok.s.append_string("nan");
			return;
		case 'i':
			if (self.match("inf")!) tok.s.append_string("infinity");
			return;
		default:
			return;
	}
	self.parse_float(tok)!;
}

fn void? Parser.date_time(&self, Token *tok)
{
	tok.type = DATETIME;
	switch (self.peek())
	{
		case '0'..'9':
		case 't':
		case 'T':
		case 'z':
		case 'Z':
		case ' ':
		case '.':
		case ':':
		case '+':
		case '-':
			tok.s.append_char(self.advance()!);
			self.date_time(tok)!;
		default:
			return;
	}
}

alias Accept = fn bool(char);

fn void? Parser.parse_int(&self, DString s, Accept accept)
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
				if (!self.valid_surround(c, accept)) return INVALID_UNDERSCORE~;
				self.advance()!;
			default:
				break LOOP;
		}
	}
}

fn void? Parser.hex_int(&self, DString s) => self.parse_int(s, &ascii::is_xdigit)!;
fn void? Parser.oct_int(&self, DString s) => self.parse_int(s, &ascii::is_odigit)!;
fn void? Parser.bin_int(&self, DString s) => self.parse_int(s, &ascii::is_bdigit)!;

