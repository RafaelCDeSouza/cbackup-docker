<?php

namespace dautkom\ipv4;

/**
 * IPv4 utility class — shim for dautkom/ipv4 with fluent interface.
 *
 * Supports both the fluent API used by cBackup:
 *   address($ip)->isValid()
 *   address($ip)->mask($cidr)->isValid(1)
 *   subnet($cidr_notation)->isValid()
 *   subnet($cidr_notation)->has($ip)
 *   subnet($cidr_notation)->getRange()
 *
 * And the static-style helpers:
 *   isValid($ip), validate($ip), cidrToNetmask(), netmaskToCidr(), inRange(), ip2long(), long2ip()
 */
class IPv4
{
    private $_address = null;
    private $_mask    = null;

    // ── Fluent setters ────────────────────────────────────────────────────────

    /** Set the IP address for fluent operations. */
    public function address($ip)
    {
        $this->_address = $ip;
        $this->_mask    = null;
        return $this;
    }

    /** Set the prefix length / netmask for fluent operations. */
    public function mask($mask)
    {
        $this->_mask = $mask;
        return $this;
    }

    /**
     * Parse a CIDR string ("192.168.0.0/24") or bare IP into address+mask.
     * Used as: subnet($network)->isValid() / ->has($ip) / ->getRange()
     */
    public function subnet($network)
    {
        if (strpos($network, '/') !== false) {
            [$addr, $mask]  = explode('/', $network, 2);
            $this->_address = trim($addr);
            $this->_mask    = trim($mask);
        } else {
            $this->_address = trim($network);
            $this->_mask    = null;
        }
        return $this;
    }

    // ── Fluent terminators ────────────────────────────────────────────────────

    /**
     * Validate the stored address (and optional mask).
     *
     * Fluent usage:  ->address($ip)->isValid()
     *                ->address($ip)->mask($cidr)->isValid(1)   ← strict: host bits must be 0
     *                ->subnet($cidr)->isValid()
     *
     * Legacy usage:  ->isValid($ipString)
     *
     * @param  int|string $strict  1 = strict network-address check; or legacy IP string
     * @return bool
     */
    public function isValid($strict = 0)
    {
        // Legacy non-fluent call: isValid('192.168.0.1')
        if ($this->_address === null) {
            return is_string($strict) ? $this->validate($strict) : false;
        }

        $addr = $this->_address;
        $mask = $this->_mask;
        $this->_address = null;
        $this->_mask    = null;

        if (filter_var($addr, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false) {
            return false;
        }

        if ($mask === null) {
            return true; // address-only validation
        }

        $cidr = $this->_normaliseCidr($mask);
        if ($cidr === false) {
            return false;
        }

        // Strict mode: the address must be the network address (host bits == 0)
        if ((int)$strict === 1) {
            $addrLong = ip2long($addr);
            $netMask  = $cidr === 0 ? 0 : ((~0 << (32 - $cidr)) & 0xffffffff);
            if (($addrLong & (~$netMask & 0xffffffff)) !== 0) {
                return false;
            }
        }

        return true;
    }

    /**
     * Check whether the stored subnet contains $ip.
     * Usage: subnet('192.168.0.0/24')->has('192.168.0.5')
     */
    public function has($ip)
    {
        $addr = $this->_address;
        $mask = $this->_mask;
        $this->_address = null;
        $this->_mask    = null;

        if ($addr === null || $mask === null) {
            return false;
        }

        return $this->inRange($ip, $addr . '/' . $mask);
    }

    /**
     * Return [first_ip, last_ip] for the stored subnet.
     * Usage: subnet('192.168.0.0/24')->getRange()  → ['192.168.0.0', '192.168.0.255']
     */
    public function getRange()
    {
        $addr = $this->_address;
        $mask = $this->_mask;
        $this->_address = null;
        $this->_mask    = null;

        if ($addr === null) {
            return [];
        }

        $cidr = ($mask !== null) ? $this->_normaliseCidr($mask) : 32;
        if ($cidr === false) {
            return [];
        }

        $addrLong = ip2long($addr);
        $netMask  = $cidr === 0 ? 0 : ((~0 << (32 - $cidr)) & 0xffffffff);
        $first    = $addrLong & $netMask;
        $last     = $first | (~$netMask & 0xffffffff);

        return [long2ip($first), long2ip($last)];
    }

    // ── Static-style helpers ──────────────────────────────────────────────────

    public function ip2long($ip)   { return ip2long($ip); }
    public function long2ip($long) { return long2ip($long); }

    public function validate($ip)
    {
        return filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) !== false;
    }

    public function cidrToNetmask($cidr)
    {
        $cidr = (int)$cidr;
        if ($cidr < 0 || $cidr > 32) {
            return false;
        }
        return long2ip($cidr === 0 ? 0 : ((~0 << (32 - $cidr)) & 0xffffffff));
    }

    public function netmaskToCidr($netmask)
    {
        $long = ip2long($netmask);
        if ($long === false) {
            return false;
        }
        return substr_count(decbin($long & 0xffffffff), '1');
    }

    public function inRange($ip, $network)
    {
        if (strpos($network, '/') === false) {
            return $ip === $network;
        }

        [$subnet, $cidr] = explode('/', $network, 2);
        $cidr = $this->_normaliseCidr($cidr);
        if ($cidr === false) {
            return false;
        }

        $ipLong     = ip2long($ip);
        $subnetLong = ip2long($subnet);
        if ($ipLong === false || $subnetLong === false) {
            return false;
        }

        $mask = $cidr === 0 ? 0 : ((~0 << (32 - $cidr)) & 0xffffffff);
        return ($ipLong & $mask) === ($subnetLong & $mask);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Accept CIDR int ("24") or dotted netmask ("255.255.255.0"), return int 0-32 or false.
     */
    private function _normaliseCidr($mask)
    {
        if (is_numeric($mask)) {
            $cidr = (int)$mask;
            return ($cidr >= 0 && $cidr <= 32) ? $cidr : false;
        }

        // Dotted-decimal netmask
        if (filter_var($mask, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false) {
            return false;
        }
        return $this->netmaskToCidr($mask);
    }
}
