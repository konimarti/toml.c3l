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

fault Error
{
	INVALID_RFC3339
}

fn DateTime! parse(String s)
{
	DateTimeObject dto = Parser{s}.parse()!;
	if (dto.type == DATETIME) return dto.dt;
	return Error.INVALID_RFC3339?;
}


module toml::rfc3339::parser @private;

import std::io;
import std::time::datetime;

fault Error
{
	INVALID_DATE_FORMAT,
	INVALID_INPUT,
	INVALID_NUMBER,
	INVALID_TOKEN,
}

struct Date
{
	int year;
	int month;
	int day;
}

struct Time
{
	int hour;
	int min;
	int sec;
	int us;
	bool utc;
}

struct Offset
{
	int hour;
	int min;
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

enum TokenType
{
	INTEGER,
	MINUS,
	PLUS,
	COLON,
	PERIOD,
	UTC,
	DATE_TIME_SEP,
	EOF,
}

struct Token
{
	TokenType type;
	int value;
}

fn Token Parser.lex(&p)
{
	TokenType t;
	char c = p.peek();
	switch (c)
	{
		case '0'..'9':
			return {.type = TokenType.INTEGER,
				.value = p.consumeInt()!!};
		case '-':
			t = TokenType.MINUS;
		case '+':
			t = TokenType.PLUS;
		case ':':
			t = TokenType.COLON;
		case '.':
			t = TokenType.PERIOD;
		case 'Z':
		case 'z':
			t = TokenType.UTC;
		case 'T':
		case 't':
		case ' ':
			t = TokenType.DATE_TIME_SEP;
		default:
			return {.type = TokenType.EOF};
	}
	p.consume(c)!!;
	return {.type = t};
}

enum DateTimeType
{
	DATE,
	TIME,
	DATETIME,
}

struct DateTimeObject
{
	DateTimeType type;
	union
	{
		Date d;
		Time t;
		DateTime dt;
	}
}

struct Block
{
	DateTimeType type;
	int[3] values;
}

fn Block! Parser.block(&p)
{
	Token[5] tokens;
	for (int i = 0; i < 5; i++)
	{
		tokens[i] = p.lex();
		if (tokens[i].type == EOF) return Error.INVALID_DATE_FORMAT?;
	}

	if (tokens[1].type != tokens[3].type) return Error.INVALID_DATE_FORMAT?;

	Block blk = { .values = {tokens[0].value, tokens[2].value, tokens[4].value} };

	switch (tokens[1].type)
	{
		case MINUS:
			blk.type = DATE;	
		case COLON:
			blk.type = TIME;	
		default:
			return Error.INVALID_DATE_FORMAT?;
	}
	return blk;
}

struct TimeAttribute
{
	int usec;
	bool utc;
	Offset off;
}

fn TimeAttribute! Parser.attributes(&p)
{
	TimeAttribute a;
	Token tok;
	int sign = 1;
	while (1)
	{
		tok = p.lex();
		switch (tok.type)
		{
			case UTC:
				a.utc = true;
			case PERIOD:
				tok = p.lex();
				if (tok.type != INTEGER) return Error.INVALID_DATE_FORMAT?;
				a.usec = tok.value;
			case MINUS:
				sign = -1;
				nextcase;
			case PLUS:
				a.off.hour = sign*p.lex().value;
				tok = p.lex();
				if (tok.type != COLON) return Error.INVALID_DATE_FORMAT?;
				a.off.min = p.lex().value;
			case EOF:
				return a;
			default:
				return Error.INVALID_DATE_FORMAT?;
		}
	}
}

fn DateTimeObject! Parser.parse(&p)
{
	Date d;
	Time t;
	Offset off;
	DateTimeObject dto;

	Block blk = p.block()!;
	if (blk.type == DATE)
	{
		d.year = blk.values[0];
		d.month = blk.values[1];
		d.day = blk.values[2];
		dto.type = DATE;

		Token tok = p.lex();
		if (tok.type == DATE_TIME_SEP)
		{
			blk = p.block()!;	
			dto.type = DATETIME;
		}
	}

	if (blk.type == TIME)
 	{
		t.hour = blk.values[0];
		t.min = blk.values[1];
		t.sec = blk.values[2];
		if (dto.type != DATETIME) dto.type = TIME;

		TimeAttribute a = p.attributes()!;

		t.us = a.usec;
		t.utc = a.utc;
		off = a.off;
	}

	io::printfn("date: %d-%d-%d", d.year, d.month, d.day);
	io::printfn("time: %d:%d:%d.%d %s", t.hour, t.min, t.sec, t.us, t.utc);

	switch (dto.type)
	{
		case DATE:
			dto.d = d;
		case TIME:
			dto.t = t;
		case DATETIME:
			dto.dt = datetime::from_date(
				d.year, (Month)d.month-1, d.day, 
				t.hour, t.min, t.sec, t.us);
			if (off.to_sec())
			{
				TzDateTime tzdt = dto.dt.to_gmt_offset(off.to_sec());
				dto.dt = tzdt.date_time;
			}
	}

	return dto;
}

fn bool Parser.empty(&p) => p.s.len == 0;

fn char Parser.peek(&p)
{
	if (p.empty()) return '\0';
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
