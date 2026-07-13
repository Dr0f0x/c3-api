module c3api::config;

import std::io;
import std::io::os;
import std::io::file;
import std::io::path;
import std::collections::object;
import std::encoding::json;

struct Config {
    String address;
    uint port;
    Object* cors;
}

fn Config readFromFile() {
    @pool() {
        Path path = path::cwd(mem)!!;
        path = path.append(mem,"config.json")!!;

        if (!path::is_file(path)) {
            io::printn("Creating config file...");
			
			
			File? file = file::open_path(path, "w");
			if (catch err = file) {
				io::printn(err);
				return {};
			}

            file.write(
			`{
				"address": "127.0.0.1",
				"port": 8080,
				"cors": {
					"enabled": false,
					"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
					"Access-Control-Allow-Headers": "Content-Type",
					"Access-Control-Allow-Origin": "*"
				}
			}`)!!;
            file.flush()!!;
            file.close()!!;
        }

        File file = file::open_path(path, "r")!!;

		sz size = file::get_size(path)!!;
		char[] buffer = mem::new_array(char, size + 1);
		defer {
			mem::free(buffer);
		}
		sz read = file.read(buffer)!!;
		buffer[read] = 0;
		
		
		String content = (String)buffer[:read];
        Object* json = json::parse(mem, content)!!;
        file.flush()!!;
        file.close()!!;

        Config config = {.address = json.get_string("address")??"", .port = json.get_uint("port") ?? 0, .cors = json.get_or_create_obj("cors")};

        free(json);
        return config;
    };
}