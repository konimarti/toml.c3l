module toml::lexer;
import std::io;
import std::collections::object;
import std::collections::list;

def TokenList = List(<Token>);

fault Errors {
	GENERL_ERROR,
}

// -- implementation follows --

enum TokenType @local
{
	// single-char token
	EOF,
	NEWLINE,
	LBRACE,
	RBRACE,
	LBRACKET,
	RBRACKET,
	COMMA,
	PLUS,
	MINUS,
	PERIOD,
	EQUAL,

	// literals
	COMMENT,
	STRING, // [ml-]basic-string, [ml-]literal-string, unquote-key
	INTEGER, // dec, hex, oct, bin
	FLOAT, // infinity, nan
	BOOLEAN, // true, false
	DATETIME,
}

struct Token (Printable)
{
	TokenType type;
	String lexeme;
	Object *literal;
	int line;
}

fn usz! Token.to_format(&self, Formatter* f) @dynamic
{
	usz n = f.printf("-- line: %d tok: %8s", self.line, self.type)!;
	if (self.lexeme.trim().len) {
		n += f.printf(" lexeme: %s", self.lexeme)!;
	}
	n += f.printf("\n")!;
	return n;
}

struct Lexer
{
	String s;
	Allocator allocator;
	TokenList *tokens;
	bool scan_value;
	int start;
	int current;
	int line;
}

fn Lexer* Lexer.init(&self, String s, Allocator allocator)
{
	TokenList *tokens = allocator::new(allocator, TokenList);
	*self = {s, allocator, tokens.new_init(16, allocator), false, 0, 0, 1};
	return self;
}

fn void Lexer.free(&self)
{
	// FIXME: we need to free the token.literals, too
	if (self.tokens) self.tokens.free();
}

fn bool Lexer.at_end(&self)
{
	return self.current >= self.s.len; 
}

fn char! Lexer.advance(&self)
{
	if (self.at_end()) return IoError.EOF?;
	return self.s[self.current++];
}

fn char Lexer.peek(&self)
{
	if (self.at_end()) return '\0';
	return self.s[self.current];
}

fn char Lexer.peek_next(&self)
{
	if (self.current + 1 >= self.s.len) return '\0';
	return self.s[self.current + 1];
}

fn bool Lexer.must(&self, char c)
{
	if (self.at_end() || self.peek() != c) return false;
	self.current++;
	return true;
}

fn void Lexer.add_token(&self, TokenType type, Object *literal = null)
{
	String text = self.s[self.start..self.current-1];
	self.tokens.push(Token{
		.type = type,
		.lexeme = text.copy(self.allocator),
		.literal = literal,
		.line = self.line,
	});
}

fn TokenList*! Lexer.scan_tokens(&self)
{
	while (!self.at_end())
	{
		self.start = self.current;
		self.scan_token()!;
	}
	self.add_token(TokenType.EOF);
	return self.tokens;
}

fn void! Lexer.scan_token(&self)
{
	char c = self.advance()!;
	switch (c) 
	{
		case 0x20: // space
		case 0x09: // \t
		case 0x0D: // \r
			break;
		case 0x0A:
			self.line++;
			self.scan_value = false;
			self.add_token(TokenType.NEWLINE);
		case '#':
			while (self.peek() != 0x0A) self.advance()!;
			self.add_token(TokenType.COMMENT);
		case '.':
			self.add_token(TokenType.PERIOD);
		case '=':
			self.scan_value = true;
			self.add_token(TokenType.EQUAL);
		case '{':
			self.add_token(TokenType.LBRACE);
		case '}':
			self.add_token(TokenType.RBRACE);
		case '[':
			self.add_token(TokenType.LBRACKET);
		case ']':
			self.add_token(TokenType.RBRACKET);
		case ',':
			self.add_token(TokenType.COMMA);
		case '"':
			self.basic_string()!;
		case '\'':
			self.literal_string()!;
		default:
			if (self.scan_value && (c.is_digit() || c == '+' || c == '-')) {
				self.number_or_datetime()!;
			}
			else
			{
				self.unquoted_key()!;
			}
	}
}

fn void! Lexer.basic_string(&self)
{
	// we have already consumed '"'
	while (!self.at_end() && self.peek() != '"') self.advance()!;
	// FIXME: object literal?
	self.add_token(TokenType.STRING);
}

fn void! Lexer.literal_string(&self)
{
	// we have already consumed '''
	while (!self.at_end() && self.peek() != '\'') self.advance()!;
	// FIXME: object literal?
	self.add_token(TokenType.STRING);
}

fn void! Lexer.unquoted_key(&self)
{
	char p;
	while LOOP: (!self.at_end())
	{
		p = self.peek();
		if ((p >= 'a' && p <= 'z') || (p >= 'A' && p <= 'Z') || 
			(p >= '0' && p <= '9') || p == '-' || p == '_' )
		{
			self.advance()!;
		} else {
			break LOOP;
		}
	}
	String text = self.s[self.start..self.current-1];
 	Object *literal = object::new_string(text, self.allocator);
	self.add_token(TokenType.STRING, literal);
}

fn void! Lexer.number_or_datetime(&self)
{
	unsupported("not implemented yet");
}

