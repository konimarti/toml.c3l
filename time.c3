module toml::time;

import std::time;

enum TomlDateTimeKind
{
	DATE_ONLY,
	TIME_ONLY,
	LOCAL_DATE_TIME,
	OFFSET_DATE_TIME,
}

struct TomlDateTime
{
	int year;
	int month;
	int day;
	int hour;
	int minute;
	int second;
	int nanosecond;
	int tz_hour_offset;
	int tz_minute_offset;
	bool tz_utc;
	TomlDateTimeKind kind;
}

fn DateTime? TomlDateTime.date_time(&self)
{
	DateTime dt = datetime::from_date(
		self.year, Month.from_ordinal(self.month-1), self.day,
		self.hour, self.minute, self.second, self.nanosecond / 1000);

	if (self.kind == OFFSET_DATE_TIME)
	{
		TzDateTime tzdt = dt.to_gmt_offset(self.tz_hour_offset * 3600 + self.tz_minute_offset * 60);
		dt = tzdt.date_time;
	}

	return dt;
}

enum TokenType
{
	NUMBER,
	DASH,
	COLON,
	DOT,
	T,
	Z,
	PLUS,
	MINUS,
	SPACE,
	END
}

faultdef UNKNOWN_CHAR, EXPECTED_DASH, EXPECTED_COLON, INVALID_INPUT;

struct Token
{
	TokenType type;
	int num;
}

struct Lexer
{
	String input;
	usz pos;
	usz mark;
}

fn bool is_digit(char c) => c >= '0' && c <= '9';

fn Token? Lexer.read_number(&self, usz maxlen)
{
	usz start = self.pos;
	while (self.pos < self.input.len && is_digit(self.input[self.pos]) && self.pos - start < maxlen) self.pos += 1;
	int number = self.input[start .. self.pos - 1].to_int()!;
	return { NUMBER, number };
}

fn Token? Lexer.next(&self)
{
	self.mark = self.pos;
	char c = self.input[self.pos];
	if (c == 0) return { .type = END };

	switch (c)
	{
		case ':': self.pos += 1; return { .type = COLON };
		case '.': self.pos += 1; return { .type = DOT };
		case 'T': self.pos += 1; return { .type = T };
		case 'Z': self.pos += 1; return { .type = Z };
		case '+': self.pos += 1; return { .type = PLUS };
		case '-': self.pos += 1; return { .type = MINUS };
		case ' ': self.pos += 1; return { .type = SPACE };
		default:
			if (is_digit(c))
			{
				return self.read_number(9)!;
			}
			return UNKNOWN_CHAR?;
	}
}

fn Token? Lexer.peek(&self)
{
	usz save = self.pos;
	Token tok = self.next()!;
	self.pos = save;
	return tok;
}

fn void? parse_time(Lexer *lexer, TomlDateTime *dt)
{
	Token tok;

	tok = lexer.next()!;
	if (tok.type == NUMBER) dt.hour = tok.num;

	tok = lexer.next()!;
	if (tok.type != COLON) return EXPECTED_COLON?;

	tok = lexer.next()!;
	if (tok.type == NUMBER) dt.minute = tok.num;

	tok = lexer.next()!;
	if (tok.type != COLON) return EXPECTED_COLON?;

	tok = lexer.next()!;
	if (tok.type == NUMBER) dt.second = tok.num;

	tok = lexer.next()!;
	if (tok.type == DOT)
	{
		usz start = lexer.pos;
		while (is_digit(lexer.input[lexer.pos])) lexer.pos += 1;
		usz len = lexer.pos - start;
		int frac = lexer.input[start .. lexer.pos - 1].to_int()!;
		while (len < 9) {
			frac *= 10; len += 1;
		}
		dt.nanosecond = frac;
		tok = lexer.next()!;
	}

	switch (tok.type)
	{
		case Z:
			dt.kind = OFFSET_DATE_TIME;
			dt.tz_utc = true;

		case PLUS:
		case MINUS:
			int sign = (tok.type == MINUS) ? -1 : 1;

			tok = lexer.next()!;
			if (tok.type == NUMBER) dt.tz_hour_offset = sign * tok.num;

			tok = lexer.next()!;
			if (tok.type != COLON) return EXPECTED_COLON?;

			tok = lexer.next()!;
			if (tok.type == NUMBER) dt.tz_minute_offset = sign * tok.num;
			dt.kind = OFFSET_DATE_TIME;

		default:
			lexer.pos = lexer.mark; // rewind if no timezone
	}
}

fn DateTime? parse(String input)
{
	Lexer lexer = { input, 0, 0 };
	TomlDateTime dt = {};
	Token first = lexer.peek()!;

	if (first.type != NUMBER) return INVALID_INPUT?; // must begin with a number

	Token tok = lexer.next()!; // year/hour
	Token sep_tok = lexer.next()!; // dash or colon

	switch (sep_tok.type)
	{
		case MINUS:
			dt.kind = DATE_ONLY;
			dt.year = tok.num;

			tok = lexer.next()!;
			if (tok.type == NUMBER) dt.month = tok.num;

			tok = lexer.next()!;
			if (tok.type != MINUS) return EXPECTED_DASH?;

			tok = lexer.next()!;
			if (tok.type == NUMBER) dt.day = tok.num;

			Token sep = lexer.next()!;
			if (sep.type == T || sep.type == SPACE)
			{
				dt.kind = LOCAL_DATE_TIME;
				parse_time(&lexer, &dt)!;
			}

		case COLON:
			dt.kind = TIME_ONLY;
			dt.hour = tok.num;
			lexer.pos = lexer.mark; // rewind before colon
			parse_time(&lexer, &dt)!;

		default:
			return INVALID_INPUT?;
	}

	return dt.date_time();
}



module toml::time_test;

import toml::time;

import std::io;
import std::time;

fn void test_parse_date_time() @test
{
	String s = "1996-12-19T16:39:57-08:00";
	DateTime dt = toml::time::parse(s)!!;

	assert(dt.year == 1996);
	assert(dt.month.ordinal + 1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 8);
	assert(dt.min == 39);
	assert(dt.sec == 57);
}

fn void test_parse_utc() @test
{
	String s = "1996-12-19T16:39:57Z";
	DateTime dt = toml::time::parse(s)!!;

	assert(dt.year == 1996);
	assert(dt.month.ordinal + 1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 16);
	assert(dt.min == 39);
	assert(dt.sec == 57);
}

fn void test_parse_utc_frac() @test
{
	String s = "1996-12-19T16:39:57.123456Z";
	DateTime dt = toml::time::parse(s)!!;
}

