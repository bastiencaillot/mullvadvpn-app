#pragma once

#include <winfw/rules/ifirewallrule.h>
#include <winfw/winfw.h>
#include <libwfp/ipaddress.h>
#include <string>

namespace rules::multi
{

class PermitVpnRelayBase : public IFirewallRule
{
public:

	enum class Sublayer
	{
		Baseline,
		Dns
	};

	PermitVpnRelayBase
	(
		const GUID &filterKey,
		const wfp::IpAddress &relay,
		uint16_t relayPort,
		WinFwProtocol protocol,
		const std::wstring &relayClient,
		Sublayer sublayer
	);

	bool apply(IObjectInstaller &objectInstaller) override;

private:

	const GUID &m_filterKey;
	const wfp::IpAddress m_relay;
	const uint16_t m_relayPort;
	const WinFwProtocol m_protocol;
	const std::wstring m_relayClient;
	const Sublayer m_sublayer;
};

}
