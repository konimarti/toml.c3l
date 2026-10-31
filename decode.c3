module toml;

import std::io, std::collections::map, std::collections::object;

faultdef UNSUPPORTED_TYPE;

macro toml_decode_to_type($Type, toml) @private
{
	$Type t;

	$foreach $x : $Type::members:

		// io::printn("-------");
		// io::printfn("nameof: %s", $x.name);
		// io::printfn("kindof: %s", $x.type.kind);
		// io::printfn("typeid: %s", $x.typeid.nameof);
		// io::printfn("get value of membersof $x: %s", $x.get(*t));

		if (toml.has_key($x.name))
		{

		$switch $x.type.kind:

		$case STRUCT:

			t.$eval($x.name) = toml_decode_to_type($Typefrom($x.type), toml.get($x.name)!)!;

		$case VECTOR:
		$case ARRAY:

			Object* arr = toml.get($x.name)!;
			if (!arr.is_array())
			{
				io::eprintfn("TOML Decode Error: should field '%s' really be an array?", $x.name);
				return UNSUPPORTED_TYPE~;
			}

			var $ElementType = $Typefrom($x.type.inner);

			// io::printfn("array.len (Type): %d", $x.type.len);
			// io::printfn("array.len (Object): %d", arr.get_len());
			// io::printfn("type of array: %s", $x.typeid.nameof);
			// io::printfn("type of array[0]: %s", $x.typeid.inner.nameof);
			// io::printfn("type of array[0]: %s", $ElementType.nameof);

			$if $ElementType::typeid == Object*::typeid:
				if (arr.get_len() != $x.type.len)
				{
					io::eprintfn("TOML Decode Warning: array lengths differ for %s.", $x.name);
				}
				sz n = min(arr.get_len(), $x.type.len);
				if (n < arr.get_len())
				{
					io::eprintfn("TOML Decode Warning: target array is smaller than config values: %s", $x.name);
				}
				for (sz i = 0; i < n; i++)
				{
					t.$eval($x.name)[i] = arr.get_at(i);
				}
			$else
				io::eprintfn("TOML Decode Error: type of field '%s' is unsupported; use 'Object*' instead.", $x.name);
				return UNSUPPORTED_TYPE~;
			$endif

		$default:

			var $TargetType = $Typefrom($x.type);
			String $name = $x.name;

			$switch:

				$case types::is_int($TargetType):

					t.$eval($name) = toml.get_int($name)!;

				$case types::is_float($TargetType):

					t.$eval($name) = toml.get_float($name)!;

				$case types::is_bool($TargetType):

					t.$eval($name) = toml.get_bool($name)!;

				$case $TargetType::typeid == String::typeid:

					t.$eval($name) = toml.get_string($name)!;

			$default:

				t.$eval($name) = toml.get($name)!;

			$endswitch

		$endswitch

		}

	$endforeach

	return t;
}
