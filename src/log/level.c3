// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::log;

import std::io;

<*
 Log severity levels in ascending order.

 The string fields provide display-friendly and uppercase names.
*>
enum LogLevel (Printable) : int (String name, String name_upper)
{
	TRACE { "Trace", "TRACE" },
	DEBUG { "Debug", "DEBUG" },
	INFO  { "Info", "INFO" },
	WARN  { "Warn", "WARN" },
	ERROR { "Error", "ERROR" },
	FATAL { "Fatal", "FATAL" }
}

fn String LogLevel.to_constant_string(&self) @dynamic
{
	switch (*self)
	{
		case LogLevel.TRACE: return "TRACE";
		case LogLevel.DEBUG: return "DEBUG";
		case LogLevel.INFO: return "INFO";
		case LogLevel.WARN: return "WARN";
		case LogLevel.ERROR: return "ERROR";
		case LogLevel.FATAL: return "FATAL";
	}
}