module toml::lexer;

import std::io; // FIXME: for debugging only

enum TokenType
{
	EMPTY,
	IDENTIFIER,
	STRING,
	INTEGER,
	FLOAT,
	BOOLEAN,
	DATETIME,
	COMMENT,
	EQUALS,
	COMMA,
	SQUAREOPEN,
	SQUARECLOSE,
	ARRAYOPEN, // [[
	ARRAYCLOSE, // ]]
	CURLYOPEN,
	CURLYCLOSE,
	NEWLINE,
	EOF,
	ERROR,
}

struct Token
{
	TokenType type;
	union {
		String s;
		long int64;
		double fp64;
		bool b;
	}
	usz lineno;
	usz column;
}

struct Lexer
{
	String input;
	usz pos;
	usz lineno;
	usz column;
}

fn Lexer* Lexer.init(&lexer, String input)
{
	*lexer = { .input = input, .pos = 0, .lineno = 1, .column = 1 };
	return lexer;
}

//
// Lexer: Character advancement and peeking
//

fn char Lexer.current_char(&self) => self.pos < self.input.len ? self.input[self.pos] : 0;
fn char Lexer.next_char(&self) => self.pos + 1 < self.input.len ? self.input[self.pos+1] : 0;
fn bool Lexer.is_eof(&self) => self.pos >= self.input.len;

fn void Lexer.advance(&lexer)
{
	if (lexer.is_eof()) return;

	char current = lexer.input[lexer.pos];

	// Advance position
	lexer.pos += 1;

	// Track line and column numbers
	if (current == '\n')
	{
		lexer.lineno += 1;
		lexer.column = 0; // Reset column at new line
	}
	else
	{
		lexer.column += 1;
	}
}


//
// Lexer: Utility functions
//

fn void Lexer.skip_whitespace_and_comments(&lexer)
{
	char c;
	while (!lexer.is_eof())
	{
		c = lexer.current_char();
		if (c == ' ' || c == '\t' || c == '\r')
		{
			lexer.advance();
		}
		else if (c == '#')
		{
			while (!lexer.is_eof() && lexer.current_char() != '\n')
			{
				lexer.advance();
			}
		}
		else
		{
			break;
		}
	}
}

fn bool is_whitespace(char c) => c == 0x20 || c == 0x09;
fn bool is_newline(char c) => c == 0x0A || c == 0x0D;
fn bool is_digit(char c) => c >= '0' && c <= '9';
fn bool non_ascii(char c) => c >= 0x80;
fn bool non_eol(char c) => c == 0x09 || (c >= 0x20 && c <= 0x7F) || non_ascii(c);
fn bool is_bare_key(char c) => c.is_alpha() || c.is_digit() || c == '-' || c == '_';

macro Token Lexer.issue_token(&lexer, TokenType type)
{
	return {
		 .type =type,
		 .lineno = lexer.lineno,
		 .column = lexer.column
		};
}


//
// Lexer: Token scanning
//

fn Token Lexer.scan_identifier(&lexer) => @pool()
{
	Token token = lexer.issue_token(EMPTY);
	usz start = lexer.pos;
	char c = lexer.current_char();

	// Accept bare key chars
	while (is_bare_key(c) && !lexer.is_eof())
	{
		lexer.advance();
		c = lexer.current_char();
	}

	token.type = IDENTIFIER;
	token.s = lexer.input[start .. lexer.pos - 1];
	return token;
}

// @FIXME: how to handle memory allocations? See DString
// @FIXME: does not handle multiline strings
fn Token Lexer.scan_string(&lexer)
{
	Token token = lexer.issue_token(STRING);
	DString buf = dstring::temp();

	char quote_char = lexer.current_char();
	lexer.advance();

	char c = lexer.current_char();
	while (c != quote_char && !lexer.is_eof())
	{
		// Handle escape sequences for quoted strings
		if (quote_char == '"' && c == '\\')
		{
			lexer.advance();
			c = lexer.current_char();
			switch (c)
			{
			case 'n' : buf.append_char('\n');
			case 't' : buf.append_char('\t');
			case '"' : buf.append_char('"');
			case '\\': buf.append_char('\\');
			default  : buf.append_char(c);
			}
		}
		else
		{
			buf.append_char(c);
		}
		lexer.advance();
		c = lexer.current_char();
	}
	lexer.advance(); // Skip closing quote
	token.s = buf.str_view();
	return token;
}

alias IsValidChar @local = fn bool(char);

// Scans for a number (integer, float) [or datetime]
fn Token Lexer.scan_number(&lexer) => @pool()
{
	Token token = lexer.issue_token(INTEGER);
	DString buf = dstring::temp();

	usz start = lexer.pos;
	char c = lexer.current_char();

	// Optional leading sign
	if (c == '-' || c == '+')
	{
		buf.append_char(c);
		lexer.advance();
		c = lexer.current_char();
	}

	// Check for hex, bin, oct prefix (0x, 0b, 0o) after leading zero
	if (c == '0')
	{
		buf.append_char(c);
		lexer.advance();
		c = lexer.current_char();

		IsValidChar is_valid_char;
		switch (c)
		{
		case 'x':
		case 'X':
			is_valid_char = &ascii::is_xdigit;
		case 'b':
		case 'B':
			is_valid_char = &ascii::is_bdigit;
		case 'o':
		case 'O':
			is_valid_char = &ascii::is_odigit;
		default:
			// TODO: report error for invalid sequence
			unreachable("scan_number: faulty integer with 0 prefix");
		}

		buf.append_char(c);
		lexer.advance();
		c = lexer.current_char();

		// Accept digits and underscores
		while ((is_valid_char(c) || c == '_') && !lexer.is_eof())
		{
			if (c != '_') buf.append_char(c);
			lexer.advance();
			c = lexer.current_char();
		}

		token.type = INTEGER;
		token.int64 = buf.str_view().to_int()!!; // TODO: Return error?
		return token;
	}
	else if (c == 'n' || c == 'i')
	{
		// Read either "nan" or "inf"
		for (usz i = 0; i < 3 && !lexer.is_eof(); i++)
		{
			buf.append_char(c);
			lexer.advance();
			c = lexer.current_char();
		}

		// Fix for String.to_double() in C3 stdlib:
		if (buf.str_view()[^3..] == "inf") buf.append_chars("inity");

		// Return parsed float
		token.type = FLOAT;
		token.fp64 = buf.str_view().to_double()!!; // TODO: handle error?
		return token;
	}

	// Read integer
	while ((is_digit(c) || c == '_') && !lexer.is_eof())
	{
		if (c != '_') buf.append_char(c);
		lexer.advance();
		c = lexer.current_char();
	}

	switch (c)
	{
		case '.':
		case 'e':
		case 'E':
			buf.append_char(c);
			lexer.advance();
			c = lexer.current_char();

			// read float
			while ((is_digit(c) || @ok("_eE.-+".index_of_char(c))) && !lexer.is_eof())
			{
				if (c != '_') buf.append_char(c);
				lexer.advance();
				c = lexer.current_char();
			}

			token.type = FLOAT;
			token.fp64 = buf.str_view().to_double()!!; // TODO: handle error?
			return token;

		case 't':
		case 'T':
		case '-':
		case ':':
			buf.append_char(c);
			lexer.advance();
			c = lexer.current_char();

			// read datetime
			while ((is_digit(c) || @ok("-tT:.Z+".index_of_char(c))) && !lexer.is_eof())
			{
				buf.append_char(c);
				lexer.advance();
				c = lexer.current_char();
			}

			token.type = DATETIME;
			token.s = lexer.input[start .. buf.len() - 1];
			return token;
	}

	token.int64 = buf.str_view().to_long()!!;
	return token;
}

fn Token Lexer.scan_comment(&lexer)
{
	Token token = lexer.issue_token(COMMENT);
	usz start = lexer.pos;
	lexer.advance(); // Consume "#"
	char c = lexer.current_char();
	while (!is_newline(c) && !lexer.is_eof()) lexer.advance();
	token.s = lexer.input[start .. lexer.pos - 1];
	return token;
}

// This function is currently not used; the DateTime is Token is parsed in
// scan_number(). We could call this scanning function explicitly from
// scan_number() when we rewind the lexer position.
fn Token Lexer.scan_datetime(&lexer)
{
	Token token = lexer.issue_token(DATETIME);
	usz start = lexer.pos;
	char c = lexer.current_char();

	// DateTime in TOML can contain digits, '-', ':', '.', 'Z', 'T'
	while ((ascii::is_digit(c) ||
		c == '-' || c == '+' ||
		c == 'T' || c == 't' ||
		c == 'Z' || c == 'z' ||
		c == '.' || c == ':') && !lexer.is_eof())
	{
		lexer.advance();
		c = lexer.current_char();
	}

	token.s = lexer.input[start .. lexer.pos - 1];
	return token;
}

fn Token Lexer.scan_punctuation(&lexer)
{
	char c = lexer.current_char();
	Token token = lexer.issue_token(EMPTY);

	// Lookahead for two-character tokens ([[ or ]])
	if (c == '[' && lexer.next_char() == '[')
	{
		token.type = ARRAYOPEN;;
		lexer.advance(); lexer.advance();
	}
	else if (c == ']' && lexer.next_char() == ']')
	{
		token.type = ARRAYCLOSE;
		lexer.advance(); lexer.advance();
	}
	else
	{
		// Single-character punctuation
		switch (c)
		{
		case '=': token.type = EQUALS;
		case ',': token.type = COMMA;
		case '[': token.type = SQUAREOPEN;
		case ']': token.type = SQUARECLOSE;
		case '{': token.type = CURLYOPEN;
		case '}': token.type = CURLYCLOSE;
		default : token.type = ERROR;
		}
		lexer.advance();
	}
	return token;
}

//
// Lexer: Main lexing loop
//

fn Token Lexer.next_token(&lexer)
{
	lexer.skip_whitespace_and_comments();

	if (lexer.is_eof())
	{
		return lexer.issue_token(EOF);
	}

	char c = lexer.current_char();

	// Strings (basic or literal)
	if (c == '"' || c == '\'')
	{
		return lexer.scan_string();
	}

	// Numbers or DateTime
	if (is_digit(c) || ((c == '-' || c == '+') && is_digit(lexer.next_char())))
	{
		return lexer.scan_number();
	}

	// Identifiers (bare keys, true, false, datetime, nan, infinity)
	if (is_bare_key(c))
	{
		Token token = lexer.scan_identifier();

		// If identifier matches 'true', 'false', 'nan', 'infinity',
		// reclassify token type
		if (token.s.starts_with("true"))
		{
			token.type = BOOLEAN;
			token.b = true;
		}
		else if (token.s.starts_with("false"))
		{
			token.type = BOOLEAN;
			token.b = false;
		}
		else if (token.s.starts_with("nan"))
		{
			token.type = FLOAT;
			token.fp64 = token.s.to_double()!!; // TODO: Return error?
		}
		else if (token.s.starts_with("inf"))
		{
			token.type = FLOAT;
			token.fp64 = double.inf;
		}
		return token;
	}

	io::printn("D");

	// Punctuation and structural tokens
	switch (c)
	{
	case '=':
	case ',':
	case '[':
	case ']':
	case '{':
	case '}':
		return lexer.scan_punctuation();
	case '\n':
		defer lexer.advance();
		return lexer.issue_token(NEWLINE);
	case '#':
		return lexer.scan_comment();
	default:
		// Unexpected/illegal character
		// TODO: lexer.report_error()
		io::printfn(" -- boom -- ");
		defer lexer.advance();
		return lexer.issue_token(ERROR);
	}
}
