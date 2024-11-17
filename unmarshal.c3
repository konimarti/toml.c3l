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

		// io::printfn("nameof: %s", $x.nameof);
		// io::printfn("kindof: %s", $x.kindof);
		// io::printfn("typeid: %s", $x.typeid.nameof);

		$switch ($x.kindof)

		$case TypeKind.STRUCT:

			@unmarshal_obj(t.$eval($x.nameof), m.get($x.nameof)!)!;

		$case TypeKind.ARRAY:

			// TODO: handle arrays
			io::eprintfn("TOML Unmarshal error: type of field '%s' is unsupported; use 'Object*' instead.", $x.nameof);
			return MarshalError.UNSUPPORTED_TYPE?;

		$default:

			if (m.has_key($x.nameof))
			{
				var $XType = $typeof(t.$eval($x.nameof));

				$switch

					$case types::is_int($XType):

						t.$eval($x.nameof) = m.get_int($x.nameof)!;

					$case types::is_float($XType):

						t.$eval($x.nameof) = m.get_float($x.nameof)!;

					$case types::is_bool($XType):

						t.$eval($x.nameof) = m.get_bool($x.nameof)!;

					$case $XType.typeid == String.typeid:

						t.$eval($x.nameof) = m.get_string($x.nameof)!;

				$default:

					t.$eval($x.nameof) = m.get($x.nameof)!;

				$endswitch

			}

		$endswitch

	$endforeach
}
