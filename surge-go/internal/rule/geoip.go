package rule

import (
	"github.com/surge-proxy/surge-go/internal/geoip"
)

// GeoIPRule matches IP country code
type GeoIPRule struct {
	BaseRule
	CountryCode string
}

func NewGeoIPRule(country, adapter string, noResolve bool) *GeoIPRule {
	return &GeoIPRule{
		BaseRule: BaseRule{
			RuleType:    "GEOIP",
			RulePayload: country,
			AdapterName: adapter,
			NoResolve:   noResolve,
		},
		CountryCode: country,
	}
}

func (r *GeoIPRule) Match(metadata *RequestMetadata) bool {
	ip := metadata.IP
	if ip == nil {
		if r.NoResolve {
			return false
		}
		ip = metadata.DnsIP
	}

	if ip == nil {
		return false
	}

	// Use the global GeoIP instance
	if !geoip.IsInitialized() {
		return false
	}

	isoCode, err := geoip.LookupCountry(ip)
	if err != nil {
		return false
	}

	return isoCode == r.CountryCode
}
