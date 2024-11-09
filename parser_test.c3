module toml_test @test;

import toml;
import std::io;
import std::collections::object;

fn void! test_parser() @test
{
	toml::parser::Parser scan;	
	scan.init(ByteReader{}.init(`shipping.cost={boat=100.0, ml="""\nhello\nworld""""", cabin=0xdead, sell=true}
	[basket]
	fruit.apply.color = [1.2, 'literal', "quotedstring",true, [1 #shesd
	,2
	# comment
	,3,]] 
	`),
	allocator::temp());

	io::printn("parser:");

	Object* obj = scan.toml()!;
	io::printn(obj);
}

fn void! test_parser_toml_doc() @test
{
	toml::parser::Parser scan;	
	scan.init(ByteReader{}.init(`
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
	`),
	allocator::temp());

	io::printn("parser:");

	Object* obj = scan.toml()!;
	io::printn(obj);
}

fn void! parser_read_quoted_str() @test
{
	DString s;
	s.new_init();
	toml::parser::Parser{}.init(
		ByteReader{}.init(`"quoted\"string"rest`),
		allocator::temp(),
	).read_quoted_string(&s)!;

	String want = "quoted\"string";
	assert(s.str_view() == want, "got: %s, but want: %s", s.str_view(), want);
	s.free();
}

fn void! parser_array_tables() @test
{
	DString s;
	s.new_init();
	toml::parser::Parser p;
	p.init(
		ByteReader{}.init(`
		[[product]]
		widget.color = "green"
		widget.price = 3.14
		[[product]]
		[[product]]
		widget.color = "blue"
		widget.price = 2.71
		`),
		allocator::temp(),
	);

	Object* obj = p.toml()!;
	io::printn(obj);
	assert(obj.get("product")!.get_len() == 3, "not enough elements in array");
}
