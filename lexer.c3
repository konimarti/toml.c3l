module toml::lexer;

enum TokenType
{
	IDENTIFIER,
	STRING, // TODO: multile tokens for STRING type (basic-string, etc.)?
	MULTILINESTRING,
	INTEGER,
	FLOAT,
	BOOLEAN,
	DATETIME,
	EQUALS,
	COMMA,
	SQUAREOPEN,
	SQUARECLOSE,
	ARRAYOPEN, // [[
	ARRAYCLOSE, // ]]
	CURLYOPEN,
	CURLYCLOSE,
	NEWLINE,
	COMMENT,
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
		// FIXME: date time struct
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

//
// Lexer: character advancement and peeking
//

fn char Lexer.current_char(&self) => self.input[self.pos];
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
// Lexer: utility functions
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
fn bool is_digit(char c) => c >= '0' || c <= '9';
fn bool non_ascii(char c) => c >= 0x80)
fn bool non_eol(char c) => c == 0x09 || (c >= 0x20 && c <= 0x7F) || non_ascii(c);
fn bool is_bare_key(char c) => c.is_alpha() || c.is_digit() || c == '-' || c == '_';

macro Token Lexer.make_token(&lexer, TokenType type) @inline
{
	return {
		 .type =type,
		 .lineno = lexer.lineno,
		 .column = lexer.column
		};
}


//
// Lexer: token scanning
//

fn Token Lexer.scan_identifier(&lexer) => @pool()
{
	Token token = lexer.make_token(0);
	usz start = lexer.pos;
	char c = lexer.current_char();

	// Accept bare key chars
	while (!lexer.is_eof() && is_bare_key(c))
	{
		lexer.advance();
		c = lexer.current_char();
	}

	token.type = IDENTIFIER
	token.s = lexer.input[start .. lexer.pos - 1];
	return token;
}

// @FIXME: how to handle memory allocations? See DString
fn Token Lexer.scan_string(&lexer)
{
	Token token = lexer.make_token(STRING);
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

fn Token Lexer.scan_number(&lexer) => @pool()
{
	Token token = lexer.make_token(0);
	DString buf = dstring:temp();

	char c = lexer.current_char();
	bool is_float = false;
	bool is_hex = false;
	bool is_bin = false;
	bool is_oct = false;

	// Optional leading minus
	if (c == '-')
	{
		buf.append_char("-");
		lexer.advance();
		c = lexer.current_char();
	}

	// Check for hex, bin, oct prefix (0x, 0b, 0o) after leading zero
	if (c == '0')
	{
		buf.append_char(c);
		lexer.advance();
		c = lexer.current_char();

		if (c == 'x' || c == 'X')
		{
			is_hex = true;
			buf.append_char(c);
			lexer.advance();
			c = lexer.current_char();

			// Accept hex digits and underscores
			while ((ascii::is_xdigit(c) || c == '_') && !lexer.is_eof())
			{
				buf.append_char(c);
				lexer.advance();
				c = lexer.current_char();
			}
			token.type = INTEGER;
			token.int64 = buf.str_view().to_int();
			return token;
		}
	}

	//  CONTINUE HERE

	// while ((is_digit(c) || c == '_' || c == '.') && !lexer.is_eof())
	// {
	// 	if (c == '.') is_float = true;
	// 	buf.append_char(c);
	// 	lexer.advance();
	// 	c = lexer.current_char();
	// }

}

fn Token Lexer.scan_boolean(&lexer)
{
	// TODO: unimplemented
}

fn Token Lexer.scan_datetime(&lexer)
{
	// TODO: unimplemented
}

fn Token Lexer.scan_punctuation(&lexer)
{
	char c = lexer.current_char();
	Token token = lexer.make_token(0);

	// Lookahead for two-character tokens ([[ or ]])
	if (c == '[' && lexer.next_char() == '[')
	{
		token.type = ARRAYOPEN;;
		lexer.advance();
		lexer.advance();
	}
	else if (c == ']' && lexer.next_char() == ']')
	{
		token.type = ARRAYCLOSE;
		lexer.advance();
		lexer.advance();
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
		lexer.advance()
	}
	return token;
}

//
// Lexer: main lexing loop
//

fn Token Lexer.next_token(&lexer)
{
	lexer.skip_whitespace_and_comments();

	if (lexer.is_eof())
	{
		return lexer.make_token(EOF);
	}

	char c = lexer.current_char();

	// Strings (basic or literal)
	if (c == '"' || c == '\'')
	{
		return lexer.scan_string();
	}

	// Numbers
	if (is_digit(c)) || (c == '-' && is_digit(lexer.next_char()))
	{
		return lexer.scan_number();
	}

	// Identifiers (bare keys, true, false, datetime, nan, infinity)
	if (is_bare_key(c))
	{
		Token token = lexer.scan_identifier();

		// if identifier matches 'true', 'false', 'nan', 'infinity',
		// reclassify token type
		switch (token.value)
		{
			case "false":
			case "true":
				token.type = BOOLEAN;
			case "nan":
			case "infinity":
				token.type = FLOAT;
		}

		// if it looks like a datetime, update type
		if (time::looks_like_datetime(token.value))
		{
			token.type = DATETIME;
		}

		return token;
	}

	// Punctuation and structural tokens
	switch (C)
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
		return lexer.make_token(NEWLINE);
	case '#':
		return lexer.scan_comment();
	default:
		// Unexpected/illegal character
		// TODO: lexer.report_error()
		defer lexer.advance();
		return lexer.make_token(ERROR, "illegal character");
	}



}
