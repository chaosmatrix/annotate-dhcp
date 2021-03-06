// Copyright (C) 2016-2017 Internet Systems Consortium, Inc. ("ISC")
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#include <dhcp6/simple_parser6.h>
#include <cc/data.h>
#include <boost/foreach.hpp>

using namespace isc::data;

namespace isc {
namespace dhcp {
/// @brief This sets of arrays define the default values and
///        values inherited (derived) between various scopes.
///
/// Each of those is documented in @file simple_parser6.cc. This
/// is different than most other comments in Kea code. The reason
/// for placing those in .cc rather than .h file is that it
/// is expected to be one centralized place to look at for
/// the default values. This is expected to be looked at also by
/// people who are not skilled in C or C++, so they may be
/// confused with the differences between declaration and definition.
/// As such, there's one file to look at that hopefully is readable
/// without any C or C++ skills.
///
/// @{

/// @brief This table defines default values for option definitions in DHCPv6.
///
/// Dhcp6 may contain an array called option-def that enumerates new option
/// definitions. This array lists default values for those option definitions.
const SimpleDefaults SimpleParser6::OPTION6_DEF_DEFAULTS = {
    { "record-types", Element::string,  ""},
    { "space",        Element::string,  "dhcp6"},
    { "array",        Element::boolean, "false"},
    { "encapsulate",  Element::string,  "" }
};

/// @brief This table defines default values for options in DHCPv6.
///
/// Dhcp6 usually contains option values (option-data) defined in global,
/// subnet, class or host reservations scopes. This array lists default values
/// for those option-data declarations.
const SimpleDefaults SimpleParser6::OPTION6_DEFAULTS = {
    { "space",        Element::string,  "dhcp6"},
    { "csv-format",   Element::boolean, "true"}
};

/// @brief This table defines default global values for DHCPv6
///
/// Some of the global parameters defined in the global scope (i.e. directly
/// in Dhcp6) are optional. If not defined, the following values will be
/// used.
const SimpleDefaults SimpleParser6::GLOBAL6_DEFAULTS = {
    { "renew-timer",              Element::integer, "900" },
    { "rebind-timer",             Element::integer, "1800" },
    { "preferred-lifetime",       Element::integer, "3600" },
    { "valid-lifetime",           Element::integer, "7200" },
    { "decline-probation-period", Element::integer, "86400" }, // 24h
    { "dhcp4o6-port",             Element::integer, "0" }
};

/// @brief This table defines default values for each IPv6 subnet.
const SimpleDefaults SimpleParser6::SUBNET6_DEFAULTS = {
    { "id",               Element::integer, "0" }, // 0 means autogenerate
    { "interface",        Element::string,  "" },
    { "client-class",     Element::string,  "" },
    { "reservation-mode", Element::string,  "all" },
    { "rapid-commit",     Element::boolean, "false" }, // rapid-commit disabled by default
    { "interface-id",     Element::string,  "" },
};

/// @brief List of parameters that can be inherited from the global to subnet6 scope.
///
/// Some parameters may be defined on both global (directly in Dhcp6) and
/// subnet (Dhcp6/subnet6/...) scope. If not defined in the subnet scope,
/// the value is being inherited (derived) from the global scope. This
/// array lists all of such parameters.
const ParamsList SimpleParser6::INHERIT_GLOBAL_TO_SUBNET6 = {
    "renew-timer",
    "rebind-timer",
    "preferred-lifetime",
    "valid-lifetime"
};
/// @}

/// ---------------------------------------------------------------------------
/// --- end of default values -------------------------------------------------
/// ---------------------------------------------------------------------------

size_t SimpleParser6::setAllDefaults(isc::data::ElementPtr global) {
    size_t cnt = 0;

    // Set global defaults first.
    cnt = setDefaults(global, GLOBAL6_DEFAULTS);

    // Now set the defaults for each specified option definition
    ConstElementPtr option_defs = global->get("option-def");
    if (option_defs) {
        BOOST_FOREACH(ElementPtr option_def, option_defs->listValue()) {
            cnt += SimpleParser::setDefaults(option_def, OPTION6_DEF_DEFAULTS);
        }
    }

    // Set the defaults for option data
    ConstElementPtr options = global->get("option-data");
    if (options) {
        BOOST_FOREACH(ElementPtr single_option, options->listValue()) {
            cnt += SimpleParser::setDefaults(single_option, OPTION6_DEFAULTS);
        }
    }

    // Now set the defaults for defined subnets
    // Now set the defaults for defined subnets
    ConstElementPtr subnets = global->get("subnet6");
    if (subnets) {
        cnt += setListDefaults(subnets, SUBNET6_DEFAULTS);
    }

    return (cnt);
}

size_t SimpleParser6::deriveParameters(isc::data::ElementPtr global) {
    size_t cnt = 0;
    // Now derive global parameters into subnets.
    ConstElementPtr subnets = global->get("subnet6");
    if (subnets) {
        BOOST_FOREACH(ElementPtr single_subnet, subnets->listValue()) {
            cnt += SimpleParser::deriveParams(global, single_subnet,
                                              INHERIT_GLOBAL_TO_SUBNET6);
        }
    }

    return (cnt);
}

};
};
