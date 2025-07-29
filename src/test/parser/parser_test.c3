module toml::parser_test @test;

import toml;

import std::io;
import std::math;
import std::collections::object;

const TOML_DOC = `
	# This is a TOML document

	title = "TOML Example"

	[owner]
	name = "Tom Preston-Werner"
	dob = 1979-05-27T07:32:00-08:00

	[database]
	enabled = true
	ports = [ 8000, 8001, 8002 ]
	#data = [ ["delta", "phi"], [3.14] ]
	temp_targets = { cpu = 79.5, case = 72.0 }

	[servers]

	[servers.alpha]
	ip = "10.0.0.1"
	role = "frontend"

	[servers.beta]
	ip = "10.0.0.2"
	role = "backend"
`;

fn void test_parser_toml_doc() @test
{
	toml::parser::Parser scan;
	scan.init(TOML_DOC, tmem);
	Object* obj = scan.toml()!!;
	//io::printn(obj);

	Object* owner = obj.get("owner")!!;
	Object* database = obj.get("database")!!;
	Object* ports = database.get("ports")!!;
	Object* temp = database.get("temp_targets")!!;

	Object* servers = obj.get("servers")!!;
	Object* alpha = servers.get("alpha")!!;
	Object* beta = servers.get("beta")!!;

	assert(obj.get_string("title")!! == "TOML Example");
	assert(owner.get_string("name")!! == "Tom Preston-Werner");
	assert(owner.get_string("dob")!! == "1979-05-27T07:32:00-08:00");

	assert(database.get_bool("enabled")!! == true);
	assert(database.get_bool("enabled")!! == true);

	assert(ports.get_len() == 3);
	assert(ports.get_int_at(0)!! == 8000);
	assert(ports.get_int_at(1)!! == 8001);
	assert(ports.get_int_at(2)!! == 8002);

	assert(@catch(database.get("data")) == NOT_FOUND);

	assert(math::abs(temp.get_float("cpu")!! - 79.5) < math::FLOAT_EPSILON);
	assert(math::abs(temp.get_float("case")!! - 72.0) < math::FLOAT_EPSILON);

	assert(alpha.get_string("ip")!! == "10.0.0.1");
	assert(alpha.get_string("role")!! == "frontend");

	assert(beta.get_string("ip")!! == "10.0.0.2");
	assert(beta.get_string("role")!! == "backend");
}

struct StringTestCase
{
	String name;
	String input;
	String want;
}

fn void parser_value_string() @test
{
	StringTestCase[] tests = {
		{
			.name = "quoted string",
			.input = `"quoted\"string"rest`,
			.want = "quoted\\\"string",
		},
		{
			.name = "basic string with unicode",
			.input = `"\UF09F918D"`,
			.want = "\\UF09F918D",
		},
		{
			.name = "multiline basic string with mlb-quotes",
			.input = `"""string""hello"world"""""`,
			.want = "string\"\"hello\"world\"\"",
		},
		{
			.name = "multiline basic string with newlines",
			.input = "\"\"\"hello\nworld\"\"\"",
			.want = "hello\nworld",
		},
		{
			.name = "multiline basic string with escaped newlines",
			.input = "\"\"\"hello \\ \nworld\"\"\"",
			.want = "hello world",
		},
		{
			.name = "multiline literal string with escaped newlines",
			.input = `'''hello\nworld'''''`,
			.want = "hello\\nworld''",
		},
	};

	foreach (i, t : tests)
	{
		toml::parser::Parser p;
		String s = p.init(t.input, tmem).string()!!.s;
		assert(s == t.want,
			"test %d [%s]: got: %s, but want: %s",
				i+1, t.name, s, t.want);
	}
}

fn void parser_array_tables() @test
{
	toml::parser::Parser p;
	p.init(`
		[[product]]
		widget.color = "green"
		widget.price = 3.14
		[[product]]
		[[product]]
		widget.color = "blue"
		widget.price = 2.71
		`,
		tmem,
	);

	Object* obj = p.toml()!!;
	// io::printn(obj);
	assert(obj.get("product")!!.get_len() == 3,
		"array_tables: incorrect array length");
}

fn void parser_inline_tables() @test
{
	toml::parser::Parser p;
	p.init(
	`widget = { color = "green", price = 3.14, vendors = ["abc", "def"]}`,
		tmem,
	);

	Object* obj = p.toml()!!;
	// io::printn(obj);

	Object* widget = obj.get("widget")!!;
	Object* vendors = widget.get("vendors")!!;

	assert(widget.get_string("color")!! == "green");
	assert(widget.get_float("price")!! == 3.14);
	assert(vendors.get_len() == 2);
	assert(vendors.get_string_at(1)!! == "def");
}

struct IntegerTestCase
{
	String name;
	String input;
	int want;
}

fn void parser_value_integer() @test
{
	IntegerTestCase[] tests = {
		{
			.name = "dec-int 1",
			.input = `123`,
			.want = 123,
		},
		{
			.name = "dec-int minus",
			.input = `-123`,
			.want = -123,
		},
		{
			.name = "dec-int plus",
			.input = `+123`,
			.want = 123,
		},
		{
			.name = "dec-int zero",
			.input = `0`,
			.want = 0,
		},
		{
			.name = "dec-int with underscore",
			.input = `1_000_000`,
			.want = 1000000,
		},
		{
			.name = "hex-int",
			.input = `0xbeef`,
			.want = 48879,
		},
		{
			.name = "hex-int case",
			.input = `0xbEeF`,
			.want = 48879,
		},
		{
			.name = "hex-int with underscore",
			.input = `0xbe_ef`,
			.want = 48879,
		},
		{
			.name = "oct-int",
			.input = `0o644`,
			.want = 420,
		},
		{
			.name = "bin-int",
			.input = `0b1001`,
			.want = 9,
		},
	};

	foreach (i, t : tests)
	{
		toml::parser::Parser p;
		p.init(t.input, tmem);
		Object *integer = p.number_or_datetime()!!;
		assert(integer.is_int(),
			"test %d [%s]: object value is not an integer",
				i+1, t.name);
		int value = (int)integer.i;
		assert(value == t.want,
			"test %d [%s]: got: %d, but want: %d",
				i+1, t.name, value, t.want);
	}
}

struct FloatTestCase
{
	String name;
	String input;
	double want;
}

fn void parser_value_float() @test
{
	FloatTestCase[] tests = {
		{
			.name = "float",
			.input = `123.456`,
			.want = 123.456,
		},
		{
			.name = "float with underscore",
			.input = `1_2_3.4_5_6`,
			.want = 123.456,
		},
		{
			.name = "float minus",
			.input = `-123.456`,
			.want = -123.456,
		},
		{
			.name = "float exp 0",
			.input = `1e0`,
			.want = 1,
		},
		{
			.name = "float exp 2",
			.input = `1e2`,
			.want = 100,
		},
		{
			.name = "float exp -2",
			.input = `1e-2`,
			.want = 0.01,
		},
		{
			.name = "float exp 2 with frac",
			.input = `1.1e2`,
			.want = 110,
		},
		{
			.name = "float nan",
			.input = `nan`,
			.want = float.nan,
		},
		{
			.name = "float -nan",
			.input = `-nan`,
			.want = -float.nan,
		},
		{
			.name = "float +inf",
			.input = `+inf`,
			.want = float.inf,
		},
		{
			.name = "float -inf",
			.input = `-inf`,
			.want = -float.inf,
		},
	};

	foreach (i, t : tests)
	{
		toml::parser::Parser p;
		p.init(t.input, tmem);
		Object *real = p.number_or_datetime()!!;
		assert(real.is_float(),
			"test %d [%s]: object value is not a double", i+1, t.name);
		double value = (double)real.f;
		if (math::is_nan(t.want))
		{
			assert(math::is_nan(value),
				"test %d [%s]: value is not a nan", i+1, t.name);
		}
		else
		{
			assert(equals(value, t.want),
				"test %d [%s]: got: %g, but want: %g", i+1, t.name, value, t.want);
		}
	}
}

struct InvalidToml
{
	String name;
	String input;
}

fn void parser_toml_test_invalid() @test => @pool()
{
	InvalidToml[*] invalid_tests = {
		{
			.name = "invalid/table/overwrite-with-deep-table",
			.input = "a=1\n[a.b.c.d]",
		},
		{
			.name = "invalid/table/super-twice",
			.input = "[a.b]\n[a]\n[a]",
		},
		{
			.name = "invalid/table/overwrite-bool-with-array",
			.input = "a=true\n[[a]]",
		},
		{
			.name = "invalid/table/duplicated-table-array",
			.input = "[tbl]\n[[tbl]]",
		},
		{
			.name = "invalid/table/multiline-no-close-5",
			.input = "bee = \"\"\"\nhee\ngee\\",
		},
		{
			.name = "invalid/table/multiline-escape-space-2",
			.input = "bee = \"\"\"\n hee \\n gee \\   \"\"\"",
		},
		{
			.name = "invalid/table/basic-out-of-range-unicode-escape-1",
			.input = `"\UFFFFFFFF"`,
		},
		{
			.name = "invalid/table/basic-out-of-range-unicode-escape-2",
			.input =  `"\U00D80000"`,
		},
		{
			.name = "invalid/spec/inline-table-2-0",
			.input =  "[product]\ntype = { name = \"Nail\" }\ntype.edible = false",
		},
		{
			.name = "invalid/local-time/second-over",
			.input = "d = 00:00:61", // 60 is allowed for leap-year but not 61
		},
		{
			.name = "invalid/local-time/time-no-leads",
			.input = "d = 1:32:00", // leading 0 required
		},
		{
			.name = "invalid/local-time/time-no-leads-2",
			.input = "d = 01:32:0", // leading 0 required
		},
		{
			.name = "invalid/local-date/feb-29",
			.input = "\"not a leap year\" = 2100-02-29",
		},
		{
			.name = "invalid/local-date/feb-30",
			.input = "\"only 28 or 29 days in february\" = 1988-02-30",
		},
		{
			.name = "invalid/local-datetime/feb-29",
			.input = "\"not a leap year\" = 2100-02-29T15:15:15",
		},
		{
			.name = "invalid/local-datetime/feb-30",
			.input = "\"only 28 or 29 days in february\" = 1988-02-30T15:15:15",
		},
		{
			.name = "invalid/local-datetime/hour-over",
			.input = "d = 2006-01-01T24:00:00", // hour 00-23
		},
		{
			.name = "invalid/local-time/hour-over",
			.input = "d = 24:00:00", // hour 00-23
		},
		{
			.name = "invalid/key/newline-4",
			.input = "\"\"\"long\nkey\"\"\" = 1",
		},
		{
			.name = "invalid/key/newline-5",
			.input = "'''long\nkey''' = 1",
		},
		{
			.name = "invalid/integer/negative-bin",
			.input = "negative-bin = -0b11010110",
		},
		{
			.name = "invalid/integer/negative-hex",
			.input = "negative-hex = -0xff",
		},
		{
			.name = "invalid/integer/negative-oct",
			.input = "negative-oct = -0o755",
		},
		{
			.name = "invalid/integer/positive-hex",
			.input = "positive-hex = +0xff",
		},
		{
			.name = "invalid/integer/trailing-us",
			.input = "trailing-us = 123_",
		},
		{
			.name = "invalid/integer/trailing-us-hex",
			.input = "trailing-us-hex = 0x1_",
		},
		{
			.name = "invalid/integer/us-after-hex",
			.input = "us-after-hex = 0x_1",
		},
		{
			.name = "invalid/integer/leading-zero-1",
			.input = "leading-zero-1 = 01",
		},
		{
			.name = "invalid/integer/leading-zero-2",
			.input = "leading-zero-2 = 00",
		},
		{
			.name = "invalid/integer/leading-zero-3",
			.input = "leading-zero-3 = 0_0",
		},
		{
			.name = "invalid/integer/leading-zero-sign-1",
			.input = "leading-zero-sign-1 = -01",
		},
		{
			.name = "invalid/integer/leading-zero-sign-2",
			.input = "leading-zero-sign-1 = +01",
		},
		{
			.name = "invalid/integer/leading-zero-sign-3",
			.input = "leading-zero-sign-1 = +0_1",
		},
		{
			.name = "invalid/inline-table/trailing-comma",
			.input = "abc = { abc = 123, }", // not permitted at end of inline table
		},
		{
			.name = "invalid/inline-table/double-comma",
			.input = "t = { x=3,,y=4 }", // not permitted at end of inline table
		},
		{
			.name = "invalid/float/trailing-point",
			.input = "trailing-point = 1.",
		},
		{
			.name = "invalid/float/trailing-point-min",
			.input = "trailing-point = -1.",
		},
		{
			.name = "invalid/datetime/offset-overflow-hour",
			.input = "d = 1985-06-18 17:04:07+25:00", // off-hour: 0-24
		},
		{
			.name = "invalid/datetime/offset-overflow-hour",
			.input = "d = 1985-06-18 17:04:07+12:61", // off-min: 0-60
		},
		{
			.name = "invalid/array/no-comma-2",
			.input = "no-comma = [ 1 2 3 ]",
		},
	};

	foreach (t : invalid_tests)
	{
		toml::parser::Parser p;
		p.init(t.input, tmem);
		assert(!@ok(p.toml()), "unittest '%s' should fail.", t.name);
	}
}
