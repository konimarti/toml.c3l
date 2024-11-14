module toml::rfc3339_test @test;

import toml::rfc3339;

import std::io;
import std::time;

fn void! test_parse_date_time() @test
{
	String s = "1996-12-19T16:39:57-08:00";
	DateTime dt = rfc3339::parse(s)!;
	// io::printfn("\n%s",s);
	// io::printfn("year: %4d, mon: %2d, day: %2d", dt.year, dt.month+1, dt.day);
	// io::printfn("hour: %4d, min: %2d, sec: %2d", dt.hour, dt.min, dt.sec);

	assert(dt.year == 1996);
	assert((int)dt.month+1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 8);
	assert(dt.min == 39);
	assert(dt.sec == 57);
}

fn void! test_parse_utc() @test
{
	String s = "1996-12-19T16:39:57Z";
	DateTime dt = rfc3339::parse(s)!;

	assert(dt.year == 1996);
	assert((int)dt.month+1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 16);
	assert(dt.min == 39);
	assert(dt.sec == 57);
}

fn void! test_parse_utc_frac() @test
{
	String s = "1996-12-19T16:39:57.123456Z";
	DateTime dt = rfc3339::parse(s)!;
}

