package config

import _ "embed"

// MerchantIconsJSON ships the keyword dictionary with every binary, including
// Android, where the repository's config files are not available on disk.
//
//go:embed merchants.json
var MerchantIconsJSON []byte
