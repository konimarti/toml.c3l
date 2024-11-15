module toml::rfc3339_test @test;

import toml::rfc3339;

import std::io;
import std::time;

fn void! test_parse_offset_date_time() @test
{
	String s = "1996-12-19T16:39:57-08:00";
	DateTime dt = rfc3339::parse(s)!;

	assert(dt.year == 1996);
	assert((int)dt.month+1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 8);
	assert(dt.min == 39);
	assert(dt.sec == 57);
	assert(dt.usec == 0);
}

fn void! test_parse_local_date_time() @test
{
	String s = "1996-12-19T16:39:57.123456";
	DateTime dt = rfc3339::parse(s)!;

	assert(dt.year == 1996);
	assert((int)dt.month+1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 16);
	assert(dt.min == 39);
	assert(dt.sec == 57);
	assert(dt.usec == 123456);
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
	assert(dt.usec == 0);
}

fn void! test_parse_utc_frac() @test
{
	String s = "1996-12-19T16:39:57.123456Z";
	DateTime dt = rfc3339::parse(s)!;
	assert(dt.usec == 123456);
}

fn void! test_parse_local_date() @test
{
	String s = "1996-12-19";
	DateTime! dt = rfc3339::parse(s);
	assert(@catch(dt) == Error.INVALID_RFC3339);
}

fn void! test_parse_local_time() @test
{
	String s = "16:39:57.123456";
	DateTime! dt = rfc3339::parse(s);
	assert(@catch(dt) == Error.INVALID_RFC3339);
}
