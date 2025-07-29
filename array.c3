module toml::parser;

import std::io;
import std::collections::object @public;

// array = array-open [ array-values ] ws-comment-newline array-close
// array-open = 0x5B ; [
// array-close = 0x5D ; ]
// array-values = ws-comment-newline val ws-comment newline array-sep array-values
// array-values = ws-comment-newline val ws-comment-newline [ array-sep ]
// array-sep = 0x2C ; ,
fn Object*? Parser.array(&self)
{
	// array-open
	self.must('[');

	Object* arr = object::new_obj(self.allocator);
	arr.init_array_if_needed();

	while LOOP: (1)
	{
		self.skip_ws_comment_newline()!;

		if (self.must(']')) break LOOP;

		arr.push_object(self.value()!);

		self.skip_ws_comment_newline()!;

		switch (self.peek())
		{
			case ',': self.advance()!; continue;
			case ']': self.advance()!; break LOOP;
			default: return INVALID_ARRAY?;
		}
	}

	return arr;

}
