module toml::lexer;

import std::io; // FIXME: for debugging only

enum TokenType
{
	EMPTY,
	IDENTIFIER, // contains also INTEGER, BOOLEAN
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
	ARRAYTABLEOPEN, // [[
	ARRAYTABLECLOSE, // ]]
	CURLYOPEN,
	CURLYCLOSE,
	NEWLINE,
	EOF,
	ERROR,
}

struct Token
{
	TokenType type;
	String value;
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

struct LexerState
{
	usz pos;
	usz lineno;
	usz column;
}

fn LexerState Lexer.save(&lexer) => { lexer.pos, lexer.lineno, lexer.column };
fn Lexer* Lexer.restore(&lexer,  LexerState state)
{
	lexer.pos = state.pos;
	lexer.lineno = state.lineno;
	lexer.column = state.column;
	return lexer;
}
fn String Lexer.text(&lexer, LexerState state) => lexer.input[state.pos .. lexer.pos - 1];

fn void Lexer.report_error(&lexer, String msg)
{
	io::eprintfn("Line: %d, Column: %d -- Error: %s", lexer.lineno, lexer.column, msg);
	// panic(" -- Stopped because of a lexer error --");
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

fn void Lexer.skip_whitespace(&lexer)
{
	char c;
	while (!lexer.is_eof())
	{
		c = lexer.current_char();
		if (c == ' ' || c == '\t' || c == '\r')
		{
			lexer.advance();
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

fn Token Lexer.scan_identifier(&lexer, bool plus_prefix = false) => @pool()
{
	Token token = lexer.issue_token(IDENTIFIER);
	LexerState start_state = lexer.save();
	char c = lexer.current_char();

	if (plus_prefix && c == '+')
	{
		lexer.advance();
		c = lexer.current_char();
	}

	// Accept bare key chars
	while (is_bare_key(c) && !lexer.is_eof())
	{
		lexer.advance();
		c = lexer.current_char();
	}

	token.value = lexer.text(start_state);
	return token;
}

// @FIXME: how to handle memory allocations? See DString
// @FIXME: does not handle multiline strings
fn Token Lexer.scan_string(&lexer)
{
	Token token = lexer.issue_token(STRING);

	char quote_char = lexer.current_char();
	lexer.advance();

	LexerState start_state = lexer.save();

	char c = lexer.current_char();
	while (c != quote_char && !lexer.is_eof())
	{
		// // Handle escape sequences for quoted strings
		// if (quote_char == '"' && c == '\\')
		// {
		// 	lexer.advance();
		// 	c = lexer.current_char();
		// 	switch (c)
		// 	{
		// 	case 'n' : buf.append_char('\n');
		// 	case 't' : buf.append_char('\t');
		// 	case '"' : buf.append_char('"');
		// 	case '\\': buf.append_char('\\');
		// 	default  : buf.append_char(c);
		// 	}
		// }
		// else
		// {
		// 	buf.append_char(c);
		// }
		lexer.advance();
		c = lexer.current_char();
	}

	token.value = lexer.text(start_state);

	lexer.advance(); // Skip closing quote
	return token;
}

alias IsValidChar @local = fn bool(char);

// Scans for a number (integer, float)
fn Token Lexer.scan_number(&lexer) => @pool()
{
	Token token = lexer.issue_token(INTEGER);
	LexerState start_state = lexer.save();

	char c = lexer.current_char();
	bool bare_key = true;

	// Optional leading sign
	if (c == '-' || c == '+')
	{
		lexer.advance();
		c = lexer.current_char();
		if (c == '+') bare_key = false;
	}

	// Check for hex, bin, oct prefix (0x, 0b, 0o) after leading zero
	if (c == '0')
	{
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
			// unreachable("scan_number: faulty integer with 0 prefix");
			io::eprintn("scan_number: faulty integer with 0 prefix");
			lexer.restore(start_state);
			return token; // FIXME: this should be an error value, indicating we haven't scanned a Token yet
		}

		lexer.advance();
		c = lexer.current_char();

		// Accept digits and underscores
		while ((is_valid_char(c) || c == '_') && !lexer.is_eof())
		{
			lexer.advance();
			c = lexer.current_char();
		}

		if (is_bare_key(c))
		{
			if (bare_key)
			{
				lexer.restore(start_state);
				return lexer.scan_identifier();
			}
			else
			{
				lexer.report_error("cannot read bare key");
			}
		}

		token.type = INTEGER;
		token.value = lexer.text(start_state);
		return token;
	}

	// Read integer
	while ((is_digit(c) || c == '_') && !lexer.is_eof())
	{
		lexer.advance();
		c = lexer.current_char();
	}

	switch (c)
	{
		case '.':
		case 'e':
		case 'E':
			// FLOAT
			lexer.advance();
			c = lexer.current_char();

			// read float
			while ((is_digit(c) || @ok("_eE.-+".index_of_char(c))) && !lexer.is_eof())
			{
				lexer.advance();
				c = lexer.current_char();
			}

			token.type = FLOAT;
			token.value = lexer.text(start_state);
			return token;

		case '-':
		case ':':
			// DATETIME
			lexer.restore(start_state);
			return lexer.scan_datetime();
		default:
			// INTEGER
			token.value = lexer.text(start_state);
			return token;
	}
}

fn Token Lexer.scan_comment(&lexer)
{
	Token token = lexer.issue_token(COMMENT);
	LexerState start_state = lexer.save();
	lexer.advance(); // Consume "#"
	char c = lexer.current_char();
	while (non_eol(c) && !lexer.is_eof()) lexer.advance();
	token.value = lexer.text(start_state);
	return token;
}

// This function is currently not used; the DateTime is Token is parsed in
// scan_number(). We could call this scanning function explicitly from
// scan_number() when we rewind the lexer position.
fn Token Lexer.scan_datetime(&lexer)
{
	Token token = lexer.issue_token(DATETIME);
	LexerState start_state = lexer.save();
	char c = lexer.current_char();
	bool bare_key = true;

	// DateTime in TOML can contain digits, '-', ':', '.', 'Z', 'T'
	while ((ascii::is_digit(c) ||
		c == '-' || c == '+' ||
		c == 'T' || c == 't' ||
		c == 'Z' || c == 'z' ||
		c == '.' || c == ':' || c == ' ') && !lexer.is_eof())
	{
		lexer.advance();
		c = lexer.current_char();
		if (c == ' ' && !is_digit(lexer.next_char())) break;
		if (c == '+' || c == '.' || c == ':') bare_key = false;
	}

	if (is_bare_key(c))
	{
		if (bare_key)
		{
			lexer.restore(start_state);
			return lexer.scan_identifier();
		}
		else
		{
			lexer.report_error("failed to scan for datetime");
		}
	}

	// FIXME: DateTime need validation here; otherwise, 2009-09-9999 would
	// be valid

	token.value = lexer.text(start_state);
	return token;
}

fn Token Lexer.scan_punctuation(&lexer)
{
	char c = lexer.current_char();
	Token token = lexer.issue_token(EMPTY);

	// Lookahead for two-character tokens ([[ or ]])
	if (c == '[' && lexer.next_char() == '[')
	{
		token.type = ARRAYTABLEOPEN;;
		lexer.advance(); lexer.advance();
	}
	else if (c == ']' && lexer.next_char() == ']')
	{
		token.type = ARRAYTABLECLOSE;
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
	lexer.skip_whitespace();

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

	// Identifiers (bare keys, true, false, 'nan', 'inf')
	if (is_bare_key(c))
	{
		Token token = lexer.scan_identifier();

		// If identifier matches 'true', 'false', 'nan', 'inf',
		// reclassify token type
		switch (token.value)
		{
		case "true":
			token.type = BOOLEAN;
		case "false":
			token.type = BOOLEAN;
		case "nan":
		case "-nan":
			token.type = FLOAT;
		case "inf":
		case "-inf":
			token.type = FLOAT;
		}
		return token;
	}

	// Special case for '+nan' and '+inf'
	if (c == '+' && (lexer.next_char() == 'n' || lexer.next_char() == 'i'))
	{
		Token token = lexer.scan_identifier(true);

		// If identifier matches '+nan', '+inf', reclassify token type
		switch (token.value)
		{
		case "+nan":
			token.type = FLOAT;
			return token;
		case "+inf":
			token.type = FLOAT;
			return token;
		default:
			lexer.report_error("could not scan value");
		}
	}

	// Punctuation and structural tokens
	switch (c)
	{
	case '=':
	case ',':
	case '[':
	case ']':
	case '{':
	case '}':
	case '.':
		return lexer.scan_punctuation();
	case '\n':
		Token token = lexer.issue_token(NEWLINE);
		lexer.advance();
		return token;
	case '#':
		return lexer.scan_comment();
	default:
		// Unexpected/illegal character
		// TODO: lexer.report_error()
		io::printfn(" -- boom -- ");
		Token token = lexer.issue_token(ERROR);
		lexer.advance();
		return token;
	}
}
