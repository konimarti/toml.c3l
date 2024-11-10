module toml_test @test;

import toml;
import std::io;
import std::collections::object;

fn void! test_lexer() @test
{
	Lexer lex;	
	lex.init(ByteReader{}.init(`
	[table]
	fruit.apply.color = green
	`), allocator::temp());

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
