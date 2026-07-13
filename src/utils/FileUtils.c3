module c3api::utils;

import std::collections::map;

fn String? format_path(String format, HashMap{String, String}* args) {
    @pool() {
        foreach (String key: args.key_iter()) {
            DString _placeholder = dstring::new(mem);
            _placeholder.appendf("{%s}", key);
            String placeholder = _placeholder.str_view();
            _placeholder.free();
            if (format.contains(placeholder)) {
                String[] split = format.split(mem, placeholder);
                DString new = dstring::join(mem, split, args.get(key)!!);
                format = new.str_view();
                new.free();
            }
        }

        return format;
    };
}
