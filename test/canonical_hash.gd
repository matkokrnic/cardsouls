class_name CanonicalHash
extends RefCounted

## Deterministic hash of a snapshot Dictionary for the item-4 determinism regression.
## Serializes with RECURSIVELY SORTED KEYS (never insertion order — that hashes stable in
## practice and breaks silently when order changes) and fixed float precision, then SHA-256.

static func of(value: Variant) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(canonical(value).to_utf8_buffer())
	return ctx.finish().hex_encode()


static func canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			var parts: Array[String] = []
			for k in keys:
				parts.append(str(k) + ":" + canonical(value[k]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var parts: Array[String] = []
			for e in value:
				parts.append(canonical(e))
			return "[" + ",".join(parts) + "]"
		TYPE_VECTOR2:
			return "V2(%s,%s)" % [_f(value.x), _f(value.y)]
		TYPE_VECTOR3:
			return "V3(%s,%s,%s)" % [_f(value.x), _f(value.y), _f(value.z)]
		TYPE_FLOAT:
			return _f(value)
		TYPE_BOOL:
			return "true" if value else "false"
		_:
			return str(value)


static func _f(x: float) -> String:
	return "%.6f" % x
