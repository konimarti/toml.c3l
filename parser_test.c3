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
