module toml;

import std::io, std::collections::map, std::collections::object;

faultdef UNSUPPORTED_TYPE;

macro toml_decode_to_type($Type, toml) @private
{
	$Type t;

	$foreach $x : $Type.membersof:

		// io::printn("-------");
		// io::printfn("nameof: %s", $x.nameof);
		// io::printfn("kindof: %s", $x.kindof);
		// io::printfn("typeid: %s", $x.typeid.nameof);
		// io::printfn("get value of membersof $x: %s", $x.get(*t));

		if (toml.has_key($x.nameof))
		{

		$switch $x.kindof:

		$case TypeKind.STRUCT:

			t.$eval($x.nameof) = toml_decode_to_type($typefrom($x.typeid), toml.get($x.nameof)!)!;

		$case TypeKind.VECTOR:
		$case TypeKind.ARRAY:

			Object* arr = toml.get($x.nameof)!;
			if (!arr.is_array())
			{
				io::eprintfn("TOML Decode Error: should field '%s' really be an array?", $x.nameof);
				return UNSUPPORTED_TYPE~;
			}

			var $ElementType = $typefrom($x.typeid.inner);

			// io::printfn("array.len (Type): %d", $x.typeid.len);
			// io::printfn("array.len (Object): %d", arr.get_len());
			// io::printfn("type of array: %s", $x.typeid.nameof);
			// io::printfn("type of array[0]: %s", $x.typeid.inner.nameof);
			// io::printfn("type of array[0]: %s", $ElementType.nameof);

			$if $ElementType.typeid == Object*.typeid:
				if (arr.get_len() != $x.typeid.len)
				{
					io::eprintfn("TOML Decode Warning: array lengths differ for %s.", $x.nameof);
				}
				usz n = min(arr.get_len(), $x.typeid.len);
				if (n < arr.get_len())
				{
					io::eprintfn("TOML Decode Warning: target array is smaller than config values: %s", $x.nameof);
				}
				for (usz i = 0; i < n; i++)
				{
					$x.get(t)[i] = arr.get_at(i);
				}
			$else
				io::eprintfn("TOML Decode Error: type of field '%s' is unsupported; use 'Object*' instead.", $x.nameof);
				return UNSUPPORTED_TYPE~;
			$endif

		$default:

			var $TargetType = $typefrom($x.typeid);
			String $name = $x.nameof;

			$switch:

				$case types::is_int($TargetType):

					t.$eval($name) = toml.get_int($name)!;

				$case types::is_float($TargetType):

					t.$eval($name) = toml.get_float($name)!;

				$case types::is_bool($TargetType):

					t.$eval($name) = toml.get_bool($name)!;

				$case $TargetType.typeid == String.typeid:

					t.$eval($name) = toml.get_string($name)!;

			$default:

				t.$eval($name) = toml.get($name)!;

			$endswitch

		$endswitch

		}

	$endforeach

	return t;
}
