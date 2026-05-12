package engine

import (
	"log"
	"moneef/internal/db"
	"moneef/internal/iconlookup"
	"moneef/internal/models"
)

var patternTypeDefaults = map[string]struct {
	Icon  string
	Color string
}{
	"weekend_spike":           {Icon: "mdi:calendar", Color: "#F59E0B"},
	"weekday_spike":           {Icon: "mdi:briefcase", Color: "#3B82F6"},
	"top_category":            {Icon: "mdi:trophy", Color: "#10B981"},
	"high_concentration":      {Icon: "mdi:alert", Color: "#F59E0B"},
	"very_high_concentration": {Icon: "mdi:circle", Color: "#EF4444"},
	"daily_habit":             {Icon: "mdi:coffee", Color: "#6B5CE7"},
	"weekly_repeat":           {Icon: "mdi:repeat", Color: "#3B82F6"},
	"infrequent_splurge":      {Icon: "mdi:cash-multiple", Color: "#EF4444"},
}

func isBlank(s string) bool {
	return s == "" || s == "-"
}

func resolveIconForPattern(pattern *models.Pattern) {
	if !isBlank(pattern.Icon) && !isBlank(pattern.Color) {
		return
	}

	category := extractCategoryFromMetadata(pattern.Metadata)

	if category != "" {
		var cat models.Category
		if err := db.DB.Where("name = ?", category).First(&cat).Error; err == nil {
			if isBlank(pattern.Icon) && cat.Icon != "" {
				pattern.Icon = cat.Icon
			}
			if isBlank(pattern.Color) && cat.Color != "" {
				pattern.Color = cat.Color
			}
		}
	}

	if isBlank(pattern.Icon) || isBlank(pattern.Color) {
		fields := []string{pattern.Name, pattern.Description}
		for _, field := range fields {
			if field == "" {
				continue
			}
			icon, color, found := iconlookup.Lookup(field)
			if found {
				if isBlank(pattern.Icon) {
					pattern.Icon = icon
				}
				if isBlank(pattern.Color) {
					pattern.Color = color
				}
				break
			}
		}
	}

	if isBlank(pattern.Icon) || isBlank(pattern.Color) {
		if defaults, ok := patternTypeDefaults[pattern.Type]; ok {
			if isBlank(pattern.Icon) {
				pattern.Icon = defaults.Icon
			}
			if isBlank(pattern.Color) {
				pattern.Color = defaults.Color
			}
		} else {
			if isBlank(pattern.Icon) {
				pattern.Icon = "mdi:chart-bar"
			}
			if isBlank(pattern.Color) {
				pattern.Color = "#6B5CE7"
			}
		}
	}
}

func ResolvePatternIconInMemory(pattern *models.Pattern) {
	resolveIconForPattern(pattern)
}

func ResolvePatternIcon(patternID uint) {
	var pattern models.Pattern
	if err := db.DB.First(&pattern, patternID).Error; err != nil {
		log.Printf("⚠️ [PATTERN-ENGINE] Pattern %d not found for icon resolution: %v", patternID, err)
		return
	}

	if !isBlank(pattern.Icon) && !isBlank(pattern.Color) {
		log.Printf("⏭️ [PATTERN-ENGINE] Pattern %d already has icon/color, skipping", patternID)
		return
	}

	resolveIconForPattern(&pattern)

	updates := map[string]interface{}{}
	if !isBlank(pattern.Icon) {
		updates["icon"] = pattern.Icon
	}
	if !isBlank(pattern.Color) {
		updates["color"] = pattern.Color
	}

	if len(updates) > 0 {
		if err := db.DB.Model(&models.Pattern{}).Where("id = ?", patternID).Updates(updates).Error; err != nil {
			log.Printf("❌ [PATTERN-ENGINE] Failed to update pattern %d icon/color: %v", patternID, err)
			return
		}
		log.Printf("✅ [PATTERN-ENGINE] Pattern %d icon/color resolved: icon=%v color=%v", patternID, updates["icon"], updates["color"])
	}
}

func ResolvePatternIconAsync(patternID uint) {
	go ResolvePatternIcon(patternID)
}

func extractCategoryFromMetadata(metadata interface{}) string {
	m, ok := metadata.(map[string]interface{})
	if !ok {
		return ""
	}
	if cat, ok := m["category"].(string); ok && cat != "" {
		return cat
	}
	return ""
}
