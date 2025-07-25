module toml::time;

import std::time;
import std::io; // Debugging

enum TomlDateTimeKind
{
	DATE_ONLY,
	TIME_ONLY,
	LOCAL_DATE_TIME,
	OFFSET_DATE_TIME,
}

struct TomlDateTime (Printable)
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

fn int TomlDataTime.offset_secs(&self) =>
	tz_hour_offset * 3600 + tz_minute_offset * 60

fn usz? TomlDataTime.to_format(&self, Formatter* f) @dynamic
{
	const DATE_FMT = "%d-%d-%d";
	const TIME_FMT = "%d:%d:%d";
	const OFF_FMT  = "%d:%d";
	switch (self.kind)
	{
		case DATE_ONLY:
			f.printf(DATE_FMT, self.year, self.month, self.day);
		case LOCAL_DATE_TIME:
			f.printf(DATE_FMT + " " + TIME_FMT, self.year, self.month, self.day, self.hour, self.minute, self.seconds);
			if (self.nanosecond > 0) f.printf(".%d", self.nanosecond/1000);
		case OFFSET_DATE_TIME:
			f.printf(DATE_FMT + " " + TIME_FMT, self.year, self.month, self.day, self.hour, self.minute, self.seconds);
			if (self.nanosecond > 0) f.printf(".%d", self.nanosecond/1000);
			if (self.tz_utc) f.print("Z");
			int off_secs = self.offset_secs();
			if (off_secs != 0)
			{
				f.print(off_secs < 0 ? "-" : "+");
				f.printf(OFF_FMT, self.tz_hour_offset, self.tz_minute_offset);
			}
		case TIME_ONLY:
			f.printf("%d:%d:%d", self.hour, self.minute, self.seconds);
			if (self.nanosecond > 0) f.printf(".%d", self.nanosecond/1000);
	}
}

fn DateTime? TomlDateTime.date_time(&self)
{
	DateTime dt;
	switch (self.kind)
	{
		case DATE_ONLY:
		case LOCAL_DATE_TIME:
		case OFFSET_DATE_TIME:
			dt = datetime::from_date(
				self.year, Month.from_ordinal(self.month-1), self.day,
				self.hour, self.minute, self.second,
				self.nanosecond / 1000);
		case TIME_ONLY:
			dt = datetime::from_date(
				0, JANUARY, 1,
				self.hour, self.minute, self.second,
				self.nanosecond / 1000);
	}

	if (self.kind == OFFSET_DATE_TIME)
	{
		dt = dt.to_gmt_offset(self.offset_secs()).date_time;
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

faultdef UNKNOWN_CHAR, UNEXPECTED_TOKEN;

struct Token
{
	TokenType type;
	int num;
}

struct Lexer
{
	String input;
	usz pos;
}

fn bool is_digit(char c) => c >= '0' && c <= '9';

fn Token? Lexer.read_number(&self, usz maxlen)
{
	usz start = self.pos;
	while (self.pos < self.input.len &&
		is_digit(self.input[self.pos]) &&
		self.pos - start < maxlen)
	{
		self.pos += 1;
	}
	int number = self.input[start .. self.pos - 1].to_int()!;
	io::printfn("num: %d", number);
	return { NUMBER, number };
}

fn Token? Lexer.next(&self)
{
	if (self.pos >= self.input.len) return { .type = END };

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
			if (is_digit(c)) return self.read_number(9)!;
			return UNKNOWN_CHAR?;
	}
}

fn void? Lexer.expect(&self, TokenType type, int *arg = null)
{
	Token tok = self.next()!;
	if (tok.type != type) return UNEXPECTED_TOKEN?;
	if (arg) *arg = tok.num;
}

fn void? parse_time(Lexer *lexer, TomlDateTime *dt)
{
	lexer.expect(NUMBER, &dt.hour)!;
	lexer.expect(COLON)!;
	lexer.expect(NUMBER, &dt.minute)!;
	lexer.expect(COLON)!;
	lexer.expect(NUMBER, &dt.second)!;

	Token tok = lexer.next()!;
	if (tok.type == DOT)
	{
		usz start = lexer.pos;
		int frac;
		lexer.expect(NUMBER, &frac)!;
		io::printfn("frac: %d", frac);
		usz len = lexer.pos - start;
		while (len < 9)
		{
			frac *= 10;
			len += 1;
		}
		dt.nanosecond = frac;
		io::printfn("nano: %d", frac);

		tok = lexer.next()!;
	}

	switch (tok.type)
	{
		case Z:
			dt.kind = OFFSET_DATE_TIME;
			dt.tz_utc = true;
		case PLUS:
		case MINUS:
			dt.kind = OFFSET_DATE_TIME;

			lexer.expect(NUMBER, &dt.tz_hour_offset)!;
			lexer.expect(COLON)!;
			lexer.expect(NUMBER, &dt.tz_minute_offset)!;

			if (tok.type == MINUS)
			{
				dt.tz_hour_offset *= -1;
				dt.tz_minute_offset *= -1;
			}
		default:
			// nothing to do
	}
}

fn DateTime? parse(String input)
{
	Lexer lexer = { input, 0 };
	TomlDateTime dt = {};

	lexer.expect(NUMBER)!;
	Token tok = lexer.next()!; // dash or colon
	switch (tok.type)
	{
		case MINUS:
			dt.kind = DATE_ONLY;
			lexer.pos = 0;
			lexer.expect(NUMBER, &dt.year)!;
			lexer.expect(MINUS)!;
			lexer.expect(NUMBER, &dt.month)!;
			lexer.expect(MINUS)!;
			lexer.expect(NUMBER, &dt.day)!;

			tok = lexer.next()!;
			if (tok.type == T || tok.type == SPACE)
			{
				dt.kind = LOCAL_DATE_TIME;
				parse_time(&lexer, &dt)!;
			}

		case COLON:
			dt.kind = TIME_ONLY;
			lexer.pos = 0;
			parse_time(&lexer, &dt)!;

		default:
			return UNEXPECTED_TOKEN?;
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
	assert(dt.usec == 123456, "got: %d", dt.usec);
}

fn void test_parse_date_only() @test
{
	String s = "1996-12-19";
	DateTime dt = toml::time::parse(s)!!;
	assert(dt.year == 1996);
	assert(dt.month.ordinal + 1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 0);
	assert(dt.min == 0);
	assert(dt.sec == 0);
}

fn void test_parse_time_only() @test
{
	String s = "16:39:57.999999";
	DateTime dt = toml::time::parse(s)!!;

	assert(dt.year == 0);
	assert(dt.month == JANUARY);
	assert(dt.day == 1);
	assert(dt.hour == 16);
	assert(dt.min == 39);
	assert(dt.sec == 57, "got: %d, but want: %d", dt.sec, 57);
	assert(dt.usec == 999999);
}


