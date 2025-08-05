module toml::time;

import std::time, std::io;
import toml::time::impl @public;

<*
 Parse a TomlDateTime from String
*>
fn TomlDateTime? parse(String input) => impl::parse_string(input);

enum TomlDateTimeKind
{
	DATE_ONLY,
	TIME_ONLY,
	LOCAL_DATE_TIME,
	OFFSET_DATE_TIME,
}

struct TomlDateTime (Printable)
{
	TomlDateTimeKind kind;
	int year, month, day;
	int hour, minute, second;
	int nanosecond;
	int offset_hour, offset_minute;
	int offset_sign;
	bool tz_utc;
}

const DATE_FMT @local      = "%04d-%02d-%02d";
const TIME_FMT @local      = "%02d:%02d:%02d";
const OFFSET_FMT @local    = "%02d:%02d";
const DATE_TIME_FMT @local = "%04d-%02d-%02d %02d:%02d:%02d";

fn int TomlDateTime.offset_seconds(&self) => self.offset_hour * 3600 + self.offset_minute * 60;
fn usz? TomlDateTime.to_format(&self, Formatter* f) @dynamic
{
	usz n;
	switch (self.kind)
	{
		case DATE_ONLY:
			n += f.printf(DATE_FMT, self.year, self.month, self.day)!;
		case LOCAL_DATE_TIME:
			n += f.printf(DATE_TIME_FMT, self.year, self.month, self.day, self.hour, self.minute, self.second)!;
			if (self.nanosecond > 0) n += f.printf(".%d", self.nanosecond/1000)!;
		case OFFSET_DATE_TIME:
			n += f.printf(DATE_TIME_FMT, self.year, self.month, self.day, self.hour, self.minute, self.second)!;
			if (self.nanosecond > 0) n += f.printf(".%d", self.nanosecond/1000)!;
			if (self.tz_utc)
			{
				n += f.print("Z")!;
			}
			else
			{
				int off_secs = self.offset_seconds();
				n += f.print(self.offset_sign < 0 ? "-" : "+")!;
				n += f.printf(OFFSET_FMT, self.offset_hour, self.offset_minute)!;
			}
		case TIME_ONLY:
			n += f.printf(TIME_FMT, self.hour, self.minute, self.second)!;
			if (self.nanosecond > 0) n += f.printf(".%d", self.nanosecond/1000)!;
	}
	return n;
}

// Performs crude validation of the date time data
fn bool TomlDateTime.valid_ranges(&self)
{
	switch (self.kind)
	{
		case DATE_ONLY:
		case LOCAL_DATE_TIME:
		case OFFSET_DATE_TIME:
			if (self.year < 0 || self.year > 9999) return false;
			if (self.month < 1 || self.month > 12) return false;
			if (self.day < 1 || self.day > 31) return false;

			if (self.offset_hour < 0 || self.offset_hour > 24) return false;
			if (self.offset_minute < 0 || self.offset_minute > 60) return false;

			nextcase;
		case TIME_ONLY:
			if (self.hour < 0 || self.hour > 23) return false;
			if (self.minute < 0 || self.minute > 59) return false;
			if (self.second < 0 || self.second > 60) return false;
	}

	// Leap-year
	bool leap = (self.year % 4 == 0 && self.year % 100 != 0) ||
		(self.year % 400 == 0);

	// February checks
	if (self.month == 2 && self.day > (leap ? 29 : 28)) return false;


	return true;
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
				self.hour, self.minute, self.second, 0);
			dt.usec = self.nanosecond / 1000;
		case TIME_ONLY:
			dt = datetime::from_date(
				0, JANUARY, 1,
				self.hour, self.minute, self.second, 0);
			dt.usec = self.nanosecond / 1000;
	}

	if (self.kind == OFFSET_DATE_TIME)
	{
		dt = dt.to_gmt_offset(self.offset_sign * self.offset_seconds()).date_time;
	}

	return dt;
}

//
// -- time implementation
//

module toml::time::impl @private;

faultdef UNKNOWN_CHAR, UNEXPECTED_TOKEN, UNEXPECTED_DIGITS;

enum TokenType
{
	NUMBER,
	COLON,
	DOT,
	T,
	UTC,
	PLUS,
	MINUS,
	SPACE,
	END
}

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

fn Token? Lexer.read_number(&self, usz ndigits = 0)
{
	usz maxlen = 9;
	usz start = self.pos;
	while (self.pos < self.input.len &&
		is_digit(self.input[self.pos]) &&
		self.pos - start < maxlen)
	{
		self.pos += 1;
	}
	if (ndigits > 0 && self.pos - start != ndigits) return UNEXPECTED_DIGITS?;
	int number = self.input[start .. self.pos - 1].to_int()!;
	return { NUMBER, number };
}

fn Token? Lexer.next(&self, usz ndigits = 0)
{
	if (self.pos >= self.input.len) return { .type = END };
	char c = self.input[self.pos];
	if (c == 0) return { .type = END };
	switch (c)
	{
		case ':': self.pos += 1; return { .type = COLON };
		case '.': self.pos += 1; return { .type = DOT };
		case 't':
		case 'T': self.pos += 1; return { .type = T };
		case 'z':
		case 'Z': self.pos += 1; return { .type = UTC };
		case '+': self.pos += 1; return { .type = PLUS };
		case '-': self.pos += 1; return { .type = MINUS };
		case ' ': self.pos += 1; return { .type = SPACE };
		default:
			if (is_digit(c)) return self.read_number(ndigits)!;
			return UNKNOWN_CHAR?;
	}
}

fn void? Lexer.expect(&self, TokenType type, int *arg = null, usz ndigits = 0)
{
	Token tok = self.next(ndigits)!;
	if (tok.type != type) return UNEXPECTED_TOKEN?;
	if (arg) *arg = tok.num;
}

fn void? parse_time(Lexer *lexer, TomlDateTime *dt)
{
	lexer.expect(NUMBER, &dt.hour, 2)!;
	lexer.expect(COLON)!;
	lexer.expect(NUMBER, &dt.minute, 2)!;
	lexer.expect(COLON)!;
	lexer.expect(NUMBER, &dt.second, 2)!;

	Token tok = lexer.next()!;
	if (tok.type == DOT)
	{
		usz start = lexer.pos;
		int frac;
		lexer.expect(NUMBER, &frac)!;
		usz len = lexer.pos - start;
		while (len < 9)
		{
			frac *= 10;
			len += 1;
		}
		dt.nanosecond = frac;

		tok = lexer.next()!;
	}

	switch (tok.type)
	{
		case UTC:
			dt.kind = OFFSET_DATE_TIME;
			dt.tz_utc = true;
		case PLUS:
		case MINUS:
			dt.kind = OFFSET_DATE_TIME;

			lexer.expect(NUMBER, &dt.offset_hour, 2)!;
			lexer.expect(COLON)!;
			lexer.expect(NUMBER, &dt.offset_minute, 2)!;

			dt.offset_sign = tok.type == MINUS ? -1 : 1;
		default:
			// nothing to do
	}
}

fn TomlDateTime? parse_string(String input)
{
	Lexer lexer = { input.trim(), 0 };
	TomlDateTime dt = {};

	lexer.expect(NUMBER)!;
	Token tok = lexer.next()!; // dash or colon
	switch (tok.type)
	{
		case MINUS:
			dt.kind = DATE_ONLY;
			lexer.pos = 0;
			lexer.expect(NUMBER, &dt.year, 4)!;
			lexer.expect(MINUS)!;
			lexer.expect(NUMBER, &dt.month, 2)!;
			lexer.expect(MINUS)!;
			lexer.expect(NUMBER, &dt.day, 2)!;

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

	return dt;
}

