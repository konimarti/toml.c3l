module toml;

import std::io;
import std::collections::map;
import std::collections::object;

fault MarshalError
{
	UNSUPPORTED_TYPE,
}

macro void! @unmarshal_obj(&t, m)
{
	var $Type = $typeof(*t);

	$foreach ($x : $Type.membersof)

		// io::printn("-------");
		// io::printfn("nameof: %s", $x.nameof);
		// io::printfn("kindof: %s", $x.kindof);
		// io::printfn("typeid: %s", $x.typeid.nameof);

		if (m.has_key($x.nameof))
		{

		$switch ($x.kindof)

		$case TypeKind.STRUCT:

			@unmarshal_obj(t.$eval($x.nameof), m.get($x.nameof)!)!;

		$case TypeKind.VECTOR:
		$case TypeKind.ARRAY:

			Object* arr = m.get($x.nameof)!;
			if (!arr.is_array())
			{
				io::eprintfn("TOML Unmarshal Error: should field '%s' really be an array?", $x.nameof);
				return MarshalError.UNSUPPORTED_TYPE?;
			}

			var $ElementType = $typeof(t.$eval($x.nameof)[0]);

			// io::printfn("array.len (Type): %d", $x.typeid.len);
			// io::printfn("array.len (Object): %d", arr.get_len());
			// io::printfn("array[0].type: %s", $ElementType.nameof);

			$if $ElementType.typeid == Object*.typeid:
				usz n = min(arr.get_len(), $x.typeid.len);
				if (n < arr.get_len())
				{
					io::eprintfn("TOML Unmarshal Warning: target array is smaller than config values!", $x.nameof);
				}
				for (usz i = 0; i < n; i++)
				{
					t.$eval($x.nameof)[i] = arr.get_at(i);
				}
			$else
				io::eprintfn("TOML Unmarshal Error: type of field '%s' is unsupported; use 'Object*' instead.", $x.nameof);
				return MarshalError.UNSUPPORTED_TYPE?;
			$endif

		$default:

			var $TargetType = $typeof(t.$eval($x.nameof));

			$switch

				$case types::is_int($TargetType):

					t.$eval($x.nameof) = m.get_int($x.nameof)!;

				$case types::is_float($TargetType):

					t.$eval($x.nameof) = m.get_float($x.nameof)!;

				$case types::is_bool($TargetType):

					t.$eval($x.nameof) = m.get_bool($x.nameof)!;

				$case $TargetType.typeid == String.typeid:

					t.$eval($x.nameof) = m.get_string($x.nameof)!;

			$default:

				t.$eval($x.nameof) = m.get($x.nameof)!;

			$endswitch

		$endswitch

		}

	$endforeach
}
