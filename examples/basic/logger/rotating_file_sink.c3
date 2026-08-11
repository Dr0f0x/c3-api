module main;

import std::io::path;
import std::thread;
import std::collections::deque;
import std::time;
import std::io::file;
import std::sort;

import c3api::log;

<*
 Rotating file sink.

 Writes encoded log entries to timestamped files and automatically
 creates a new file when the current file reaches the configured
 maximum size.
*>
struct RotatingFileSink (LogSink)
{
	bool file_base_owned;
	String file_base_name;
	Path file_base_parent;

	File file;
	Mutex mutex;

	EncoderFunc encoder;

	usz max_files;
	usz max_file_size;
	usz current_size;

	// Paths of files currently owned and retained by this sink,
	// ordered from oldest to newest.
	Deque{Path} files;

	Allocator allocator;
}

<*
 Initialize the rotating file sink.

 The initial log file is created using file_base plus a timestamp.

 @param file_base : "Base path and filename used for generated log files"
 @param max_files : "Maximum number of log files to retain"
 @param max_file_size : "Maximum size of an individual log file in bytes"
 @param from_cwd : "If true, resolve file_base relative to the current working directory"
 @param encoder : "Encoder callback to apply to each entry"
*>
fn RotatingFileSink*? RotatingFileSink.init(
	&self,
	Allocator allocator,
	Path file_base,
	uint max_files,
	uint max_file_size,
	bool from_cwd = true,
	EncoderFunc encoder = &log::json_encode
)
{
	if (max_files <= 1)
	{
		return io::INVALID_ARGUMENT~;
	}

	if (max_file_size == 0)
	{
		return io::INVALID_ARGUMENT~;
	}

	self.encoder = encoder;
	self.max_files = max_files;
	self.max_file_size = max_file_size;
	self.current_size = 0;
	self.allocator = allocator;
	if (from_cwd)
	{
		Path cwd = path::cwd(allocator)!;
		self.file_base_parent = (cwd.append(allocator, file_base)!).parent()!;
		self.file_base_owned = true;
	}
	else
	{
		self.file_base_parent = file_base.parent()!;
	}
	self.file_base_name = file_base.basename();

	// Ensure parent directory
	path::mkdir(self.file_base_parent, true)!;

	self.files.init(allocator);
	self.mutex.init()!;

	// Try to continue writing to the newest existing file.
	if (!self.try_reuse_existing()!)
	{
		self.rotate()!;
	}

	return self;
}

fn int compare_paths(Path* a, Path* b) @private
{
	if (a < b) return -1;
	if (a > b) return 1;
	return 0;
}

<*
 Find existing rotated files and reuse the newest one.

 The files are expected to follow the format:

 <name>-<timestamp><extension>

 Only files matching this sink's base name are considered.
*>
fn bool? RotatingFileSink.try_reuse_existing(&self)
{
	// Split file base into name and extension to insert timestamp
	String name;
	String extension = "";

	if (try sz dot = self.file_base_name.rindex_of_char('.'))
	{
		name = self.file_base_name[..dot - 1];
		extension = self.file_base_name[dot..];
	}
	else
	{
		name = self.file_base_name;
	}

	@pool()
	{
		// build pattern
		String pattern = string::tformat("%s-*%s", name, extension);

		PathList existing = path::ls(
			self.allocator,
			self.file_base_parent,
			no_dirs: true,
			mask: pattern,
			relative: false
		)!;
		if (existing.len() == 0)
		{
			return false;
		}

		// The generated timestamp is lexically sortable:
		// 
		// 2026-08-11_210000
		// 2026-08-11_220000
		// 
		// so sorting by filename gives chronological order
		sort::quicksort(&existing, &compare_paths);

		foreach (Path existing_path : existing)
		{
			self.files.push(existing_path);
		}

		// The newest file is the last one
		Path newest = existing[existing.len() - 1];

		// Get its current size
		usz size = (ulong)path::file_size(newest)!;

		// If the newest file is already full, let rotate()
		// create a new one instead
		if (size >= self.max_file_size)
		{
			return false;
		}

		self.file = file::open_path(newest, "a")!;
		self.current_size = size;
	};

	return true;
}

<*
 Create a new timestamped log file.

 The generated filename is based on file_base and the current
 date/time.
*>
fn void? RotatingFileSink.rotate(&self)
{
	// Close the previous file before opening the new one.
	if (self.current_size > 0)
	{
		self.file.flush()!;
		self.file.close()!!;
	}

	@pool()
	{
		// Generate a timestamped filename.
		String timestamp = datetime::now().format(tmem, DateTimeFormat.DATETIME).treplace(" ", "_").treplace(":", "-");

		// Split file base into name and extension to insert timestamp
		String name;
		String extension = "";

		if (try sz dot = self.file_base_name.rindex_of_char('.'))
		{
			name = self.file_base_name[..dot - 1];
			extension = self.file_base_name[dot..];
		}
		else
		{
			name = self.file_base_name;
		}

		// Insert timestamp
		String filename = string::tformat("%s-%s%s", name, timestamp, extension);
		Path new_path   = self.file_base_parent.append(self.allocator, filename)!;

		// Create and open new file
		self.file = file::open_path(new_path, "w")!;
		self.files.push(new_path);
		self.current_size = 0;

		// Remove the oldest files if we exceeded max_files.
		while ((ulong)self.files.len() > self.max_files)
		{
			// Delete oldest file and remove it from our tracking list
			if (try Path old_path = self.files.pop_first())
			{
				old_path.free(self.allocator);
				path::delete(old_path)!;
			}
		}
	};
}

<*
 Encode and append a log entry.

 If writing the entry would exceed max_file_size, rotate before
 writing the entry.

 @param [in] entry : "Entry to write"
*>
fn void RotatingFileSink.write(&self, LogEntry* entry) @dynamic
{
	@pool()
	{
		self.mutex.@in_lock()
		{
			String encoded = self.encoder(tmem, entry);
			usz entry_size = encoded.len + 1;

			// Rotate before writing if this entry would exceed
			// the configured maximum file size.
			if (self.current_size > 0 && self.current_size + entry_size > self.max_file_size)
			{
				self.rotate()!!;
			}

			self.file.write(encoded)!!;
			self.file.write("\n")!!;

			self.current_size += entry_size;
		};
	};
}

<*
 Flush pending bytes to disk.
*>
fn void? RotatingFileSink.sync(&self) @dynamic
{
	self.mutex.@in_lock()
	{
		self.file.flush()!;
	};
}

<*
 Change the encoder used by the file sink.

 @param encoder : "Encoder callback to apply to each entry"
*>
fn void RotatingFileSink.set_encoder(&self, EncoderFunc encoder) @dynamic
{
	self.encoder = encoder;
}

<*
 Flush and close the current log file.
*>
fn void RotatingFileSink.free(&self)
{
	if (self.file_base_owned)
	{
		self.file_base_parent.free(self.allocator);
	}
	self.file_base_name.free(self.allocator);

	foreach (Path file : self.files)
	{
		file.free(self.allocator);
	}
	self.files.free();
	self.sync()!!;
	self.file.close()!!;
	self.mutex.destroy();
}