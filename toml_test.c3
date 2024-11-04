module toml_test @test;

import toml;
import std::io;
import std::collections::object;

fn void! test_lexer() @test
{
	Lexer lex;	
	lex.init(ByteReader{}.init("fruit.apply.color = green"), allocator::temp());

	io::printn("lexer:");
	while LOOP: (1)
	{
		Token*! tok = lex.next_token();
		if (catch err = tok)
		{
			if (err == IoError.EOF) {
				io::printn(">> EOF received");
				break LOOP;
			}
			return err?;
		}
		io::print(tok);
	}
}

fn void! test_scanner() @test
{
	toml::scanner::Scanner scan;	
	scan.init(ByteReader{}.init("[basket]\nfruit.apply.color = green\n"), allocator::temp());

	io::printn("scanner:");

	Object* obj = scan.toml()!;
	io::printn(obj);
}
