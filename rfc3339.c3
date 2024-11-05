module toml::rfc3339;

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

struct Parser
{
	String s;
}

fn bool Parser.empty(&p)
	return p.len == 0;
}

fn char Parser.peek(&p)
{
	return p.s[0];
}

fn bool Parser.consume(&p, char c)
{
	if (p.empty() || p.peek() != c) return false;
	p.s = p.s[1:];
	return true;
}

fn int! Parser.consume4(&p)
{
	DString d;
	d.tinit(4);
	// FIXME:WIP
}

fn void Parser.skipSpace(&p)
{
	while (p.s.len() && (p.s[0] == ' ' || p.s[0] == '\t')) p.s = p.s[1:];
}

fault Error
{
	INVALID_DATE_FORMAT
	INVALID_NUMBER
}

fn Datetime! parse(String s)
{
	Parser p = {s};

	int year = p.consume4();
	if (p.peek() != '-') return Error.INVALID_DATE_FORMAT?;

	int month = p.consume2();
	if (p.peek() != '-') return Error.INVALID_DATE_FORMAT?;

	int day = p.consume2();

	if (p.peek() != ' ' || p.peek() != 'T' || p.peek() != 't') return Error.INVALID_DATE_FORMAT?;

	int hour = p.consume2();
	if (p.peek() != ':') return Error.INVALID_DATE_FORMAT?;

	int min = p.consume2();
	if (p.peek() != ':') return Error.INVALID_DATE_FORMAT?;

	int sec = p.consume2();

	int us = 0;
	if (!p.empty() && p.peek() == '.') {
		// TODO: read sec-frac
	}

	if (p.empty()) 
	{
		return DateTime.from_date(year, month, day, hour, min, sec, us);
	}

	bool utc = false
	switch (p.peek())
	case 'z':
	case 'Z':
		utc = true;
	case '-':
	case '+':
	}

	// FIXME: adjust gmt offset
	return DateTime.from_date(year, month, day, hour, min, sec, us);
}



