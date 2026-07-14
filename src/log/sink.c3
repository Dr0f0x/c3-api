module c3api::log;

import std::io;

interface LogSink
{
	fn void write(LogEntry* entry);

	fn void sync();

	fn void set_encoder(EncoderFunc encoder);
}

struct ConsoleSink (LogSink)
{
	Allocator allocator;
	EncoderFunc encoder;
}

fn ConsoleSink* ConsoleSink.init(&self, Allocator allocator)
{
	self.allocator = allocator;
	self.encoder = &simple_encode;
	return self;
}

fn void ConsoleSink.write(&self, LogEntry* entry) @dynamic
{
	String encoded = self.encoder(self.allocator, entry);
	if (entry.level > LogLevel.ERROR){
		io::eprint(encoded);
	}
	io::printfn(encoded);
}

fn void ConsoleSink.sync(&self) @dynamic
{
	// No-op for console sink
}

fn void ConsoleSink.set_encoder(&self, EncoderFunc encoder) @dynamic
{
	self.encoder = encoder;
}