module c3api::log;

struct Field
{
	String name;
	any value;
}

fn Field field(String name, any value)
{
	return { name, value };
}


macro Field _field_value(String name, $Type, value)
{
	$Type* p = alloc::new(tmem, $Type);
	*p = value;
	return { name, any_make(p, $Type) };
}

fn Field _string(String name, String val)
{
	return _field_value(name, String, val);
}

fn Field _bool(String name, bool val)
{
	return _field_value(name, bool, val);
}

fn Field _char(String name, char val)
{
	return _field_value(name, char, val);
}

fn Field _short(String name, short val)
{
	return _field_value(name, short, val);
}

fn Field _int(String name, int val)
{
	return _field_value(name, int, val);
}

fn Field _long(String name, long val)
{
	return _field_value(name, long, val);
}

fn Field _ushort(String name, ushort val)
{
	return _field_value(name, ushort, val);
}

fn Field _uint(String name, uint val)
{
	return _field_value(name, uint, val);
}

fn Field _ulong(String name, ulong val)
{
	return _field_value(name, ulong, val);
}

fn Field _usz(String name, usz val)
{
	return _field_value(name, usz, val);
}

fn Field _float(String name, float val)
{
	return _field_value(name, float, val);
}

fn Field _double(String name, double val)
{
	return _field_value(name, double, val);
}

fn Field _fault(String name, fault val)
{
	return _field_value(name, fault, val);
}

fn Field _error(fault err)
{
	return _field_value("error", fault, err);
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
