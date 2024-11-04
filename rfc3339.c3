module toml::rfc3339;

import toml::rfc3339::parser @public;

import std::time::datetime;

// Parse date and time formats according to RFC 3339.
// https://www.rfc-editor.org/rfc/rfc3339

/*
   date-fullyear   = 4DIGIT
   date-month      = 2DIGIT  ; 01-12
   date-mday       = 2DIGIT  ; 01-28, 01-29, 01-30, 01-31 based on
                             ; month/year
   time-hour       = 2DIGIT  ; 00-23
   time-minute     = 2DIGIT  ; 00-59
   time-second     = 2DIGIT  ; 00-58, 00-59, 00-60 based on leap second
                             ; rules
   time-secfrac    = "." 1*DIGIT
   time-numoffset  = ("+" / "-") time-hour ":" time-minute
   time-offset     = "Z" / time-numoffset

   partial-time    = time-hour ":" time-minute ":" time-second
                     [time-secfrac]
   full-date       = date-fullyear "-" date-month "-" date-mday
   full-time       = partial-time time-offset

   date-time       = full-date "T" full-time
*/

// 1996-12-19T16:39:57-08:00

fn DateTime! parse(String s)
{
	return Parser{s}.parse();
}

module toml::rfc3339_test @test;

import toml::rfc3339;
import std::io;
import std::time;

fn void! test_parse_date_time() @test
{
	String s = "1996-12-19T16:39:57-08:00";
	DateTime dt = rfc3339::parse(s)!;
	io::printfn("\n%s",s);
	io::printfn("year: %4d, mon: %2d, day: %2d", dt.year, dt.month+1, dt.day);
	io::printfn("hour: %4d, min: %2d, sec: %2d", dt.hour, dt.min, dt.sec);
}

fn void! test_parse_utc() @test
{
	String s = "1996-12-19T16:39:57Z";
	DateTime dt = rfc3339::parse(s)!;
}

fn void! test_parse_utc_frac() @test
{
	String s = "1996-12-19T16:39:57.123456Z";
	DateTime dt = rfc3339::parse(s)!;
}

module toml::rfc3339::parser @private;

import std::time::datetime;

fault Error
{
	INVALID_DATE_FORMAT,
	INVALID_INPUT,
	INVALID_NUMBER,
}

struct Date
{
	int year;
	int month;
	int day;
}

fn void! Date.parse(&d, Parser* p)
{
	if (p.s.len < 10) return Error.INVALID_INPUT?;

	d.year = p.consumeInt()!;
	p.consume('-')!;
	d.month = p.consumeInt()!;
	p.consume('-')!;
	d.day = p.consumeInt()!;
}

struct Time
{
	int hour;
	int min;
	int sec;
	int us;
	bool utc;
}

fn void! Time.parse(&t, Parser* p)
{
	if (p.s.len < 8) return Error.INVALID_INPUT?;

	t.hour = p.consumeInt()!;
	p.consume(':')!;
	t.min = p.consumeInt()!;
	p.consume(':')!;
	t.sec = p.consumeInt()!;

	t.us = 0;
	if (!p.empty() && p.peek() == '.') {
		p.consume('.')!;
		t.us = p.consumeInt()!; 
	}

	if (try p.consume('Z')) t.utc = true;
}

struct Offset
{
	int hour;
	int min;
}

fn void! Offset.parse(&o, Parser* p)
{
	if (p.s.len < 6) return Error.INVALID_INPUT?;

	int sign;
	switch (p.peek())
	{
		case '+':
			sign = 1;
			p.consume('+')!;
		case '-':
			sign = -1;
			p.consume('-')!;
		default:
			return;
	}

	o.hour = sign * p.consumeInt()!;
	p.consume(':')!;
	o.min = p.consumeInt()!;
}

fn int Offset.to_sec(&o)
{
	return o.hour * 3600 + o.min * 60;
}


fault ParserError
{
	INVALID_LENGTH,
	UNEXPECTED_CHAR,
}

struct Parser
{
	String s;
}

fn DateTime! Parser.parse(&p)
{
	Date d;
	d.parse(p)!;

	if (p.peek() == ' ' || p.peek() == 'T') p.consume(p.peek())!;

	Time t;
	t.parse(p)!;

	DateTime dt = datetime::from_date(
		d.year, (Month)(d.month-1), d.day, 
		t.hour, t.min, t.sec, t.us);

	Offset off;
	if (try off.parse(p))
	{
		TzDateTime tzdt = dt.to_gmt_offset(off.to_sec());
		dt = tzdt.date_time;
	}

	return dt;
}

fn bool Parser.empty(&p)
{
	return p.s.len == 0;
}

fn char Parser.peek(&p)
{
	return p.s[0];
}

fn void! Parser.consume(&p, char c)
{
	if (p.empty() || p.peek() != c) return ParserError.UNEXPECTED_CHAR?;
	p.s = p.s[1..];
}

fn int! Parser.consumeInt(&p)
{
	int n, v;
	while (n < p.s.len && p.s[n].is_digit()) n++;

	if (!n) return ParserError.INVALID_LENGTH?;

	v = p.s[:n].to_int()!;
	p.s = p.s[n..];

	return v;
}

fn void Parser.skipSpace(&p)
{
	while (p.s.len && (p.s[0] == ' ' || p.s[0] == '\t')) p.s = p.s[1..];
}

