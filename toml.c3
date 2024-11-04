module toml;
import std::io;
import std::collections::object;

fault Errors {
	GENERL_ERROR,
}

/*
fn Object*! parse_string(String s) {
	return parse(ByteReader{}.init(s), allocator::heap());
}

fn Object*! temp_parse_string(String s) {
	return parse(ByteReader{}.init(s), allocator::temp());
}

fn Object*! parse(InStream s, Allocator allocator = allocator::heap()) {
	// TODO
}
*/

// -- implementation follows --

enum TokenType @local
{
	NEWLINE,
	LBRACE,
	RBRACE,
	LBRACKET,
	RBRACKET,
	COMMA,
	PLUS,
	MINUS,
	EXPONENT,
	DOT,
	EQUAL,
	IDENT,
	QSTRING,
	LSTRING,
	UNDERSCORE,
	TRUE,
	FALSE,
	HEX,
	OCT,
	BIN,
	NAN,
	INF,
}

struct Token (Printable)
{
	TokenType type;
	String lexeme;
}

fn usz! Token.to_format(&self, Formatter* f) @dynamic
{
	usz n = f.printf("-- tok: %s", self.type)!;
	if (self.lexeme.len) {
		n += f.printf(" lexeme: %s", self.lexeme)!;
	}
	n += f.printf("\n")!;
	return n;
}

struct Lexer
{
	InStream s;
	Allocator allocator;
	bool unread;
	char current;
}

fn void Lexer.init(&self, InStream s, Allocator allocator)
{
	*self = {s, allocator, false, '\0'};
}

fn Token* Lexer.token(&self, TokenType type)
{
	Token* tok;
	mem::@scoped(self.allocator) {
		tok = mem::new(Token);
	};
	tok.type = type;
	return tok;
}

fn Token* Lexer.token_with_lexeme(&self, TokenType type, String lexeme)
{
	Token *tok = self.token(type);
	tok.lexeme = lexeme;
	return tok;
}


fn char! Lexer.read_byte(&self)
{
	if (self.unread)
	{
		self.unread = false;
		return self.current;
	}
	self.current = self.s.read_byte()!;
	return self.current;
}

fn void Lexer.unread_byte(&self)
{
	self.unread = true; 
}

fn char! Lexer.peek(&self)
{
	if (self.unread)
	{
		return self.current;
	}
	char c = self.read_byte()!;
	self.unread_byte();
	return c;
}

fn void! Lexer.skip_ws(&self)
{
	char c;
	while ((c = self.peek()!) && (c == 0x20 || c == 0x09)) self.read_byte()!;
}


fn DString! Lexer.consume_until(&self, char until)
{
	DString s;
	s.new_init(16, self.allocator);
	char c;
	bool escape;
	do {
		c = self.read_byte()!;
		s.append_char(c);
		if (c == '\\') 
		{
			escape = true;
		}
		else if (escape)
		{
			escape = false;
		}
	} while (c != until || escape);
	return s;
}

macro bool is_ident(char c) {
	return (c.is_digit() || c.is_alpha() || c == '-' || c == '_');
}

macro bool is_valid_hex(String s) {
	foreach (c : s)
	{
		if (c.is_digit() || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f') || c == '_')
		{
			continue;
		}
		else
		{
			return false;
		}
	}
	return true;
}

macro bool is_valid_octal(String s) {
	foreach (c : s)
	{
		if ((c >= '0' && c <= '7') || c == '_')
		{
			continue;
		}
		else
		{
			return false;
		}
	}
	return true;
}

macro bool is_valid_binary(String s) {
	foreach (c : s)
	{
		if ((c >= '0' && c <= '1') || c == '_')
		{
			continue;
		}
		else
		{
			return false;
		}
	}
	return true;
}

macro bool is_valid_int(String s) {
	foreach (c : s)
	{
		if ((c >= '0' && c <= '9') || c == '_')
		{
			continue;
		}
		else
		{
			return false;
		}
	}
	return true;
}

macro bool is_valid_float(String s) {
	foreach (c : s)
	{
		if ((c >= '0' && c <= '9') || c == '_' || c == '.' || c == 'e')
		{
			continue;
		}
		else
		{
			return false;
		}
	}
	return true;
}

fn void! Lexer.consume_ident(&self, DString *s)
{
	char c;
	while (is_ident(c = self.read_byte()!))
	{
		s.append_char(c);
	}
	self.unread_byte();
}

fn Token*! Lexer.next_token(&self)
{
	char c;
	while (1) 
	{
		c = self.read_byte()!;
		switch (c) 
		{
			case 0x20: 
			case 0x09: 
				// skip whitespace
				continue;
			case 0x0D:
				char peek = self.peek()!;
				if (peek == 0x0A)
				{
					self.read_byte()!;
					return self.token(TokenType.NEWLINE);
				}
				else
				{
					// TODO: what to do?
				}
			case 0x0A:
				return self.token(TokenType.NEWLINE);
			case '#':
				self.consume_until(0x0A)!;
			case '.':
				return self.token(TokenType.DOT);
			case '_':
				return self.token(TokenType.UNDERSCORE);
			case '+':
				return self.token(TokenType.PLUS);
			case '-':
				return self.token(TokenType.MINUS);
			case '=':
				return self.token(TokenType.EQUAL);
			case '{':
				return self.token(TokenType.LBRACE);
			case '}':
				return self.token(TokenType.RBRACE);
			case '[':
				return self.token(TokenType.LBRACKET);
			case ']':
				return self.token(TokenType.RBRACKET);
			case ',':
				return self.token(TokenType.COMMA);
			case 'e':
				return self.token(TokenType.EXPONENT);
			case '0':
				char peek = self.peek()!;
				switch (peek) {
					case 'X':
					case 'x':
						// TODO: consume hexdigit
						return self.token(TokenType.HEX);
					case 'O':
					case 'o':
						// TODO: consume octaldigit
						return self.token(TokenType.OCT);
					case 'B':
					case 'b':
						// TODO: consume binarydigit
						return self.token(TokenType.BIN);
				}
			case '"':
				// consume quoted string
				DString s = self.consume_until('"')!;
				return self.token_with_lexeme(TokenType.QSTRING, s.str_view());

				// TODO: multi-line string (""")
			case '\'':
				// consume literal string
				// TODO: multi-line string (''')
			default:
				if (is_ident(c)) 
				{
					DString s;
					s.new_init(16, self.allocator);
					s.append_char(c);
					if (catch err = self.consume_ident(&s))
					{
						// if we encounter EOF, return
						// content first and error out
						// on the next call.
						if (err != IoError.EOF) return err?;
					}
					String str = s.str_view();
					switch (s)
					{
						case "true":
							return self.token(TokenType.TRUE);
						case "false":
							return self.token(TokenType.FALSE);
						case "nan":
							return self.token(TokenType.NAN);
						case "inf":
							return self.token(TokenType.INF);
					}
					return self.token_with_lexeme(TokenType.IDENT, str);
				}
				else
				{
					return IoError.UNKNOWN_ERROR?;
				}

		}
	}
}


