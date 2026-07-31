// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::concurrency;

import std::io;

enum ConcurrencyMode (Printable)
{
	THREAD_POOL,
	THREAD_PER_REQUEST,
}

fn String ConcurrencyMode.to_constant_string(&self) @dynamic
{
	switch (*self)
	{
		case ConcurrencyMode.THREAD_POOL:
			return "THREAD_POOL";
		case ConcurrencyMode.THREAD_PER_REQUEST:
			return "THREAD_PER_REQUEST";
		default:
			return "INVALID_CONCURRENCY_MODE";
	}
}
