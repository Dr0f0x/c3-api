module c3api::os::win32;

import std::os::win32;
import std::io;
import std::core::string;

import c3api::log;
struct WsaData @if(env::WIN32)
{
	ushort wVersion;
	ushort wHighVersion;

	ushort iMaxSockets; // should be ingored for Winsock 2 and later
	ushort iMaxUdpDg; // should be ingored for Winsock 2 and later

	char* lpVendorInfo;

	char[257] szDescription; // WSADESCRIPTION_LEN + 1
	char[129] szSystemStatus; // WSASYS_STATUS_LEN + 1
}

extern fn CInt win32_WSAStartup(
	Win32_WORD version,
	WsaData* data
) @cname("WSAStartup") @if(env::WIN32 && !$defined(win32_WSAStartup));
extern fn CInt win32_WSACleanup() @cname("WSACleanup") @if(env::WIN32 && !$defined(win32_WSACleanup));
extern fn CInt win32_WSAGetLastError() @cname("WSAGetLastError") @if(env::WIN32 && !$defined(win32_WSAGetLastError));

fn void startWSA(log::Logger logger)
{
	$if !env::WIN32:
		return;
	$else
		logger.info("Env is Win32");
		WsaData wsa_data;
		Win32_WORD version = 0x0202;

		int wsa_error = win32_WSAStartup(version, &wsa_data);

		@pool()
		{
			DString desc = dstring::temp();

			foreach (char ch : wsa_data.szDescription)
			{
				if (ch == 0) break;
				desc.append_char(ch);
			}

			DString status = dstring::temp();

			foreach (char ch : wsa_data.szSystemStatus)
			{
				if (ch == 0) break;
				status.append_char(ch);
			}


			ushort major = (wsa_data.wVersion >> 8) & 0xFF;
			ushort minor = wsa_data.wVersion & 0xFF;


			logger.infof(
				"Winsock Configuration | version: %s | description: %s | status: %s",
				"Winsock configured",
				log::_string("version", &&string::tformat("%d.%d", major, minor)),
				log::_string("description", &&desc.str_view()),
				log::_string("status", &&status.str_view())
			);
		};

		if (wsa_error != 0)
		{
			logger.errorf(
				"failed to startup WSA with error: %d",
				"failed to startup WSA",
				log::_int("error", &wsa_error)
			);
			return;
		}
		logger.info("WSA started successfully");
	$endif
}

fn void stopWSA(log::Logger logger)
{
	$if !env::WIN32:
		return;
	$else
		logger.info("cleaning up WSA");
		win32_WSACleanup();
	$endif
}

fn void lastWSAErrorOut(log::Logger logger)
{
	$if !env::WIN32:
		return;
	$else
		logger.warnf("WSAGetLastError Output: %d", "WSAGetLastError", log::_int("error", &&win32_WSAGetLastError()));
	$endif
}
