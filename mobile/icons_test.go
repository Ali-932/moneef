//go:build smoke

package mobile

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
	"moneef/internal/config"
	"moneef/internal/db"
	"moneef/internal/iconlookup"
	"moneef/internal/models"
	"moneef/internal/transactions/engine"
	"moneef/pkg/types"
)

func runIconTestInSubprocess(t *testing.T) bool {
	t.Helper()
	// Init pins one DB path per process. Keep this independent of backup tests.
	if os.Getenv("MONEEF_ICON_TEST_PROCESS") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^"+t.Name()+"$", "-test.v")
		cmd.Env = append(os.Environ(), "MONEEF_ICON_TEST_PROCESS=1")
		output, err := cmd.CombinedOutput()
		require.NoError(t, err, "%s", output)
		t.Logf("%s", output)
		return true
	}
	return false
}

func TestMobileIconStartupAndUpgrade(t *testing.T) {
	if runIconTestInSubprocess(t) {
		return
	}
	path := filepath.Join(t.TempDir(), "icons.sqlite")
	require.NoError(t, Init(path, 0))
	t.Cleanup(func() { _ = Shutdown() })
	var defaults []iconlookup.Entry
	require.NoError(t, json.Unmarshal(config.MerchantIconsJSON, &defaults))
	countKeywords := func() int64 {
		var count int64
		require.NoError(t, dbHandle.Model(&models.IconLookup{}).Count(&count).Error)
		return count
	}
	// Available during the first loading screen, even before onboarding.
	require.EqualValues(t, len(defaults), countKeywords())
	require.Equal(t, len(defaults), iconlookup.GetCacheSize())
	_, err := Setup([]byte(`{"first_name":"Icon","last_name":"Test","currency_code":"USD","language":"en"}`))
	require.NoError(t, err)
	pid := ActiveProfileID()
	var category models.Category
	require.NoError(t, dbHandle.Where("name = ? AND type = ?", "Entertainment", "expense").First(&category).Error)
	encode := func(v interface{}) []byte { b, e := json.Marshal(v); require.NoError(t, e); return b }
	create := func(name string, extra map[string]interface{}) models.Transaction {
		body := map[string]interface{}{
			"transaction_name": name, "currency_code": "USD", "transaction_type": "expense",
			"date":                   "2026-09-27T12:00:00Z",
			"transaction_categories": []map[string]interface{}{{"category_id": category.ID, "amount": "15.00"}},
		}
		for key, value := range extra {
			body[key] = value
		}
		_, err := CreateTransaction(encode(body))
		require.NoError(t, err)
		var txn models.Transaction
		require.NoError(t, dbHandle.Where("name = ?", name).First(&txn).Error)
		return txn
	}
	read := func(id uint) models.Transaction {
		var txn models.Transaction
		require.NoError(t, dbHandle.Preload("TransactionCategory").First(&txn, id).Error)
		return txn
	}
	spotify := create("Spotify Premium", nil)
	require.Equal(t, "mdi:spotify", spotify.Icon)
	require.Equal(t, "#1DB954", spotify.Color)
	require.Equal(t, engine.IconSourceAutomatic, spotify.IconSource)
	manual := create("Spotify explicit", map[string]interface{}{"icon": category.Icon, "color": category.Color})
	require.Equal(t, category.Icon, manual.Icon)
	require.Equal(t, engine.IconSourceManual, manual.IconSource)
	partial := create("Spotify custom color", map[string]interface{}{"color": "#123456"})
	require.Equal(t, "mdi:spotify", partial.Icon)
	require.Equal(t, "#123456", partial.Color)
	_, err = UpdateTransaction(int64(partial.ID), encode(map[string]interface{}{"icon": "mdi:heart"}))
	require.NoError(t, err)
	_, err = UpdateTransaction(int64(partial.ID), encode(map[string]interface{}{"transaction_name": "Netflix explicit icon"}))
	require.NoError(t, err)
	require.Equal(t, "mdi:heart", read(partial.ID).Icon)
	require.Equal(t, engine.IconSourceManual, read(partial.ID).IconSource)
	require.Equal(t, "#123456", read(partial.ID).Color)
	unknown := create("zzxqv 473829", nil)
	require.Equal(t, category.Icon, unknown.Icon)
	_, err = UpdateTransaction(int64(unknown.ID), encode(map[string]interface{}{"transaction_name": "Spotify renamed"}))
	require.NoError(t, err)
	require.Equal(t, "mdi:spotify", read(unknown.ID).Icon)
	_, err = UpdateTransaction(int64(unknown.ID), encode(map[string]interface{}{"transaction_name": "zzxqv 473829 again"}))
	require.NoError(t, err)
	require.Equal(t, category.Icon, read(unknown.ID).Icon)
	merchant := create("Generic subscription", map[string]interface{}{"merchant_name": "Spotify"})
	require.Equal(t, "mdi:spotify", merchant.Icon)
	notes := create("zzxqv 937461", map[string]interface{}{"notes": "Spotify premium plan"})
	require.Equal(t, "mdi:spotify", notes.Icon)
	_, err = CreateCategory([]byte(`{"name":"Spotify automatic category","type":"expense"}`))
	require.NoError(t, err)
	var autoCategory models.Category
	require.NoError(t, dbHandle.Where("name = ?", "Spotify automatic category").First(&autoCategory).Error)
	require.Equal(t, "mdi:spotify", autoCategory.Icon)

	// Simulate a partial dictionary and pre-upgrade saved category fallbacks.
	require.NoError(t, dbHandle.Where("keyword = ?", "spotify").Delete(&models.IconLookup{}).Error)
	require.NoError(t, dbHandle.Model(&models.IconLookup{}).Where("keyword = ?", "netflix").Updates(map[string]interface{}{"icon": "mdi:television", "color": "#654321"}).Error)
	stamp := time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC)
	var legacy []models.Transaction
	for i := 0; i < 205; i++ {
		amount := types.MoneyFromInt(15)
		legacy = append(legacy, models.Transaction{
			ProfileID: uint(pid), Name: "Spotify old fallback", Type: "expense", CurrencyCode: "USD",
			Date: stamp, CreatedAt: stamp, UpdatedAt: stamp, Icon: category.Icon, Color: category.Color,
			TransactionCategory: []models.TransactionCategory{{CategoryID: category.ID, Amount: &amount}},
		})
	}
	require.NoError(t, dbHandle.CreateInBatches(&legacy, 100).Error)
	custom := create("Spotify legacy custom", map[string]interface{}{"icon": "mdi:heart", "color": "#121212"})
	require.NoError(t, dbHandle.Model(&custom).UpdateColumns(map[string]interface{}{"icon_source": "", "color_source": ""}).Error)
	require.NoError(t, Shutdown())
	require.NoError(t, Init(path, pid))
	require.EqualValues(t, len(defaults), countKeywords())
	for _, original := range legacy {
		got := read(original.ID)
		require.Equal(t, "mdi:spotify", got.Icon)
		require.Equal(t, "#1DB954", got.Color)
		require.Equal(t, engine.IconSourceAutomatic, got.IconSource)
		require.True(t, original.UpdatedAt.Equal(got.UpdatedAt))
		require.True(t, stamp.Equal(got.Date))
		require.Equal(t, "15", got.TransactionCategory[0].Amount.String())
	}
	require.Equal(t, "mdi:heart", read(custom.ID).Icon)
	require.Equal(t, category.Icon, read(manual.ID).Icon)
	require.Equal(t, "#123456", read(partial.ID).Color)
	require.Equal(t, "mdi:heart", read(partial.ID).Icon)
	icon, color, found := iconlookup.Lookup("netflix")
	require.True(t, found)
	require.Equal(t, "mdi:television", icon)
	require.Equal(t, "#654321", color)
	var before []models.Transaction
	require.NoError(t, dbHandle.Preload("TransactionCategory").Order("id").Find(&before).Error)
	require.NoError(t, Shutdown())
	require.NoError(t, Init(path, pid))
	for _, original := range before {
		require.Equal(t, original, read(original.ID), "repeated startup changed transaction %d", original.ID)
	}
	require.EqualValues(t, len(defaults), countKeywords())
}

func TestMobileIconsMigratesOldSchema(t *testing.T) {
	if runIconTestInSubprocess(t) {
		return
	}
	path := filepath.Join(t.TempDir(), "old-icons.sqlite")
	oldDB, err := gorm.Open(sqlite.Open(path), &gorm.Config{})
	require.NoError(t, err)
	require.NoError(t, db.MigrateModels(oldDB))
	// Reproduce an installed database that predates icon provenance columns.
	require.NoError(t, oldDB.Migrator().DropColumn(&models.Transaction{}, "IconSource"))
	require.NoError(t, oldDB.Migrator().DropColumn(&models.Transaction{}, "ColorSource"))
	require.NoError(t, oldDB.Create(&models.Currency{Code: "USD", Name: "US dollar"}).Error)
	kind := "expense"
	category := models.Category{Name: "Legacy entertainment", Type: &kind, Icon: "mdi:movie", Color: "#AA2211"}
	require.NoError(t, oldDB.Create(&category).Error)
	amount := types.MoneyFromInt(15)
	stamp := time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC)
	transaction := models.Transaction{
		ProfileID: 1, Name: "Spotify Premium", Type: "expense", CurrencyCode: "USD",
		Date: stamp, CreatedAt: stamp, UpdatedAt: stamp, Icon: category.Icon, Color: category.Color,
		TransactionCategory: []models.TransactionCategory{{CategoryID: category.ID, Amount: &amount}},
	}
	require.NoError(t, oldDB.Omit("IconSource", "ColorSource").Create(&transaction).Error)
	connection, err := oldDB.DB()
	require.NoError(t, err)
	require.NoError(t, connection.Close())
	require.NoError(t, Init(path, 0))
	t.Cleanup(func() { _ = Shutdown() })
	var got models.Transaction
	require.NoError(t, dbHandle.Preload("TransactionCategory").First(&got, transaction.ID).Error)
	require.Equal(t, "mdi:spotify", got.Icon)
	require.Equal(t, engine.IconSourceAutomatic, got.IconSource)
	require.Equal(t, engine.IconSourceAutomatic, got.ColorSource)
	require.True(t, stamp.Equal(got.UpdatedAt))
	require.Equal(t, "15", got.TransactionCategory[0].Amount.String())
	require.Equal(t, category.ID, got.TransactionCategory[0].CategoryID)
}
