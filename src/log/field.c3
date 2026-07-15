module c3api::log;

struct Field
{
	String name;
	any value;
}

macro Field _field(String name, $Type, value)
{
	return { name, any_make(value, $Type) };
}

fn Field _string(String name, String* val) @inline
{
	return _field(name, String, val);
}

fn Field _bool(String name, bool* val) @inline
{
	return _field(name, bool, val);
}

fn Field _char(String name, char* val) @inline
{
	return _field(name, char, val);
}

fn Field _short(String name, short* val) @inline
{
	return _field(name, short, val);
}

fn Field _int(String name, int* val) @inline
{
	return _field(name, int, val);
}

fn Field _long(String name, long* val) @inline
{
	return _field(name, long, val);
}

fn Field _ushort(String name, ushort* val) @inline
{
	return _field(name, ushort, val);
}

fn Field _uint(String name, uint* val) @inline
{
	return _field(name, uint, val);
}

fn Field _ulong(String name, ulong* val) @inline
{
	return _field(name, ulong, val);
}

fn Field _usz(String name, usz* val) @inline
{
	return _field(name, usz, val);
}

fn Field _float(String name, float* val) @inline
{
	return _field(name, float, val);
}

fn Field _double(String name, double* val) @inline
{
	return _field(name, double, val);
}

fn Field _fault(String name, fault* val) @inline
{
	return _field(name, fault, val);
}

fn Field _error(fault* err) @inline
{
	return _field("error", fault, err);
}

fn any[] values(Allocator allocator, Field[] fields)
{
	any[] value_arr = alloc::new_array(allocator, any, fields.len);
	foreach (index, Field field : fields)
	{
		value_arr[index] = fields[index].value;
	}
	return value_arr;
}

fn String[] names(Allocator allocator, Field[] fields)
{
	String[] name_arr = alloc::new_array(allocator, String, fields.len);
	foreach (index, Field field : fields)
	{
		name_arr[index] = fields[index].name;
	}
	return name_arr;
}
