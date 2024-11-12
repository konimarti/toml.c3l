module toml::parser

import std::collections::object;

// integer = dec-int / hex-int / oct-int / bin-int
// minus = 0x2D
// plus = 0x2B
// underscore = 0x5F
// hex-prefix = 0x
// oct-prefix = 0o
// bin-prefix = 0b
//
// dec-int = [ minus / plus ] unsigned-dec-int
// unsigned-dec-int = DIGIT / digit1-9 1*( DIGIT / underscore DIGIT )
//
// hex-int = hex-prefix HEXDIG *( HEXDIG / underscore HEXDIG )
// oct-int = oct-prefix digit0-7 *( digit0-7 / underscore digit0-7 )
// bin-int = bin-prefix digit0-1 *( digit0-1 / underscore digit0-1 )
//
// float = float-int-part ( exp / frac [ exp ] )
// float = special-float
//
// float-int-part = dec-int
// frac = decimal-point zero-prefixable-int
// decimal-point = 0x2E ; .
// zero-prefixable-int = DIGIT *( DIGIT / underscore DIGIT )
//
// exp = "e" float-exp-par
// float-exp-part = [ minux / plus ] zero-prefixable-int
//
// special-float = [ minus / plus ] ( inf / nan )

fn Object*! Parser.number_or_datetime()
{
	int integer = self.integer()!;

}

fn int Parser.hex_int(&self)
{
	DString s;
	s.new_init(8, self.allocator);
	defer s.free();

	s.append_chars("0x");
	
	char c;
	while LOOP: (1)
	{
		c = self.peek();
		switch
		{
			case c.is_xdigit(): 
				s.append_char(self.advance()!);
			case c == '_':
				self.advance()!;
			default:
				break LOOP;
		}
	}
	return s.str_view().to_int();
}

fn int Parser.oct_int(&self)
{
	DString s;
	s.new_init(8, self.allocator);
	defer s.free();

	s.append_chars("0o");
	
	char c;
	while LOOP: (1)
	{
		c = self.peek();
		switch
		{
			case c.is_odigit(): 
				s.append_char(self.advance()!);
			case c == '_':
				self.advance()!;
			default:
				break LOOP;
		}
	}
	return s.str_view().to_int();
}

fn int Parser.bin_int(&self)
{
	DString s;
	s.new_init(8, self.allocator);
	defer s.free();

	s.append_chars("0b");
	
	char c;
	while LOOP: (1)
	{
		c = self.peek();
		switch
		{
			case c.is_bdigit(): 
				s.append_char(self.advance()!);
			case c == '_':
				self.advance()!;
			default:
				break LOOP;
		}
	}
	return s.str_view().to_int();
}

fn int! Parser.integer(bool *is_number)
{
	switch (self.peek())
	{
		case '+':
		case '-':
		case '1'..'9':
			is_number = true;
			return self.dec_int();
		case '0':
			switch (self.peek())
			{
				case 'x':
					is_number = true;
					return self.hex_int();
				case 'o':
					is_number = true;
					return self.oct_int();
				case 'b':
					is_number = true;
					return self.bin_int();
				default:
					if (!self.peek().is_digit())
					{
						is_number = true;
						return 0;
					}
			}
	}

	is_number = false;
	return 0;
}

