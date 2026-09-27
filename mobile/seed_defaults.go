//go:build android || smoke

package mobile

import (
	"errors"
	"fmt"

	"gorm.io/gorm"

	"moneef/internal/models"
)

// seedDefaultCategories ensures the 21 built-in (profile_id IS NULL) categories
// exist. Idempotent: re-running after they exist is a no-op except for
// icon/color refresh on the existing rows (matches cmd/seed.go behavior).
//
// Called from Init so first-launch flutter clients always have categories
// to render on the Profile → Categories screen.
func seedDefaultCategories(database *gorm.DB) error {
	type def struct {
		Name  string
		Type  string
		Icon  string
		Color string
	}

	const (
		expense = "expense"
		income  = "income"
	)

	defaults := []def{
		// Expense
		{"Food", expense, "mdi:food", "#FF6B6B"},
		{"Transport", expense, "mdi:car", "#4D96FF"},
		{"Utilities", expense, "mdi:flash", "#FFD93D"},
		{"Entertainment", expense, "mdi:movie", "#845EC2"},
		{"Shopping", expense, "mdi:shopping", "#FF9671"},
		{"Healthcare", expense, "mdi:hospital-box", "#00C9A7"},
		{"Housing", expense, "mdi:home", "#8B4513"},
		{"Personal Care", expense, "mdi:spa", "#FF69B4"},
		{"Education", expense, "mdi:school", "#20B2AA"},
		{"Insurance", expense, "mdi:shield-check", "#6495ED"},
		{"Travel", expense, "mdi:airplane", "#32CD32"},
		{"Business", expense, "mdi:briefcase", "#708090"},
		{"Savings", expense, "mdi:piggy-bank", "#228B22"},
		{"Debt", expense, "mdi:credit-card", "#DC143C"},
		{"Gifts", expense, "mdi:gift", "#DA70D6"},
		// Income
		{"Salary", income, "mdi:wallet", "#00C9A7"},
		{"Business", income, "mdi:briefcase", "#2BB673"},
		{"Investments", income, "mdi:trending-up", "#228B22"},
		{"Benefits", income, "mdi:bank", "#4682B4"},
		{"Side Income", income, "mdi:hammer-wrench", "#FF8C00"},
		{"Gifts", income, "mdi:gift", "#C34A36"},
	}

	for _, d := range defaults {
		t := d.Type
		var existing models.Category
		err := database.
			Where("name = ? AND type = ? AND profile_id IS NULL", d.Name, t).
			First(&existing).Error
		if err == nil {
			// Refresh icon/color in case defaults changed between releases.
			existing.Icon = d.Icon
			existing.Color = d.Color
			if err := database.Save(&existing).Error; err != nil {
				return fmt.Errorf("mobile.seedDefaultCategories: refresh %q/%s: %w", d.Name, t, err)
			}
			continue
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("mobile.seedDefaultCategories: lookup %q/%s: %w", d.Name, t, err)
		}

		cat := models.Category{
			ProfileID: nil,
			Type:      &t,
			Name:      d.Name,
			Icon:      d.Icon,
			Color:     d.Color,
		}
		if err := database.Create(&cat).Error; err != nil {
			return fmt.Errorf("mobile.seedDefaultCategories: create %q/%s: %w", d.Name, t, err)
		}
	}
	return nil
}
