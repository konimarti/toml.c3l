module toml;

import std::io;
import std::collections::map;
import std::collections::object;

faultdef UNSUPPORTED_TYPE;

macro void? unmarshal_obj(t, m)
{
	var $Type = $typeof(*t);

	$foreach $x : $Type.membersof:

		// io::printn("-------");
		// io::printfn("nameof: %s", $x.nameof);
		// io::printfn("kindof: %s", $x.kindof);
		// io::printfn("typeid: %s", $x.typeid.nameof);
		// io::printfn("get value of membersof $x: %s", $x.get(*t));

		if (m.has_key($x.nameof))
		{

		$switch $x.kindof:

		$case TypeKind.STRUCT:

			unmarshal_obj(&$x.get(*t), m.get($x.nameof)!)!;

		$case TypeKind.VECTOR:
		$case TypeKind.ARRAY:

			Object* arr = m.get($x.nameof)!;
			if (!arr.is_array())
			{
				io::eprintfn("TOML Unmarshal Error: should field '%s' really be an array?", $x.nameof);
				return UNSUPPORTED_TYPE?;
			}

			var $ElementType = $typefrom($x.typeid.inner);

			// io::printfn("array.len (Type): %d", $x.typeid.len);
			// io::printfn("array.len (Object): %d", arr.get_len());
			// io::printfn("type of array: %s", $x.typeid.nameof);
			// io::printfn("type of array[0]: %s", $x.typeid.inner.nameof);
			// io::printfn("type of array[0]: %s", $ElementType.nameof);

			$if $ElementType.typeid == Object*.typeid:
				usz n = min(arr.get_len(), $x.typeid.len);
				if (n < arr.get_len())
				{
					io::eprintfn("TOML Unmarshal Warning: target array is smaller than config values!", $x.nameof);
				}
				for (usz i = 0; i < n; i++)
				{
					$x.get(*t)[i] = arr.get_at(i);
				}
			$else
				io::eprintfn("TOML Unmarshal Error: type of field '%s' is unsupported; use 'Object*' instead.", $x.nameof);
				return UNSUPPORTED_TYPE?;
			$endif

		$default:

			var $TargetType = $typefrom($x.typeid);
			String $name = $x.nameof;

			$switch:

				$case types::is_int($TargetType):

					t.$eval($name) = m.get_int($name)!;

				$case types::is_float($TargetType):

					t.$eval($name) = m.get_float($name)!;

				$case types::is_bool($TargetType):

					t.$eval($name) = m.get_bool($name)!;

				$case $TargetType.typeid == String.typeid:

					t.$eval($name) = m.get_string($name)!;

			$default:

				t.$eval($name) = m.get($name)!;

			$endswitch

		$endswitch

		}

	$endforeach
}
