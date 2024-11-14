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

fn void! test_parser_toml_doc() @test
{
	toml::parser::Parser scan;	
	scan.init(TOML_DOC, allocator::temp());
	Object* obj = scan.toml()!;
	//io::printn(obj);

	Object* owner = obj.get("owner")!;
	Object* database = obj.get("database")!;
	Object* ports = database.get("ports")!;
	Object* temp = database.get("temp_targets")!;

	Object* servers = obj.get("servers")!;
	Object* alpha = servers.get("alpha")!;
	Object* beta = servers.get("beta")!;

	assert(obj.get_string("title")! == "TOML Example");
	assert(owner.get_string("name")! == "Tom Preston-Werner");
	assert(owner.get_string("dob")! == "1979-05-27T07:32:00-08:00");

	assert(database.get_bool("enabled")! == true);
	assert(database.get_bool("enabled")! == true);

	assert(ports.get_len() == 3);
	assert(ports.get_int_at(0)! == 8000);
	assert(ports.get_int_at(1)! == 8001);
	assert(ports.get_int_at(2)! == 8002);

	assert(@catch(database.get("data")) == SearchResult.MISSING);

	assert(math::abs(temp.get_float("cpu")! - 79.5) < math::FLOAT_EPSILON);
	assert(math::abs(temp.get_float("case")! - 72.0) < math::FLOAT_EPSILON);

	assert(alpha.get_string("ip")! == "10.0.0.1");
	assert(alpha.get_string("role")! == "frontend");

	assert(beta.get_string("ip")! == "10.0.0.2");
	assert(beta.get_string("role")! == "backend");
}

struct StringTestCase
{
	String name;
	String input;
	String want;
}

fn void! parser_value_string() @test
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
		String s = p.init(t.input, allocator::temp()).string()!.s;
		assert(s == t.want,
			"test %d [%s]: got: %s, but want: %s",
				i+1, t.name, s, t.want);
	}
}

fn void! parser_array_tables() @test
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
		allocator::temp(),
	);

	Object* obj = p.toml()!;
	// io::printn(obj);
	assert(obj.get("product")!.get_len() == 3,
		"array_tables: incorrect array length");
}

fn void! parser_inline_tables() @test
{
	toml::parser::Parser p;
	p.init(
	`widget = { color = "green", price = 3.14, vendors = ["abc", "def"]}`,
		allocator::temp(),
	);

	Object* obj = p.toml()!;
	// io::printn(obj);

	Object* widget = obj.get("widget")!;
	Object* vendors = widget.get("vendors")!;

	assert(widget.get_string("color")! == "green");
	assert(widget.get_float("price")! == 3.14);
	assert(vendors.get_len() == 2);
	assert(vendors.get_string_at(1)! == "def");
}

struct IntegerTestCase
{
	String name;
	String input;
	int want;
}

fn void! parser_value_integer() @test
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
			.input = `0XbEeF`,
			.want = 48879,
		},
		{
			.name = "hex-int with underscore",
			.input = `0Xbe_ef`,
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
		p.init(t.input, allocator::temp());
		Object *integer = p.number_or_datetime()!;
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

fn void! parser_value_float() @test
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
		p.init(t.input, allocator::temp());
		Object *real = p.number_or_datetime()!;
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
