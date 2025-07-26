module toml::time_test;

import toml::time;
import toml::time::impl @public;

import std::io;
import std::time;

fn void test_parse_date_time() @test
{
	String s = "1996-12-19 16:39:57-08:00";
	TomlDateTime toml_dt = toml::time::parse(s)!!;

	@pool() {
		String r = string::tformat("%s", toml_dt);
		assert(s == r, "got: '%s', want: '%s'", r, s);
	};

	DateTime dt = toml_dt.date_time()!!;
	assert(dt.year == 1996);
	assert(dt.month.ordinal + 1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 8);
	assert(dt.min == 39);
	assert(dt.sec == 57);
}

fn void test_parse_utc() @test
{
	String s = "1996-12-19 16:39:57Z";
	TomlDateTime toml_dt = toml::time::parse(s)!!;

	@pool() {
		String r = string::tformat("%s", toml_dt);
		assert(s == r, "got: '%s', want: '%s'", r, s);
	};

	DateTime dt = toml_dt.date_time()!!;
	assert(dt.year == 1996);
	assert(dt.month.ordinal + 1 == 12);
	assert(dt.day == 19);
	assert(dt.hour == 16);
	assert(dt.min == 39);
	assert(dt.sec == 57);
}

fn void test_parse_utc_frac() @test
{
	String s = "1996-12-19 16:39:57.123456Z";
	TomlDateTime toml_dt = toml::time::parse(s)!!;

	@pool() {
		String r = string::tformat("%s", toml_dt);
		assert(s == r, "got: '%s', want: '%s'", r, s);
	};

	DateTime dt = toml_dt.date_time()!!;
	assert(dt.usec == 123456, "got: %d", dt.usec);
}

fn void test_parse_date_only() @test
{
	String s = "1996-12-19";
	TomlDateTime toml_dt = toml::time::parse(s)!!;

	@pool() {
		String r = string::tformat("%s", toml_dt);
		assert(s == r, "got: '%s', want: '%s'", r, s);
	};

	DateTime dt = toml_dt.date_time()!!;
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
	TomlDateTime toml_dt = toml::time::parse(s)!!;

	@pool() {
		String r = string::tformat("%s", toml_dt);
		assert(s == r, "got: '%s', want: '%s'", r, s);
	};

	DateTime dt = toml_dt.date_time()!!;
	assert(dt.year == 0);
	assert(dt.month == JANUARY);
	assert(dt.day == 1);
	assert(dt.hour == 16);
	assert(dt.min == 39);
	assert(dt.sec == 57, "got: %d, but want: %d", dt.sec, 57);
	assert(dt.usec == 999999);
}

fn void test_is_date_time() @test
{
	String[*] no = { "abc", "a-b-c", "a:b", "1999", "16.40",
		"12345-01-01", "00-11-22", "1990-333-23", "1990-02-123"};
	foreach (t : no) assert(!@ok(toml::time::parse(t)), "parsing '%s' should fail", t);

	String[*] yes = { "2002-02-10", "15:12:12" };
	foreach (t : yes) assert(@ok(toml::time::parse(t)), "parsing '%s' should work", t);
}

