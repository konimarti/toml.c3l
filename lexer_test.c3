module toml::lexer_test;

import toml::lexer;
import std::math;

struct TestCase @local
{
	String name;
	String input;
	Token[] tokens;
}

fn bool same_token(Token a, Token b)
{
	if (a.type != b.type) return false;
	switch (a.type)
	{
		case STRING:
		case IDENTIFIER:
		case DATETIME:
			return a.s == b.s;
		case INTEGER:
			return a.int64 == b.int64;
		case FLOAT:
			return math::abs(a.fp64 - b.fp64) < 1e-8;
		case BOOLEAN:
			return a.b == b.b;
		default:
			return false;
	}
}

fn void test_lexer() @test
{
	TestCase[*] tests = {
		{
			.name   = "identifier",
			.input  = "abc",
			.tokens = { { .type = IDENTIFIER, .s = "abc" }, },
		},
		{
			.name   = "basic-string",
			.input  = "\"abc\"",
			.tokens = { { .type = STRING, .s = "abc" }, },
		},
		{
			.name   = "literal-string",
			.input  = "'abc'",
			.tokens = { { .type = STRING, .s = "abc" }, },
		},
		// TODO: multiline not implemented yet
		// {
		// 	.name   = "multiline-quoted-string",
		// 	.input  = `"""abc"""`,
		// 	.tokens = { { .type = STRING, .s = "abc" }, },
		// },
		// TODO: multiline not implemented yet
		// {
		// 	.name   = "multiline-literal-string",
		// 	.input  = "'''abc'''",
		// 	.tokens = { { .type = STRING, .s = "abc" }, },
		// },
		{
			.name   = "integer",
			.input  = "123",
			.tokens = { { .type = INTEGER, .int64 = 123 }, },
		},
		{
			.name   = "plus-integer",
			.input  = "+123",
			.tokens = { { .type = INTEGER, .int64 = 123 }, },
		},
		{
			.name   = "minus-integer",
			.input  = "-123",
			.tokens = { { .type = INTEGER, .int64 = -123 }, },
		},
		{
			.name   = "minus-float",
			.input  = "-1.23e-20",
			.tokens = { { .type = FLOAT, .fp64 = -1.23e-20 }, },
		},
		{
			.name   = "plus-float",
			.input  = "1.23e+20",
			.tokens = { { .type = FLOAT, .fp64 = 1.23e+20 }, },
		},
		// FIXME
		// {
		// 	.name   = "nan",
		// 	.input  = "-nan",
		// 	.tokens = { { .type = FLOAT, .fp64 = -double.nan }, },
		// },
	};

	foreach (tc : tests)
	{
		Lexer lexer;
		lexer.init(tc.input);

		foreach (want_token : tc.tokens)
		{
			Token got = lexer.next_token();
			assert(got.type == want_token.type,
				"[%s] token types do not match; got: %s, want: %s",
				tc.name, got.type, want_token.type);
			assert(same_token(got, want_token),
				"[%s] token values do not match ('%s' vs '%s', '%f' vs '%f')", tc.name, got.s, want_token.s, got.fp64, want_token.fp64);
		}
	}
}
