module c3api::log;

import std::io;

<*
 Destination for encoded log entries.
*>
interface LogSink
{
	<*
	 Write one log entry to the sink.

	 @param [in] entry : "Entry to write"
	*>
	fn void write(LogEntry* entry);

	<*
	 Flush any buffered output owned by the sink.
	*>
	fn void? sync();

	<*
	 Set the encoder used before writing entries.

	 @param encoder : "Encoder callback to apply to each entry"
	*>
	fn void set_encoder(EncoderFunc encoder);
}

<*
 Sink that writes entries to stdout/stderr.
*>
struct ConsoleSink (LogSink)
{
	EncoderFunc encoder;
}

<*
 Initialize the console sink with plain text encoding.

 @param encoder : "Encoder callback to apply to each entry"
 @return "Initialized console sink"
*>
fn ConsoleSink* ConsoleSink.init(&self, EncoderFunc encoder = &plain_encode)
{
	self.encoder = encoder;
	return self;
}

<*
 Encode and write a log entry to the console.

 Fatal and error entries are written to stderr; other levels go to stdout.

 @param [in] entry : "Entry to write"
*>
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

<*
 Flush the console output stream.
*>
fn void? ConsoleSink.sync(&self) @dynamic
{
	io::stdout().flush()!;
}

<*
 Change the encoder used by the console sink.

 @param encoder : "Encoder callback to apply to each entry"
*>
fn void ConsoleSink.set_encoder(&self, EncoderFunc encoder) @dynamic
{
	self.encoder = encoder;
}

<*
 Flush console resources before shutdown.
*>
fn void ConsoleSink.free(&self)
{
	self.sync()!!;
}

<*
 Sink that appends encoded entries to a file.
*>
struct FileSink (LogSink)
{
	File file;
	EncoderFunc encoder;
}

<*
 Initialize the file sink and open the output file for appending.

 @param [in] file : "File path used for log output"
 @param from_cwd : "If true, resolve path relative to current working directory"
 @param create_if_missing : "If false, fail when the file does not already exist"
 @param encoder : "Encoder callback to apply to each entry"
 @return "Initialized file sink"
*>
fn FileSink*? FileSink.init(
	&self,
	Path file,
	bool from_cwd = true,
	bool create_if_missing = true,
	EncoderFunc encoder = &json_encode
)
{
	@pool()
	{
		self.encoder = encoder;

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

<*
 Encode and append a log entry to the sink file.

 @param [in] entry : "Entry to write"
*>
fn void FileSink.write(&self, LogEntry* entry) @dynamic
{
	@pool()
	{
		String encoded = self.encoder(tmem, entry);
		self.file.write(encoded)!!;
		self.file.write("\n")!!;
	};
}

<*
 Flush pending bytes to disk.
*>
fn void? FileSink.sync(&self) @dynamic
{
	self.file.flush()!;
}

<*
 Change the encoder used by the file sink.

 @param encoder : "Encoder callback to apply to each entry"
*>
fn void FileSink.set_encoder(&self, EncoderFunc encoder) @dynamic
{
	self.encoder = encoder;
}

<*
 Flush and close the sink file.
*>
fn void FileSink.free(&self)
{
	self.sync()!!;
	self.file.close()!!;
}
