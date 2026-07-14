module c3api::log;

import std::io;

interface LogSink
{
	fn void write(LogEntry* entry);

	fn void? sync();

	fn void set_encoder(EncoderFunc encoder);
}

struct ConsoleSink (LogSink)
{
	EncoderFunc encoder;
}

fn ConsoleSink* ConsoleSink.init(&self)
{
	self.encoder = &plain_encode;
	return self;
}

fn void ConsoleSink.write(&self, LogEntry* entry) @dynamic
{
	@pool()
	{
		String encoded = self.encoder(tmem, entry);
		if (entry.level > LogLevel.ERROR)
		{
			io::eprint(encoded);
		}
		else
		{
			io::printn(encoded);
		}
	};
}

fn void? ConsoleSink.sync(&self) @dynamic
{
	io::stdout().flush()!;
}

fn void ConsoleSink.set_encoder(&self, EncoderFunc encoder) @dynamic
{
	self.encoder = encoder;
}

fn void ConsoleSink.free(&self)
{
	self.sync()!!;
}

struct FileSink (LogSink)
{
	File file;
	EncoderFunc encoder;
}

fn FileSink*? FileSink.init(&self, Path file, bool from_cwd = true, bool create_if_missing = true)
{
	@pool()
	{
		self.encoder = &json_encode;

		Path actual_path;
		if (from_cwd)
		{
			Path cwd = path::tcwd()!;
			actual_path = cwd.tappend(file)!;
		}
		else
		{
			actual_path = file;
		}

		if (!path::is_file(actual_path) && !create_if_missing)
		{
			return io::FILE_NOT_FOUND~;
		}

		self.file = file::open_path(actual_path, "a")!;
		return self;
	};
}

fn void FileSink.write(&self, LogEntry* entry) @dynamic
{
	@pool()
	{
		String encoded = self.encoder(tmem, entry);
		self.file.write(encoded)!!;
		self.file.write("\n")!!;
	};
}

fn void? FileSink.sync(&self) @dynamic
{
	self.file.flush()!;
}

fn void FileSink.set_encoder(&self, EncoderFunc encoder) @dynamic
{
	self.encoder = encoder;
}

fn void FileSink.free(&self)
{
	self.sync()!!;
	self.file.close()!!;
}
