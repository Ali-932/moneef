package iconlookup

import (
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/glebarez/sqlite"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
	"moneef/internal/config"
	"moneef/internal/models"
)

func TestSeedDefaultsFillsMissingKeywordsWithoutReplacingExisting(t *testing.T) {
	database, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "icons.sqlite")), &gorm.Config{})
	require.NoError(t, err)
	conn, err := database.DB()
	require.NoError(t, err)
	t.Cleanup(func() { _ = conn.Close() })
	require.NoError(t, database.AutoMigrate(&models.IconLookup{}))
	var defaults []Entry
	require.NoError(t, json.Unmarshal(config.MerchantIconsJSON, &defaults))
	require.Greater(t, len(defaults), 3000)
	created, err := SeedDefaults(database)
	require.NoError(t, err)
	require.EqualValues(t, len(defaults), created)
	var original models.IconLookup
	require.NoError(t, database.Where("keyword = ?", "spotify").First(&original).Error)
	require.NoError(t, database.Model(&original).Updates(map[string]interface{}{"icon": "mdi:music", "color": "#123456"}).Error)
	created, err = SeedDefaults(database)
	require.NoError(t, err)
	require.Zero(t, created)
	require.NoError(t, database.Where("keyword = ?", "netflix").Delete(&models.IconLookup{}).Error)
	created, err = SeedDefaults(database)
	require.NoError(t, err)
	require.EqualValues(t, 1, created)
	var preserved models.IconLookup
	require.NoError(t, database.First(&preserved, original.ID).Error)
	require.Equal(t, "mdi:music", preserved.Icon)
	require.Equal(t, "#123456", preserved.Color)
	var count int64
	require.NoError(t, database.Model(&models.IconLookup{}).Count(&count).Error)
	require.EqualValues(t, len(defaults), count)
	require.NoError(t, LoadCache(database))
	icon, color, found := Lookup("SPOTIFY")
	require.True(t, found)
	require.Equal(t, "mdi:music", icon)
	require.Equal(t, "#123456", color)
}

func TestShortBrandNamesDoNotMatchInsideOtherWords(t *testing.T) {
	for _, input := range []string{"extra purchase", "zzxqv 473829", "x123", "اشتراكx", "xاشتراك"} {
		require.False(t, matchesKeyword(input, "x"), input)
	}
	for _, input := range []string{"x", "x premium", "subscription: x", "extra x payment"} {
		require.True(t, matchesKeyword(input, "x"), input)
	}
	require.True(t, matchesKeyword("spotify premium", "spotify"))
	require.True(t, matchesKeyword("netflix.com", "netflix"))
}
