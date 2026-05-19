<?php

namespace dautkom\ipv4;

class IPv4
{
    public function ip2long($ip) { return ip2long($ip); }

    public function long2ip($long) { return long2ip($long); }

    public function validate($ip)
    {
        return filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) !== false;
    }

    public function isValid($ip)
    {
        return $this->validate($ip);
    }

    public function cidrToNetmask($cidr)
    {
        $cidr = (int)$cidr;

        if ($cidr < 0 || $cidr > 32) {
            return false;
        }

        return long2ip((0xffffffff << (32 - $cidr)) & 0xffffffff);
    }

    public function netmaskToCidr($netmask)
    {
        $long = ip2long($netmask);

        if ($long === false) {
            return false;
        }

        return substr_count(decbin($long), '1');
    }

    public function inRange($ip, $network)
    {
        if (strpos($network, '/') === false) {
            return $ip === $network;
        }

        list($subnet, $cidr) = explode('/', $network, 2);

        $ipLong = ip2long($ip);
        $subnetLong = ip2long($subnet);
        $cidr = (int)$cidr;

        if ($ipLong === false || $subnetLong === false || $cidr < 0 || $cidr > 32) {
            return false;
        }

        $mask = (0xffffffff << (32 - $cidr)) & 0xffffffff;

        return (($ipLong & $mask) === ($subnetLong & $mask));
    }
}
