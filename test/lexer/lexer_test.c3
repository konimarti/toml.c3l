module toml_test @test;

import toml;
import std::io;
import std::collections::object;

fn void! test_lexer() @test
{
	TokenList *tokens = Lexer{}.init(`
	[table]
	fruit.apply.color = green
	`, allocator::temp()).scan_tokens()!;
	defer tokens.free();

	io::printn("lexer:");
	foreach (tok : tokens) io::print(tok);
}
