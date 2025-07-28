module toml::lexer_test;

import toml::lexer;
import std::math;

struct TestCase @local
{
	String name;
	String input;
	Token[] tokens;
}

fn void test_lexer() @test
{
	TestCase[*] tests = {
		{
			.name   = "identifier",
			.input  = "abc",
			.tokens = { { .type = IDENTIFIER, .value = "abc" }, },
		},
		{
			.name   = "basic-string",
			.input  = "\"abc\"",
			.tokens = { { .type = STRING, .value = "abc" }, },
		},
		{
			.name   = "literal-string",
			.input  = "'abc'",
			.tokens = { { .type = STRING, .value = "abc" }, },
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
			.tokens = { { .type = INTEGER, .value = "123" }, },
		},
		{
			.name   = "plus-integer",
			.input  = "+123",
			.tokens = { { .type = INTEGER, .value = "+123" }, },
		},
		{
			.name   = "minus-integer",
			.input  = "-123",
			.tokens = { { .type = INTEGER, .value = "-123" }, },
		},
		{
			.name   = "minus-float",
			.input  = "-1.23e-20",
			.tokens = { { .type = FLOAT, .value = "-1.23e-20" }, },
		},
		{
			.name   = "plus-float",
			.input  = "1.23e+20",
			.tokens = { { .type = FLOAT, .value = "1.23e+20" }, },
		},
		{
			.name   = "nan",
			.input  = "nan",
			.tokens = { { .type = FLOAT, .value = "nan" }, },
		},
		{
			.name   = "minus-nan",
			.input  = "-nan",
			.tokens = { { .type = FLOAT, .value = "-nan" }, },
		},
		{
			.name   = "plus-nan",
			.input  = "+nan",
			.tokens = { { .type = FLOAT, .value = "+nan" }, },
		},
		{
			.name   = "inf",
			.input  = "inf",
			.tokens = { { .type = FLOAT, .value = "inf" }, },
		},
		{
			.name   = "minus-inf",
			.input  = "-inf",
			.tokens = { { .type = FLOAT, .value = "-inf" }, },
		},
		{
			.name   = "plus-inf",
			.input  = "+inf",
			.tokens = { { .type = FLOAT, .value = "+inf" }, },
		},
		{
			.name   = "date-only",
			.input  = "2002-02-02",
			.tokens = { { .type = DATETIME, .value = "2002-02-02" }, },
		},
		{
			.name   = "time-only",
			.input  = "20:02:02",
			.tokens = { { .type = DATETIME, .value = "20:02:02" }, },
		},
		{
			.name   = "local-date-time with space",
			.input  = "2006-01-02 15:04:05",
			.tokens = { { .type = DATETIME, .value = "2006-01-02 15:04:05" }, },
		},
		{
			.name   = "local-date-time with T",
			.input  = "2006-01-02T15:04:05",
			.tokens = { { .type = DATETIME, .value = "2006-01-02T15:04:05" }, },
		},
		{
			.name   = "rfc3999",
			.input  = "2006-01-02T15:04:05.999999Z",
			.tokens = { { .type = DATETIME, .value = "2006-01-02T15:04:05.999999Z" }, },
		},
		{
			.name   = "bool-true",
			.input  = "true",
			.tokens = { { .type = BOOLEAN, .value = "true" }, },
		},
		{
			.name   = "bool-false",
			.input  = "false",
			.tokens = { { .type = BOOLEAN, .value = "false" }, },
		},
		{
			.name   = "comment",
			.input  = "# -12 comment",
			.tokens = { { .type = COMMENT, .value = "# -12 comment" }, },
		},
		{
			.name   = "name = John",
			.input  = "name = \"John\"\n",
			.tokens = {
				{ .type = IDENTIFIER, .value = "name" },
				{ .type = EQUALS, .value = "" },
				{ .type = STRING, .value = "John" },
				{ .type = NEWLINE, .value = "" },
			},
		},
		{
			.name   = "mini-table",
			.input  = "[   table\t]",
			.tokens = {
				{ .type = SQUAREOPEN, .value = "" },
				{ .type = IDENTIFIER, .value = "table" },
				{ .type = SQUARECLOSE, .value = "" },
			},
		},
		{
			.name   = "array-of-table",
			.input  = "[[]]",
			.tokens = {
				{ .type = ARRAYTABLEOPEN, .value = "" },
				{ .type = ARRAYTABLECLOSE, .value = "" },
			},
		},
		// FIXME: I come to the conclusion here, that lexing is not the best
		// approach to parsing a toml file ..
		// {
		// 	.name   = "dotted-key",
		// 	.input  = "abc . 123.\"john\"",
		// 	.tokens = {
		// 		{ .type = IDENTIFIER, .value = "abc" },
		// 		{ .type = DOT, .value = "" },
		// 		{ .type = NUMBER, .value = "123" },
		// 		{ .type = DOT, .value = "" },
		// 		{ .type = STRING, .value = "John" },
		// 	},
		// },
	};

	foreach (tc : tests)
	{
		Lexer lexer;
		lexer.init(tc.input);

		foreach (i, want_token : tc.tokens)
		{
			Token got = lexer.next_token();
			assert(got.type == want_token.type,
				"[test: %s -- item: %d]  token types do not match; got: %s, want: %s",
				tc.name, i+1, got.type, want_token.type);
			assert(got.value == want_token.value,
				"[test: %s -- item %d] token values do not match; got: '%s', want: '%s'",
				tc.name, i+1, got.value, want_token.value);
		}
	}
}
